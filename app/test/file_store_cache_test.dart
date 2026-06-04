import 'dart:io';

import 'package:app/services/file_store.dart';
import 'package:app/services/visible_export_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileStore.resolveReadablePath', () {
    test('prefers existing cache path over visible and abs', () {
      final dir = Directory.systemTemp.createTempSync('cache_test_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final cache = File(p.join(dir.path, 'cache.bin'));
      cache.writeAsStringSync('x');

      final resolved = FileStore.resolveReadablePath(
        cachePath: cache.path,
        visiblePath: p.join(dir.path, 'visible.bin'),
        absPath: p.join(dir.path, 'abs.bin'),
      );
      expect(resolved, cache.path);
    });

    test('falls back to visible POSIX path when cache missing', () {
      final dir = Directory.systemTemp.createTempSync('visible_test_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final visible = File(p.join(dir.path, 'visible.bin'));
      visible.writeAsStringSync('x');

      final resolved = FileStore.resolveReadablePath(
        cachePath: p.join(dir.path, 'missing.bin'),
        visiblePath: visible.path,
        absPath: p.join(dir.path, 'abs.bin'),
      );
      expect(resolved, visible.path);
    });
  });

  group('FileStore.resolveUniquePath', () {
    test('adds numeric suffix on collision', () {
      final dir = Directory.systemTemp.createTempSync('unique_test_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      File(p.join(dir.path, 'photo.jpg')).writeAsStringSync('a');

      final next = FileStore.resolveUniquePath(dir.path, 'photo.jpg');
      expect(p.basename(next), 'photo (1).jpg');
    });
  });

  group('ExportStatus', () {
    test('round-trips enum names', () {
      expect(ExportStatus.pending.name, 'pending');
      expect(ExportStatus.done.name, 'done');
      expect(ExportStatus.legacy.name, 'legacy');
    });
  });
}
