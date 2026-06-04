/**
 * Constants for the HTTP file transfer protocol.
 *
 * Direct push:  POST /transfer with X-File-Name, X-File-Size headers + raw body
 * Reverse pull: GET /download?offerId=xxx
 * Probe:        GET /probe → 200 OK
 */
export const TransferProtocol = {
  CHUNK_SIZE: 512 * 1024,
  READ_BLOCK_SIZE: 4 * 1024 * 1024,
  PROGRESS_REPORT_THRESHOLD: 2,
  MAX_CONCURRENT_FILES: 4,
} as const;
