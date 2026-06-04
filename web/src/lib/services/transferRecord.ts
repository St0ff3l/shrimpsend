export type CompletedPart = {
  partNumber: number;
  eTag: string;
};

export type TransferRecord = {
  transferId: string;
  fileName: string;
  fileSize: number;
  channel: 's3' | 'lan' | 'webrtc' | 'webdav';
  direction: 'upload' | 'download';
  status: 'in_progress' | 'paused' | 'completed' | 'failed';
  transferredBytes: number;
  fileHash?: string;
  createdAt: string;
  updatedAt: string;

  // S3 multipart
  s3UploadId?: string;
  s3Key?: string;
  s3CompletedParts?: CompletedPart[];

  // LAN
  lanTargetUrl?: string;
  lanResumeOffset?: number;

  // WebRTC
  webrtcFileId?: string;
  webrtcOffset?: number;
};

export function isResumable(r: TransferRecord): boolean {
  return r.status === 'in_progress' || r.status === 'paused' || r.status === 'failed';
}

export function progressPercent(r: TransferRecord): number {
  return r.fileSize > 0
    ? Math.min(Math.round((r.transferredBytes / r.fileSize) * 100), 100)
    : 0;
}
