import 'package:flutter_chat_core/flutter_chat_core.dart';
import '../api/api.dart';

String formatSize(int? size) {
  if (size == null) return '';
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  if (size < 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

bool _payloadTruth(dynamic v) {
  if (v == true) return true;
  if (v == false || v == null) return false;
  if (v == 1 || v == 1.0) return true;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

/// Converts backend [MessageEnvelope] to Flyer Chat [Message].
/// [overrideId] is used for optimistic messages (e.g. 'local_$localId') so we can dedupe and show status.
Message envelopeToMessage(MessageEnvelope msg, {String? overrideId}) {
  final id = overrideId ?? '${msg.ts}_${msg.fromDeviceId}';
  final createdAt = DateTime.fromMillisecondsSinceEpoch(msg.ts);
  final authorId = msg.fromDeviceId;
  if (msg.type == 'text') {
    final text =
        (msg.payload is Map
            ? (msg.payload as Map)['text']?.toString()
            : null) ??
        '';
    return Message.text(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      text: text,
    );
  }
  if (msg.type == 'file') {
    final payload = msg.payload is Map ? msg.payload as Map : null;
    final fileName = payload?['fileName']?.toString() ?? '文件';
    final sizeRaw = payload?['size'];
    final size = sizeRaw is num ? sizeRaw.toInt() : null;
    final hasKey =
        payload?['key'] != null && (payload!['key'] as String).isNotEmpty;
    final lanFlag = _payloadTruth(payload?['lan']);
    final webrtcFlag = _payloadTruth(payload?['webrtc']);
    final targetIds = payload?['targetDeviceIds'];
    final lanByMulticast =
        targetIds is List && targetIds.isNotEmpty;
    String text;
    if (webrtcFlag) {
      text = '$fileName (WebRTC)';
    } else if (lanFlag || lanByMulticast) {
      text = '$fileName (已通过 HTTP 发送)';
    } else if (hasKey) {
      text = '点击接收: $fileName (${formatSize(size)})';
    } else {
      text = '文件: $fileName';
    }
    return Message.text(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      text: text,
    );
  }
  return Message.unsupported(id: id, authorId: authorId, createdAt: createdAt);
}

String? mimeFromExtension(String ext) {
  final e = ext.toLowerCase();
  if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
  if (e == 'png') return 'image/png';
  if (e == 'gif') return 'image/gif';
  if (e == 'webp') return 'image/webp';
  if (e == 'pdf') return 'application/pdf';
  return null;
}

bool isImageOrVideoFileName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  const imageOrVideo = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'bmp',
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  };
  return imageOrVideo.contains(ext);
}
