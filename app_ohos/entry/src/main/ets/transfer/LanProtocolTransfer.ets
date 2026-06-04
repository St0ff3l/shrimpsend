import http from '@ohos.net.http';
import { Log } from '../common/Logger';

const TAG = 'LanTransfer';

/** 对齐 shared/protocol.md：HTTP 直传 POST /transfer */
export class LanProtocolTransfer {
  static normalizeBase(url: string): string {
    let u = url.trim();
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static async postTransfer(
    lanBaseUrl: string,
    fileName: string,
    fileSize: number,
    body: ArrayBuffer,
    fileId?: string,
    resumeOffset?: number,
    lastModifiedMs?: number
  ): Promise<void> {
    const base = LanProtocolTransfer.normalizeBase(lanBaseUrl);
    const url = `${base}/transfer`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/octet-stream',
      'X-File-Name': encodeURIComponent(fileName),
      'X-File-Size': `${fileSize}`
    };
    if (fileId !== undefined && fileId.length > 0) {
      headers['X-File-Id'] = fileId;
    }
    if (resumeOffset !== undefined && resumeOffset > 0) {
      headers['X-Resume-Offset'] = `${resumeOffset}`;
    }
    if (lastModifiedMs !== undefined && lastModifiedMs > 0) {
      headers['X-File-Mtime-Ms'] = `${Math.floor(lastModifiedMs)}`;
    }
    return new Promise<void>((resolve, reject) => {
      const req = http.createHttp();
      req.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 120000,
        readTimeout: 120000
      }, (err: Error | null, data: http.HttpResponse | null) => {
        req.destroy();
        if (err != null) {
          reject(err);
          return;
        }
        if (data === null || data.responseCode < 200 || data.responseCode >= 300) {
          reject(new Error(`LAN POST ${data?.responseCode ?? 0}`));
          return;
        }
        resolve();
      });
    });
  }

  static async probe(lanBaseUrl: string): Promise<boolean> {
    const base = LanProtocolTransfer.normalizeBase(lanBaseUrl);
    const url = `${base}/probe`;
    try {
      const req = http.createHttp();
      const ok = await new Promise<boolean>((resolve) => {
        req.request(url, {
          method: http.RequestMethod.GET,
          connectTimeout: 5000,
          readTimeout: 5000
        }, (err: Error | null, data: http.HttpResponse | null) => {
          req.destroy();
          resolve(data !== null && data.responseCode >= 200 && data.responseCode < 300);
        });
      });
      return ok;
    } catch (_) {
      return false;
    }
  }

  static async getDownloadRange(lanBaseUrl: string, offerId: string, rangeHeader: string): Promise<ArrayBuffer> {
    const base = LanProtocolTransfer.normalizeBase(lanBaseUrl);
    const url = `${base}/download?offerId=${encodeURIComponent(offerId)}`;
    return new Promise<ArrayBuffer>((resolve, reject) => {
      const req = http.createHttp();
      req.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Range': rangeHeader
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 120000,
        readTimeout: 120000
      }, (err: Error | null, data: http.HttpResponse | null) => {
        req.destroy();
        if (err != null || data === null) {
          reject(err ?? new Error('empty'));
          return;
        }
        if (data.responseCode !== 200 && data.responseCode !== 206) {
          reject(new Error(`GET ${data.responseCode}`));
          return;
        }
        const r = data.result;
        if (r instanceof ArrayBuffer) {
          resolve(r);
        } else {
          reject(new Error('bad body'));
        }
      });
    });
  }
}
