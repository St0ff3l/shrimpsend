import { S3TransferService } from '@/lib/services/s3Transfer';
import type { OnTransferProgress } from '@/lib/services/cloudTransfer';

const cloudTransfer = new S3TransferService();

/** Downloads an S3 object and triggers a browser save (no preview / window.open). */
export async function downloadS3FileAsBrowserSave(
  s3Key: string,
  fileName: string,
  onProgress?: OnTransferProgress,
): Promise<void> {
  const result = await cloudTransfer.download(s3Key, onProgress);
  const blobUrl = URL.createObjectURL(result.blob);
  try {
    const a = document.createElement('a');
    a.href = blobUrl;
    a.download = fileName || 'download';
    a.click();
  } finally {
    URL.revokeObjectURL(blobUrl);
  }
}
