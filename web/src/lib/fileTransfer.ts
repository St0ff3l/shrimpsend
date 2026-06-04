import type { DeviceDto } from '@/lib/api';
import { logger } from '@/lib/logger';
import { inspectXhrLikelyCors, reportCorsLikely } from '@/lib/network/corsAlert';

const TAG = 'fileTransfer';

/** Same value as `errors.transferStallTimeout` in messages; used for stall detection in chat UI. */
export const TRANSFER_STALL_TIMEOUT_MESSAGE = 'errors.transferStallTimeout' as const;

/** If upload makes no progress for this long, abort (avoids infinite "发送中"). */
const UPLOAD_STALL_MS = 120_000;
const STALL_CHECK_INTERVAL_MS = 4000;

function makeFileId(fileName: string, fileSize: number): string {
  let hash = 0;
  for (let i = 0; i < fileName.length; i++) {
    hash = ((hash << 5) - hash + fileName.charCodeAt(i)) | 0;
  }
  return `${(hash >>> 0).toString(16)}_${fileSize}`;
}

async function queryTransferStatus(httpUrl: string, fileId: string): Promise<number> {
  try {
    const resp = await fetch(
      `${httpUrl}/transfer-status?fileId=${encodeURIComponent(fileId)}`,
      { signal: AbortSignal.timeout(3000) },
    );
    if (resp.ok) {
      const text = await resp.text();
      return parseInt(text, 10) || 0;
    }
    return 0;
  } catch {
    return 0;
  }
}

/**
 * Tries to send a file to target devices via direct LAN HTTP POST.
 * Supports resume: queries the receiver for already-received bytes and sends
 * only the remaining portion.
 *
 * @returns true if at least one device received the file
 * @throws DOMException with name 'AbortError' if aborted
 */
export async function trySendFileViaLan(
  file: File,
  targetDevices: DeviceDto[],
  abortController: AbortController,
  onProgress?: (pct: number) => void,
  localId?: string,
): Promise<boolean> {
  let ok = false;
  const lanDevices = targetDevices.filter((d) => d.lanHttpUrl);
  const totalDevices = lanDevices.length;
  let devicesDone = 0;

  for (const d of lanDevices) {
    if (abortController.signal.aborted) throw new DOMException('Aborted', 'AbortError');
    if (!d.lanHttpUrl) continue;

    try {
      const progressCb = (pct: number) => {
        const deviceBase = totalDevices > 0 ? (devicesDone / totalDevices) * 100 : 0;
        const devicePart = totalDevices > 0 ? (1 / totalDevices) * 100 : 100;
        onProgress?.(Math.min(Math.round(deviceBase + (pct / 100) * devicePart), 99));
      };
      await sendFileSingleHttp(file, d.lanHttpUrl, abortController, progressCb, localId);
      ok = true;
      devicesDone++;
      onProgress?.(Math.round((devicesDone / totalDevices) * 100));
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') throw e;
      devicesDone++;
    }
  }

  return ok;
}

/**
 * Single HTTP POST upload with resume support.
 * Uses XMLHttpRequest for upload progress tracking (fetch API doesn't support it).
 */
async function sendFileSingleHttp(
  file: File,
  httpUrl: string,
  abortController: AbortController,
  onProgress?: (pct: number) => void,
  localId?: string,
): Promise<void> {
  const fileId = makeFileId(file.name, file.size);

  let offset = 0;
  try {
    offset = await queryTransferStatus(httpUrl, fileId);
    if (offset >= file.size) {
      onProgress?.(100);
      return;
    }
  } catch {
    offset = 0;
  }

  const url = `${httpUrl}/transfer`;
  const body = offset > 0 ? file.slice(offset) : file;

  await new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();

    let lastProgressAt = Date.now();
    const stallTimer = window.setInterval(() => {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        clearInterval(stallTimer);
        return;
      }
      const idle = Date.now() - lastProgressAt;
      if (idle >= UPLOAD_STALL_MS) {
        clearInterval(stallTimer);
        logger.warn(
          TAG,
          'LAN upload stall timeout, aborting',
          file.name,
          'idleMs=',
          idle,
          'readyState=',
          xhr.readyState,
        );
        xhr.abort();
      }
    }, STALL_CHECK_INTERVAL_MS);

    const cleanup = () => {
      clearInterval(stallTimer);
    };

    const onAbort = () => {
      cleanup();
      xhr.abort();
    };
    abortController.signal.addEventListener('abort', onAbort, { once: true });

    xhr.upload.onprogress = (e) => {
      lastProgressAt = Date.now();
      if (file.size <= 0) return;
      const totalSent = offset + (e.lengthComputable ? e.loaded : 0);
      const pct = Math.min(Math.round((totalSent / file.size) * 100), 99);
      onProgress?.(pct);
    };

    xhr.onload = () => {
      abortController.signal.removeEventListener('abort', onAbort);
      cleanup();
      if (xhr.status >= 200 && xhr.status < 300) {
        onProgress?.(100);
        resolve();
      } else {
        logger.warn(TAG, 'LAN upload HTTP error', file.name, 'status=', xhr.status);
        reject(new Error(`Server returned ${xhr.status}`));
      }
    };

    xhr.onerror = () => {
      abortController.signal.removeEventListener('abort', onAbort);
      cleanup();
      logger.warn(TAG, 'LAN upload network error', file.name);
      if (inspectXhrLikelyCors(xhr, { abortSignal: abortController.signal })) {
        reportCorsLikely({ url, mode: 'upload', channel: 'lan' });
      }
      reject(new Error('Network error'));
    };

    xhr.onabort = () => {
      abortController.signal.removeEventListener('abort', onAbort);
      cleanup();
      if (abortController.signal.aborted) {
        reject(new DOMException('Aborted', 'AbortError'));
        return;
      }
      reject(new Error(TRANSFER_STALL_TIMEOUT_MESSAGE));
    };

    xhr.open('POST', url);
    xhr.setRequestHeader('X-File-Name', encodeURIComponent(file.name));
    xhr.setRequestHeader('X-File-Size', file.size.toString());
    xhr.setRequestHeader('X-File-Id', fileId);
    xhr.setRequestHeader('Content-Type', 'application/octet-stream');
    if (offset > 0) {
      xhr.setRequestHeader('X-Resume-Offset', offset.toString());
    }
    if (localId) {
      xhr.setRequestHeader('X-Ultrasend-Local-Id', localId);
    }
    xhr.send(body);
  });
}

/**
 * Probe a device via HTTP GET /probe to check reachability.
 */
export async function probeHttpWeb(httpUrl: string, timeoutMs = 3000): Promise<boolean> {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    const resp = await fetch(`${httpUrl}/probe`, { signal: controller.signal });
    clearTimeout(timer);
    return resp.ok;
  } catch {
    return false;
  }
}
