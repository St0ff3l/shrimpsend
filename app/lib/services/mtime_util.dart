/// Utilities for preserving the source file's last-modified timestamp across
/// transfers (LAN HTTP, WebRTC, S3).
///
/// The transport protocols pass mtime as an int64 number of milliseconds since
/// epoch. All helpers here are best-effort: failures only emit a warning and
/// never throw, so a stat/setLastModified hiccup does not break the transfer.
library;

import 'dart:io';

import 'package:logging/logging.dart';

/// Dedicated logger; intentionally avoids depending on `app/lib/logger.dart`
/// so this helper is safe to import from isolate workers that have not wired
/// the main app's log file sink.
final Logger _log = Logger('ultrasend.mtime');

/// Reads the file's last-modified time as milliseconds since epoch.
///
/// Returns `null` if [path] is null/empty, the file does not exist, or stat
/// fails for any reason.
int? readMtimeMs(String? path) {
  if (path == null || path.isEmpty) return null;
  try {
    final f = File(path);
    if (!f.existsSync()) return null;
    return f.statSync().modified.millisecondsSinceEpoch;
  } catch (e) {
    _log.fine('readMtimeMs failed for $path: $e');
    return null;
  }
}

/// Parses a wire-format mtime value into milliseconds since epoch.
///
/// Accepts int / num / numeric string. Returns null for any other shape or
/// for non-positive values (which would represent epoch zero / invalid).
int? parseMtimeMs(Object? raw) {
  if (raw == null) return null;
  int? v;
  if (raw is int) {
    v = raw;
  } else if (raw is num) {
    v = raw.toInt();
  } else if (raw is String) {
    v = int.tryParse(raw.trim());
  }
  if (v == null || v <= 0) return null;
  return v;
}

/// Sets only the last-modified time (mtime). Does not adjust creation time.
///
/// Prefer [applyReceivedFileTimestamps] on the main isolate after receive;
/// this helper is the cross-platform fallback when platform APIs are unavailable.
void applyMtimeMs(String path, int? ms) {
  if (ms == null || ms <= 0) return;
  try {
    final f = File(path);
    if (!f.existsSync()) return;
    f.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(ms));
  } catch (e) {
    _log.warning('applyMtimeMs failed for $path (ms=$ms): $e');
  }
}
