import {
  abortMultipartUpload as apiAbortMultipart,
  completeMultipartUpload as apiCompleteMultipart,
  getDownloadUrl as apiGetDownloadUrl,
  getS3Config,
  initiateMultipartUpload as apiInitiateMultipart,
  presignUpload as apiPresignUpload,
  presignUploadPart as apiPresignUploadPart,
} from '../api/s3';
import { generateUUID } from '../deviceId';
import { logger } from '../logger';
import type {
  CloudTransferService,
  CloudUploadResult,
  CloudDownloadResult,
  OnTransferProgress,
} from './cloudTransfer';
import { S3DirectClient } from './s3DirectClient';
import { s3ConfigCache } from './s3ConfigCache';
import { transferStateManager } from './transferStateManager';
import type { CompletedPart } from './transferRecord';
import {
  inspectXhrLikelyCors,
  isLikelyNetworkOrCorsError,
  reportCorsLikely,
} from '../network/corsAlert';

const TAG = 's3Transfer';
const MULTIPART_THRESHOLD = 5 * 1024 * 1024; // 5 MB
const PART_SIZE = 10 * 1024 * 1024; // 10 MB

/**
 * 没有本地 BYO 凭证时所有上传/下载都走后端 presign。
 * 后端会按用户当前 mode（HOSTED 走平台桶；CUSTOM 走用户桶）自动路由，
 * 因此前端只需要按「本地缓存有无」选择直连还是后端代理路径即可。
 */
function shouldUseBackendRouting(): boolean {
  return s3ConfigCache.load() == null;
}

async function getDirectClient(): Promise<S3DirectClient> {
  let client = S3DirectClient.create();
  if (!client) {
    logger.info(TAG, 'no local cache, fetching config to sync');
    await getS3Config();
    client = S3DirectClient.create();
  }
  if (!client) throw new Error('errors.s3NoCustomCreds');
  return client;
}

export class S3TransferService implements CloudTransferService {
  async upload(
    file: File,
    onProgress?: OnTransferProgress,
    abortSignal?: AbortSignal,
  ): Promise<CloudUploadResult> {
    if (shouldUseBackendRouting()) {
      if (file.size >= MULTIPART_THRESHOLD) {
        try {
          return await this._hostedBackendMultipartUpload(file, onProgress, abortSignal);
        } catch (e) {
          logger.warn(TAG, 'hosted multipart upload failed, falling back to simple', e);
        }
      }
      return this._hostedBackendSimpleUpload(file, onProgress, abortSignal);
    }

    if (file.size >= MULTIPART_THRESHOLD) {
      try {
        return await this._multipartUpload(file, onProgress, abortSignal);
      } catch (e) {
        logger.warn(TAG, 'multipart upload failed, falling back to simple upload', e);
        return this._simpleUpload(file, onProgress, abortSignal);
      }
    }
    return this._simpleUpload(file, onProgress, abortSignal);
  }

  private async _simpleUpload(
    file: File,
    onProgress?: OnTransferProgress,
    abortSignal?: AbortSignal,
  ): Promise<CloudUploadResult> {
    const s3 = await getDirectClient();
    const key = s3.generateKey(file.name);
    const uploadUrl = await s3.presignPutUrl(key);
    await this._putViaXhr(uploadUrl, file, onProgress, abortSignal);
    onProgress?.(file.size, file.size);
    logger.info(TAG, 'simple upload ok', file.name, 'key=', key);
    return { key, fileName: file.name };
  }

  /** 通过后端 presign 的简单上传（HOSTED 用户走平台桶）。 */
  private async _hostedBackendSimpleUpload(
    file: File,
    onProgress?: OnTransferProgress,
    abortSignal?: AbortSignal,
  ): Promise<CloudUploadResult> {
    const pres = await apiPresignUpload(file.name, file.type || undefined, file.size);
    await this._putViaXhr(pres.uploadUrl, file, onProgress, abortSignal);
    onProgress?.(file.size, file.size);
    logger.info(TAG, 'hosted simple upload ok', file.name, 'key=', pres.key);
    return { key: pres.key, fileName: file.name };
  }

