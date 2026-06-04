export type OnTransferProgress = (transferred: number, total: number) => void;

export type CloudUploadResult = {
  key: string;
  fileName: string;
};

export type CloudDownloadResult = {
  blob: Blob;
  totalBytes: number;
};

export interface CloudTransferService {
  upload(
    file: File,
    onProgress?: OnTransferProgress,
    abortSignal?: AbortSignal,
  ): Promise<CloudUploadResult>;

  download(
    key: string,
    onProgress?: OnTransferProgress,
  ): Promise<CloudDownloadResult>;
}
