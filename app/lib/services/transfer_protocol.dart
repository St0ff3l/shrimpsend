/// Constants for the HTTP file transfer protocol.
///
/// Direct push:  POST /transfer with X-File-Name, X-File-Size headers + raw body
/// Reverse pull: GET /download?offerId=xxx
/// Probe:        GET /probe → 200 OK
/// Resume status: GET /transfer-status?fileId=xxx → X-Received-Bytes
abstract final class TransferProtocol {
  /// Chunk size for reading/writing data (512 KB).
  static const int chunkSize = 512 * 1024;

  /// Disk read block size: read this many bytes at once, then stream to HTTP.
  /// Keeps memory at O(readBlockSize).
  static const int readBlockSize = 4 * 1024 * 1024;

  /// Minimum percentage change before reporting progress (used by receiver).
  static const int progressReportThreshold = 2;

  /// Maximum number of files transferred concurrently over LAN.
  /// Kept low so receivers can finish cache writes before export copies run.
  static const int maxConcurrentFiles = 2;

  /// Header: stable file identifier for resume (hash of name+size).
  static const String headerFileId = 'X-File-Id';

  /// Header: byte offset to resume from.
  static const String headerResumeOffset = 'X-Resume-Offset';

  /// Response header: bytes already received.
  static const String headerReceivedBytes = 'X-Received-Bytes';

  /// Header: SHA-256 hash of the complete file for integrity verification.
  static const String headerFileHash = 'X-File-Hash';

  /// Header: sender device id (LAN HTTP push) so the receiver can persist to the correct thread.
  static const String headerFromDeviceId = 'X-Ultrasend-From-Device-Id';

  /// Header: intended recipient device id; receiver drops the transfer if it does not match.
  static const String headerToDeviceId = 'X-Ultrasend-To-Device-Id';

  /// Header: source file last-modified time in milliseconds since epoch (int64
  /// as decimal string). Optional; receivers apply it to the final file so the
  /// destination preserves the sender's original mtime. Older peers that don't
  /// send this header simply fall back to the local write time.
  static const String headerFileMtimeMs = 'X-File-Mtime-Ms';

  /// Header: sender-assigned per-transfer local id (UUID). Carried on LAN HTTP
  /// uploads and reverse-pull offers so the receiver can use the same id for
  /// `received_files`, chat bubbles, and merging with the Centrifugo file
  /// publication. Without it (older peers) the receiver falls back to its own
  /// UUID and treats each transfer as a fresh message.
  static const String headerLocalId = 'X-Ultrasend-Local-Id';
}
