import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../logger.dart';
import 'file_export_pipeline.dart';
import 'received_file_dao.dart';

final _log = logChat;

/// Brief pause after index write so cache files finish flushing before export.
Duration _settleAfterUpsert() {
  if (kIsWeb) return Duration.zero;
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return const Duration(milliseconds: 50);
  }
  return const Duration(milliseconds: 50);
}

/// Serializes [ReceivedFileDao.upsert] + inline [FileExportPipeline.exportNow]
/// so each received file is exported before the next finalize runs.
class ReceivedFileIndexPipeline {
  ReceivedFileIndexPipeline._();
  static final instance = ReceivedFileIndexPipeline._();

  Future<void>? _tail;

  /// Runs [upsert] then immediately exports to visible storage.
  /// Returns `true` when export reaches [ExportStatus.done].
  /// Throws if [upsert] fails.
  Future<bool> upsertAndExportInline({
    required String messageId,
    required Future<void> Function() upsert,
  }) async {
    Future<bool> run() async {
      await upsert();
      final settle = _settleAfterUpsert();
      if (settle > Duration.zero) {
        await Future<void>.delayed(settle);
      }
      return FileExportPipeline.instance.exportNow(messageId);
    }

    final prev = _tail ?? Future<void>.value();
    late final Future<bool> next;
    next = prev.then((_) => run());
    _tail = next.then((_) {}).catchError((Object e, StackTrace st) {
      _log.warning(
        'ReceivedFileIndexPipeline failed for $messageId: $e',
        e,
        st,
      );
    });
    return next;
  }
}
