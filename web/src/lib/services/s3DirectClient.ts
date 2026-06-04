import { sha256Hex as cryptoSha256Hex } from '@/lib/cryptoHash';
import { logger } from '../logger';
import { presignUrl, signRequest } from './awsV4Signer';
import { s3ConfigCache, type S3LocalConfig } from './s3ConfigCache';
import { buildS3ObjectUrl } from './s3ObjectUrl';

const TAG = 's3Direct';

export class S3DirectClient {
  private config: S3LocalConfig;

  constructor(config: S3LocalConfig) {
    this.config = config;
  }

  static create(): S3DirectClient | null {
    const cfg = s3ConfigCache.load();
    if (!cfg) return null;
    return new S3DirectClient(cfg);
  }

  generateKey(fileName: string): string {
    const ts = Date.now();
    const dotIdx = fileName.lastIndexOf('.');
    const ext = dotIdx >= 0 ? fileName.slice(dotIdx) : '';
    const baseName = dotIdx >= 0 ? fileName.slice(0, dotIdx) : fileName;
    // Sanitize to alphanumeric/dash/underscore to avoid encoding mismatches
    // across S3-compatible providers. The original filename is kept in message payload.
    const safeBase = baseName.replace(/[^a-zA-Z0-9\-_]/g, '_');
    return `uploads/${ts}-${safeBase}${ext}`;
  }

  private objectUrl(key: string): URL {
    return buildS3ObjectUrl({
      endpoint: this.config.endpoint,
      bucket: this.config.bucket,
      key,
      pathStyleAccessEnabled: this.config.pathStyleAccessEnabled,
    });
  }

  async presignPutUrl(key: string, expireSeconds = 3600): Promise<string> {
    return presignUrl({
      method: 'PUT',
      url: this.objectUrl(key),
      accessKeyId: this.config.accessKeyId,
      secretAccessKey: this.config.secretAccessKey,
      region: this.config.region,
      expireSeconds,
    });
  }

  async presignGetUrl(key: string, expireSeconds = 3600): Promise<string> {
    return presignUrl({
      method: 'GET',
      url: this.objectUrl(key),
      accessKeyId: this.config.accessKeyId,
      secretAccessKey: this.config.secretAccessKey,
      region: this.config.region,
      expireSeconds,
    });
  }

  async presignUploadPartUrl(
    key: string,
    uploadId: string,
    partNumber: number,
    expireSeconds = 3600,
  ): Promise<string> {
    const url = this.objectUrl(key);
    url.searchParams.set('partNumber', String(partNumber));
    url.searchParams.set('uploadId', uploadId);
    return presignUrl({
      method: 'PUT',
      url,
      accessKeyId: this.config.accessKeyId,
      secretAccessKey: this.config.secretAccessKey,
      region: this.config.region,
      expireSeconds,
    });
  }

  async initiateMultipartUpload(
    key: string,
    contentType = 'application/octet-stream',
  ): Promise<{ uploadId: string; key: string }> {
    const url = this.objectUrl(key);
    url.searchParams.set('uploads', '');

    const headers = await signRequest({
      method: 'POST',
      url,
      accessKeyId: this.config.accessKeyId,
      secretAccessKey: this.config.secretAccessKey,
      region: this.config.region,
      headers: { 'content-type': contentType },
    });
    headers['content-type'] = contentType;

    const resp = await fetch(url.toString(), { method: 'POST', headers });
    if (!resp.ok) {
      throw new Error(`initiateMultipartUpload failed: ${resp.status} ${await resp.text()}`);
    }

    const xml = await resp.text();
    const match = xml.match(/<UploadId>(.+?)<\/UploadId>/);
    if (!match) throw new Error('Failed to parse UploadId from response');
    const uploadId = match[1];
    logger.info(TAG, 'initiated multipart upload=', uploadId, 'key=', key);
    return { uploadId, key };
  }

  async completeMultipartUpload(
    key: string,
    uploadId: string,
    parts: Array<{ partNumber: number; eTag: string }>,
  ): Promise<void> {
    const xmlBody = this.buildCompleteXml(parts);
    const url = this.objectUrl(key);
    url.searchParams.set('uploadId', uploadId);

    const bodyHash = await this.sha256Hex(xmlBody);
    const headers = await signRequest({
      method: 'POST',
      url,
      accessKeyId: this.config.accessKeyId,
      secretAccessKey: this.config.secretAccessKey,
      region: this.config.region,
      headers: { 'content-type': 'application/xml' },
      bodyHash,
    });
    headers['content-type'] = 'application/xml';

    const resp = await fetch(url.toString(), { method: 'POST', headers, body: xmlBody });
    if (!resp.ok) {
      throw new Error(`completeMultipartUpload failed: ${resp.status} ${await resp.text()}`);
    }
    logger.info(TAG, 'completed multipart upload=', uploadId);
  }

  async abortMultipartUpload(key: string, uploadId: string): Promise<void> {
    const url = this.objectUrl(key);
    url.searchParams.set('uploadId', uploadId);

    const headers = await signRequest({
      method: 'DELETE',
      url,
      accessKeyId: this.config.accessKeyId,
      secretAccessKey: this.config.secretAccessKey,
      region: this.config.region,
    });

    const resp = await fetch(url.toString(), { method: 'DELETE', headers });
    if (!resp.ok) {
      logger.warn(TAG, 'abortMultipartUpload failed:', resp.status);
    }
    logger.info(TAG, 'aborted multipart upload=', uploadId);
  }

  private buildCompleteXml(parts: Array<{ partNumber: number; eTag: string }>): string {
    const inner = parts
      .map((p) => `<Part><PartNumber>${p.partNumber}</PartNumber><ETag>${p.eTag}</ETag></Part>`)
      .join('');
    return `<CompleteMultipartUpload>${inner}</CompleteMultipartUpload>`;
  }

  private async sha256Hex(data: string): Promise<string> {
    return cryptoSha256Hex(data);
  }
}
