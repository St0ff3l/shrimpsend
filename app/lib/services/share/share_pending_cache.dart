import 'package:file_picker/file_picker.dart';

import '../file_store.dart';

/// Staging files for shares ingested into `<cacheRoot>/shrimpsend/share_*`.
class SharePendingCache {
  SharePendingCache._();

  static Future<void> deleteStagingFile(
    String? path, {
    String? cacheRoot,
  }) async {
    if (path == null || path.isEmpty) return;
    final root = cacheRoot ?? await FileStore.getCacheDir();
    if (!FileStore.isPathUnderDirectory(path, root)) return;
    await FileStore.deleteFile(path);
  }

  static Future<void> deleteStagingFiles(
    Iterable<PlatformFile> files, {
    String? cacheRoot,
  }) async {
    for (final file in files) {
      await deleteStagingFile(file.path, cacheRoot: cacheRoot);
    }
  }
}
