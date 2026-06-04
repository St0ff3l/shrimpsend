import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import { Log } from '../common/Logger';
import { PresignUploadResponse, S3Api } from '../network/S3Api';

const TAG = 'S3Transfer';

/** 小文件：presign → PUT；大文件：multipart（parts 字段对齐后端 PartInfo：partNumber、eTag） */
export class S3SimpleTransfer {
  static async uploadLocalFile(localPath: string, fileName: string, contentType?: string): Promise<string> {
    const presign: PresignUploadResponse = await S3Api.presignUpload(fileName, contentType);
    const stat = fs.statSync(localPath);
    const size = stat.size;
    const buf = new ArrayBuffer(size);
    const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
    fs.readSync(file.fd, buf);
    fs.closeSync(file.fd);
    await S3SimpleTransfer.putExpect2xx(presign.uploadUrl, buf, contentType ?? 'application/octet-stream');
    Log.info(TAG, 'upload ok key=%{public}s', presign.key);
    return presign.key;
  }

  private static normalizeEtag(raw: string): string {
    let s = raw.trim();
    if (s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s;
  }

  private static extractEtag(data: http.HttpResponse): string {
    const h = data.header as Record<string, string>;
    const keys = Object.keys(h);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (k.toLowerCase() === 'etag') {
        return S3SimpleTransfer.normalizeEtag(h[k]);
      }
    }
    return '';
  }

  private static async putExpect2xx(url: string, body: ArrayBuffer, contentType: string): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const req = http.createHttp();
      req.request(url, {
        method: http.RequestMethod.PUT,
        header: { 'Content-Type': contentType },
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
          reject(new Error(`PUT ${data?.responseCode ?? 0}`));
          return;
        }
        resolve(S3SimpleTransfer.extractEtag(data));
      });
    });
  }

  static async uploadLargeFile(localPath: string, fileName: string, contentType: string,
    partSize: number = 8 * 1024 * 1024): Promise<string> {
    const stat = fs.statSync(localPath);
    const total = stat.size;
    const init = await S3Api.initiateMultipart(fileName, contentType);
    const parts: Record<string, Object>[] = [];
    const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
    let partNumber = 1;
    let offset = 0;
    try {
      while (offset < total) {
        const len = Math.min(partSize, total - offset);
        const buf = new ArrayBuffer(len);
        fs.readSync(file.fd, buf, { position: offset, length: len });
        const url = await S3Api.presignPart(init.uploadId, init.key, partNumber);
        const etag = await S3SimpleTransfer.putExpect2xx(url, buf, 'application/octet-stream');
        if (etag.length === 0) {
          throw new Error('missing ETag from part upload');
        }
        parts.push({
          'partNumber': partNumber,
          'eTag': etag
        });
        offset += len;
        partNumber++;
      }
    } finally {
      fs.closeSync(file.fd);
    }
    await S3Api.completeMultipart(init.uploadId, init.key, parts);
    Log.info(TAG, 'multipart ok key=%{public}s', init.key);
    return init.key;
  }

  static async chooseUpload(localPath: string, fileName: string, contentType?: string): Promise<string> {
    const stat = fs.statSync(localPath);
    const fiveMb = 5 * 1024 * 1024;
    if (stat.size >= fiveMb) {
      return await S3SimpleTransfer.uploadLargeFile(localPath, fileName,
        contentType ?? 'application/octet-stream');
    }
    return await S3SimpleTransfer.uploadLocalFile(localPath, fileName, contentType);
  }
}
