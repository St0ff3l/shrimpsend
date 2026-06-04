import http from '@ohos.net.http';
import {
  apiUrl,
  checkAuthOk,
  requestWithAuthRetry
} from './HttpHelper';

export interface S3ConfigDetail {
  configured: boolean;
  endpoint?: string;
  region?: string;
  bucket?: string;
  accessKeyId?: string;
  secretAccessKey?: string;
}

export interface PresignUploadResponse {
  uploadUrl: string;
  key: string;
}

export interface MultipartInitiateResponse {
  uploadId: string;
  key: string;
}

export class S3Api {
  static parseConfig(j: Record<string, Object>): S3ConfigDetail {
    const cfg = j['configured'];
    return {
      configured: cfg === true,
      endpoint: j['endpoint'] !== undefined ? `${j['endpoint']}` : undefined,
      region: j['region'] !== undefined ? `${j['region']}` : undefined,
      bucket: j['bucket'] !== undefined ? `${j['bucket']}` : undefined,
      accessKeyId: j['accessKeyId'] !== undefined ? `${j['accessKeyId']}` : undefined,
      secretAccessKey: j['secretAccessKey'] !== undefined ? `${j['secretAccessKey']}` : undefined
    };
  }

  static async getConfig(): Promise<S3ConfigDetail> {
    try {
      const url = apiUrl('/api/s3/config');
      const res = await requestWithAuthRetry(http.RequestMethod.GET, url, {
        'Content-Type': 'application/json'
      });
      if (res.code !== 200) {
        const empty: S3ConfigDetail = { configured: false };
        return empty;
      }
      const j = JSON.parse(res.body) as Record<string, Object>;
      return S3Api.parseConfig(j);
    } catch (_) {
      const empty: S3ConfigDetail = { configured: false };
      return empty;
    }
  }

  static async saveConfig(body: Record<string, Object>): Promise<void> {
    const url = apiUrl('/api/s3/config');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify(body));
    await checkAuthOk(res, '保存 S3 配置失败');
    if (res.code !== 204) {
      throw new Error('保存失败');
    }
  }

  static async clearConfig(): Promise<void> {
    const url = apiUrl('/api/s3/config');
    const res = await requestWithAuthRetry(http.RequestMethod.DELETE, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '清空 S3 配置失败');
  }

  static async presignUpload(fileName: string, contentType?: string): Promise<PresignUploadResponse> {
    const obj: Record<string, Object> = { 'fileName': fileName };
    if (contentType !== undefined && contentType.length > 0) {
      obj['contentType'] = contentType;
    }
    const url = apiUrl('/api/s3/presign-upload');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify(obj));
    await checkAuthOk(res, '获取上传地址失败');
    const j = JSON.parse(res.body) as Record<string, Object>;
    return {
      uploadUrl: `${j['uploadUrl']}`,
      key: `${j['key']}`
    };
  }

  static async getDownloadUrl(key: string): Promise<string> {
    const url = apiUrl(`/api/s3/download-url?key=${encodeURIComponent(key)}`);
    const res = await requestWithAuthRetry(http.RequestMethod.GET, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '获取下载地址失败');
    const j = JSON.parse(res.body) as Record<string, Object>;
    return `${j['url']}`;
  }

  static async initiateMultipart(fileName: string, contentType?: string): Promise<MultipartInitiateResponse> {
    const obj: Record<string, Object> = { 'fileName': fileName };
    if (contentType !== undefined && contentType.length > 0) {
      obj['contentType'] = contentType;
    }
    const url = apiUrl('/api/s3/multipart/initiate');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify(obj));
    await checkAuthOk(res, '创建分片上传失败');
    const j = JSON.parse(res.body) as Record<string, Object>;
    return {
      uploadId: `${j['uploadId']}`,
      key: `${j['key']}`
    };
  }

  static async presignPart(uploadId: string, key: string, partNumber: number): Promise<string> {
    const url = apiUrl('/api/s3/multipart/presign-part');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify({
      'uploadId': uploadId,
      'key': key,
      'partNumber': partNumber
    }));
    await checkAuthOk(res, '获取分片上传地址失败');
    const j = JSON.parse(res.body) as Record<string, Object>;
    return `${j['url']}`;
  }

  static async completeMultipart(uploadId: string, key: string, parts: Record<string, Object>[]): Promise<void> {
    const url = apiUrl('/api/s3/multipart/complete');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify({
      'uploadId': uploadId,
      'key': key,
      'parts': parts
    }));
    await checkAuthOk(res, '完成分片上传失败');
  }
}