  private _putViaXhr(
    uploadUrl: string,
    file: File,
    onProgress?: OnTransferProgress,
    abortSignal?: AbortSignal,
  ): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      let aborted = false;
      const onAbort = () => {
        aborted = true;
        xhr.abort();
        reject(new DOMException('Aborted', 'AbortError'));
      };
      if (abortSignal) {
        abortSignal.addEventListener('abort', onAbort, { once: true });
      }
      xhr.upload.onprogress = (e) => {
        const loaded = e.loaded;
        const total = e.lengthComputable ? e.total : file.size;
        onProgress?.(loaded, total);
      };
      xhr.onload = () => {
        abortSignal?.removeEventListener('abort', onAbort);
        if (xhr.status >= 200 && xhr.status < 300) resolve();
        else reject(new Error(`Upload failed (HTTP ${xhr.status})`));
      };
      xhr.onerror = () => {
        abortSignal?.removeEventListener('abort', onAbort);
        if (inspectXhrLikelyCors(xhr, { aborted, abortSignal })) {
          reportCorsLikely({ url: uploadUrl, mode: 'upload', channel: 's3' });
        }
        reject(new Error('errors.s3UploadFailed'));
      };
      xhr.open('PUT', uploadUrl);
      xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream');
      xhr.send(file);
    });
  }

  private async _multipartUpload(
    file: File,
    onProgress?: OnTransferProgress,
    abortSignal?: AbortSignal,
  ): Promise<CloudUploadResult> {
    const s3 = await getDirectClient();
    const mgr = transferStateManager;

    let record = mgr.findResumable({
      channel: 's3',
      direction: 'upload',
      fileName: file.name,
      fileSize: file.size,
    });

    let uploadId: string;
    let key: string;
    let completedParts: CompletedPart[];

    if (record?.s3UploadId && record?.s3Key) {
      uploadId = record.s3UploadId;
      key = record.s3Key;
      completedParts = [...(record.s3CompletedParts ?? [])];
      logger.info(TAG, 'multipart resume uploadId=', uploadId, 'completed=', completedParts.length);
    } else {
      const newKey = s3.generateKey(file.name);
      const initResp = await s3.initiateMultipartUpload(
        newKey,
        file.type || 'application/octet-stream',
      );
      uploadId = initResp.uploadId;
      key = initResp.key;
      completedParts = [];

      const now = new Date().toISOString();
      record = {
        transferId: generateUUID(),
        fileName: file.name,
        fileSize: file.size,
        channel: 's3',
        direction: 'upload',
        status: 'in_progress',
        transferredBytes: 0,
        createdAt: now,
        updatedAt: now,
        s3UploadId: uploadId,
        s3Key: key,
        s3CompletedParts: [],
      };
      mgr.saveRecord(record);
    }

    return this._runMultipartLoop({
      file,
      uploadId,
      key,
      completedParts,
      record,
      mgr,
      presignPart: (n) => s3.presignUploadPartUrl(key, uploadId, n),
      complete: (parts) => s3.completeMultipartUpload(key, uploadId, parts),
      onProgress,
      abortSignal,
    });
  }

  /** 通过后端 presign 的分片上传（HOSTED 用户走平台桶）。 */
  private async _hostedBackendMultipartUpload(
    file: File,
    onProgress?: OnTransferProgress,
    abortSignal?: AbortSignal,
  ): Promise<CloudUploadResult> {
    const mgr = transferStateManager;

    let record = mgr.findResumable({
      channel: 's3',
      direction: 'upload',
      fileName: file.name,
      fileSize: file.size,
    });

    let uploadId: string;
    let key: string;
    let completedParts: CompletedPart[];

    if (record?.s3UploadId && record?.s3Key) {
      uploadId = record.s3UploadId;
      key = record.s3Key;
      completedParts = [...(record.s3CompletedParts ?? [])];
      logger.info(TAG, 'hosted multipart resume uploadId=', uploadId, 'completed=', completedParts.length);
    } else {
      const initResp = await apiInitiateMultipart(
        file.name,
        file.type || 'application/octet-stream',
        file.size,
      );
      uploadId = initResp.uploadId;
      key = initResp.key;
      completedParts = [];

      const now = new Date().toISOString();
      record = {
        transferId: generateUUID(),
        fileName: file.name,
        fileSize: file.size,
        channel: 's3',
        direction: 'upload',
        status: 'in_progress',
        transferredBytes: 0,
        createdAt: now,
        updatedAt: now,
        s3UploadId: uploadId,
        s3Key: key,
        s3CompletedParts: [],
      };
      mgr.saveRecord(record);
    }

    return this._runMultipartLoop({
      file,
      uploadId,
      key,
      completedParts,
      record,
      mgr,
      presignPart: (n) => apiPresignUploadPart(uploadId, key, n),
      complete: (parts) => apiCompleteMultipart(uploadId, key, parts),
      abortRemote: () => apiAbortMultipart(uploadId, key).catch((e) => {
        logger.warn(TAG, 'hosted abortMultipartUpload failed', e);
      }),
      onProgress,
      abortSignal,
    });
  }

  private async _runMultipartLoop(args: {
    file: File;
    uploadId: string;
    key: string;
    completedParts: CompletedPart[];
    record: NonNullable<ReturnType<typeof transferStateManager.findResumable>>;
    mgr: typeof transferStateManager;
    presignPart: (partNumber: number) => Promise<string>;
    complete: (parts: CompletedPart[]) => Promise<void>;
    abortRemote?: () => Promise<unknown>;
    onProgress?: OnTransferProgress;
    abortSignal?: AbortSignal;
  }): Promise<CloudUploadResult> {
    const {
      file, key, completedParts, record, mgr,
      presignPart, complete, abortRemote, onProgress, abortSignal,
    } = args;

    const totalParts = Math.ceil(file.size / PART_SIZE);
    const completedNumbers = new Set(completedParts.map((p) => p.partNumber));

    let totalSent = completedParts.reduce((sum, p) => {
      const start = (p.partNumber - 1) * PART_SIZE;
      const end = Math.min(start + PART_SIZE, file.size);
      return sum + (end - start);
    }, 0);
    onProgress?.(totalSent, file.size);

    try {
      for (let partNum = 1; partNum <= totalParts; partNum++) {
        if (abortSignal?.aborted) {
          mgr.markStatus(record.transferId, 'paused');
          throw new DOMException('Aborted', 'AbortError');
        }
        if (completedNumbers.has(partNum)) continue;

        const start = (partNum - 1) * PART_SIZE;
        const end = Math.min(start + PART_SIZE, file.size);
        const partBlob = file.slice(start, end);

        const presignedUrl = await presignPart(partNum);
        const eTag = await this._uploadPart(presignedUrl, partBlob, abortSignal);

        completedParts.push({ partNumber: partNum, eTag });
        totalSent += end - start;
        onProgress?.(totalSent, file.size);

        mgr.updateProgress(record.transferId, totalSent, [...completedParts]);
      }

      const sortedParts = [...completedParts].sort((a, b) => a.partNumber - b.partNumber);
      await complete(sortedParts);

      mgr.markStatus(record.transferId, 'completed');
      onProgress?.(file.size, file.size);
      logger.info(TAG, 'multipart upload ok key=', key, 'parts=', totalParts);

      return { key, fileName: file.name };
    } catch (e) {
      const aborted = e instanceof DOMException && e.name === 'AbortError';
      if (!aborted) {
        mgr.markStatus(record.transferId, 'failed');
        if (abortRemote) {
          await abortRemote();
        }
      }
      throw e;
    }
  }

  private async _uploadPart(
    presignedUrl: string,
    blob: Blob,
    abortSignal?: AbortSignal,
  ): Promise<string> {
    let resp: Response;
    try {
      resp = await fetch(presignedUrl, {
        method: 'PUT',
        body: blob,
        signal: abortSignal,
      });
    } catch (e) {
      if (isLikelyNetworkOrCorsError(e)) {
        reportCorsLikely({ url: presignedUrl, mode: 'upload', channel: 's3', cause: e });
      }
      throw e;
    }
    if (!resp.ok) throw new Error(`Multipart upload failed (HTTP ${resp.status})`);
    return resp.headers.get('etag') ?? '';
  }

  async download(
    key: string,
    onProgress?: OnTransferProgress,
  ): Promise<CloudDownloadResult> {
    const url = await resolveDownloadUrl(key);
    logger.info(TAG, 'download start key=', key);

    let resp: Response;
    try {
      resp = await fetch(url);
    } catch (e) {
      if (isLikelyNetworkOrCorsError(e)) {
        reportCorsLikely({ url, mode: 'download', channel: 's3', cause: e });
      }
      throw e;
    }
    if (!resp.ok) throw new Error(`Download failed (HTTP ${resp.status})`);

    const contentLength = +(resp.headers.get('Content-Length') ?? 0);
    const body = resp.body;
    if (!body) throw new Error('errors.s3EmptyResponse');

    const reader = body.getReader();
    const chunks: Uint8Array[] = [];
    let received = 0;

    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      received += value.length;
      if (contentLength > 0) {
        onProgress?.(received, contentLength);
      }
    }

    const blob = new Blob(chunks as BlobPart[]);
    logger.info(TAG, 'download ok key=', key, 'bytes=', received);
    return { blob, totalBytes: received };
  }
}

/**
 * 解析任意 S3 对象的下载 URL。优先使用本地 BYO 直连（SigV4），
 * 没有缓存则走后端 `/api/s3/download-url`，让后端按用户当前 mode 自动签名。
 */
export async function resolveDownloadUrl(key: string): Promise<string> {
  const client = S3DirectClient.create();
  if (client) {
    return client.presignGetUrl(key);
  }
  return apiGetDownloadUrl(key);
}
