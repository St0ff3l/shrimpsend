import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../file_store.dart';
import 'share_inbound_payload.dart';

final Logger _logIngest = Logger('虾传.share.ingest');

class ShareIngestPipeline {
  ShareIngestPipeline(this._onSaved);

  final void Function(List<PlatformFile> saved, {required String source}) _onSaved;

  Future<List<PlatformFile>> addPaths(
    List<String> pathStrings, {
    required String source,
  }) async {
    return _ingestPaths(pathStrings, source: source);
  }

  Future<List<PlatformFile>> addAttachments(
    List<ShareAttachment> attachments, {
    required String source,
  }) async {
    final paths = <String>[];
    for (final attachment in attachments) {
      final path = attachment.path;
      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }
    return _ingestPaths(paths, source: source);
  }

  Future<List<PlatformFile>> _ingestPaths(
    List<String> pathStrings, {
    required String source,
  }) async {
    final saved = <PlatformFile>[];
    var anyCopiedToCache = false;
    final cacheRoot = await FileStore.getCacheDir();

    for (final pathStr in pathStrings) {
      if (pathStr.isEmpty) {
        _logIngest.fine('$source: skip empty path');
        continue;
      }
      final file = File(pathStr);
      if (!await file.exists()) {
        _logIngest.warning('$source: shared file not found: $pathStr');
        continue;
      }
      final originalName = p.basename(pathStr);
      if (originalName.isEmpty) {
        _logIngest.warning('$source: empty basename for path $pathStr');
        continue;
      }

      try {
        final alreadyInCache = FileStore.isPathUnderDirectory(pathStr, cacheRoot);
        late final String destPath;
        if (alreadyInCache) {
          destPath = pathStr;
          _logIngest.info(
            '$source: reuse cache path name=$originalName '
            'nativeStagingPath=$pathStr cachePath=$destPath skippedCopy=true skippedExport=true',
          );
        } else {
          final messageId = 'share_${const Uuid().v4()}';
          destPath = await FileStore.buildCachePath(messageId, originalName);
          await file.copy(destPath);
          _logIngest.info(
            '$source: copied to cache name=$originalName '
            'nativeStagingPath=$pathStr cachePath=$destPath skippedExport=true',
          );
        }

        final destFile = File(destPath);
        final stat = await destFile.stat();
        final platformFile = PlatformFile(
          name: originalName,
          path: destPath,
          size: stat.size,
        );
        anyCopiedToCache = true;
        saved.add(platformFile);
      } catch (e, st) {
        _logIngest.warning('$source: failed to ingest $pathStr: $e', e, st);
      }
    }

    if (saved.isEmpty) {
      _logIngest.warning(
        '$source: ingest produced 0 files (input=${pathStrings.length} path(s))',
      );
    }

    if (saved.isNotEmpty) {
      if (anyCopiedToCache) {
        FileStore.notifyReceiveDirChanged();
      }
      _onSaved(saved, source: source);
    }
    return saved;
  }
}
