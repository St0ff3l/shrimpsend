import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import '../utils/runtime_platform.dart';

/// Desktop-only file clipboard read/write via [Pasteboard].
final class DesktopFileClipboard {
  DesktopFileClipboard._();

  /// Reads file paths from the system clipboard and returns [PlatformFile]s
  /// suitable for the pending outbox. Empty on non-desktop or when no files.
  static Future<List<PlatformFile>> readFilesForPending() async {
    if (!RuntimePlatform.isDesktop) return const [];

    final paths = await Pasteboard.files();
    if (paths.isEmpty) return const [];

    final files = <PlatformFile>[];
    for (final p in paths) {
      final f = File(p);
      if (!await f.exists()) continue;
      final stat = await f.stat();
      if (stat.size <= 0) continue;
      files.add(
        PlatformFile(
          name: p.split(Platform.pathSeparator).last,
          path: p,
          size: stat.size,
        ),
      );
    }
    return files;
  }

  /// Writes local file paths to the system clipboard. Returns false on
  /// non-desktop, if no valid paths, or if the native write fails.
  static Future<bool> writeFilesToClipboard(List<String> paths) async {
    if (!RuntimePlatform.isDesktop) return false;

    final existing = <String>[];
    for (final p in paths) {
      if (p.isEmpty) continue;
      final f = File(p);
      if (await f.exists()) {
        existing.add(p);
      }
    }
    if (existing.isEmpty) return false;
    return Pasteboard.writeFiles(existing);
  }
}
