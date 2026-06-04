import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

final Logger _logPending = Logger('虾传.share.pending');

class SharePendingCoordinator {
  List<PlatformFile>? _pendingFromShare;

  void Function(int count, List<PlatformFile> files)? onFilesSavedFromShare;
  VoidCallback? onPendingShareReady;

  List<PlatformFile>? takePendingFromShare() {
    final list = _pendingFromShare;
    _pendingFromShare = null;
    _logPending.info('takePendingFromShare -> ${list?.length ?? 0} file(s)');
    return list;
  }

  void mergeAndNotify(List<PlatformFile> saved, {required String source}) {
    if (saved.isEmpty) return;
    _mergePendingFromShare(saved);
    final cb = onFilesSavedFromShare;
    if (cb == null) {
      _logPending.warning(
        '$source: onFilesSavedFromShare is null; ${saved.length} file(s) cached only',
      );
      return;
    }
    cb(_pendingFromShare?.length ?? saved.length, _pendingFromShare ?? saved);
  }

  void _mergePendingFromShare(List<PlatformFile> saved) {
    final existing = _pendingFromShare;
    if (existing == null || existing.isEmpty) {
      _pendingFromShare = saved;
      return;
    }
    final existingPaths = existing
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toSet();
    final merged = [...existing];
    for (final file in saved) {
      final path = file.path;
      if (path != null && existingPaths.contains(path)) continue;
      merged.add(file);
      if (path != null) existingPaths.add(path);
    }
    _pendingFromShare = merged;
  }
}
