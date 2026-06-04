import '../api/api.dart';
import '../device_id.dart';
import '../logger.dart';

class WebRTCFileMeta {
  final String fileId;
  final String fileName;
  final int fileSize;
  final String mimeType;

  /// Source file last-modified time in milliseconds since epoch.
  /// Optional: older peers omit it; receivers fall back to local write time.
  final int? lastModifiedMs;

  /// Sender-assigned per-transfer local id (UUID). Carried in the WebRTC
  /// offer + `file_start` control message so the receiver can dedup the
  /// eventual Centrifugo `file` publication (whose payload also carries
  /// `localId`) against the locally-created receiver bubble. Older peers
  /// omit it; receivers then treat each transfer as a fresh message.
  final String? senderLocalId;

  WebRTCFileMeta({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.lastModifiedMs,
    this.senderLocalId,
  });

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'fileName': fileName,
    'fileSize': fileSize,
    'mimeType': mimeType,
    if (lastModifiedMs != null) 'lastModifiedMs': lastModifiedMs,
    if (senderLocalId != null) 'localId': senderLocalId,
  };

  factory WebRTCFileMeta.fromJson(Map<String, dynamic> j) {
    final raw = j['lastModifiedMs'];
    int? mtime;
    if (raw is int) {
      mtime = raw;
    } else if (raw is num) {
      mtime = raw.toInt();
    } else if (raw is String) {
      mtime = int.tryParse(raw);
    }
    final rawLocalId = j['localId'];
    final senderLocalId =
        (rawLocalId is String && rawLocalId.isNotEmpty) ? rawLocalId : null;
    return WebRTCFileMeta(
      fileId: j['fileId'] as String,
      fileName: j['fileName'] as String,
      fileSize: j['fileSize'] as int,
      mimeType: j['mimeType'] as String,
      lastModifiedMs: mtime,
      senderLocalId: senderLocalId,
    );
  }
}

Future<void> sendWebRTCSignal(Map<String, dynamic> signal) async {
  final deviceId = await getOrCreateDeviceId();
  await sendMessage({
    'type': signal['type'],
    'payload': signal,
    'fromDeviceId': deviceId,
    'ts': DateTime.now().millisecondsSinceEpoch,
  });
  logChat.fine('sendWebRTCSignal type=${signal['type']}');
}

bool isWebRTCSignalType(String type) {
  return type == 'webrtc_offer' ||
      type == 'webrtc_answer' ||
      type == 'webrtc_ice_candidate' ||
      type == 'webrtc_transfer_cancel';
}
