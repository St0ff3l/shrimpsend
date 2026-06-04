import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:app/services/file_store.dart';
import 'package:app/services/share/share_pending_cache.dart';

void main() {
  group('SharePendingCache', () {
    test('deleteStagingFile only removes files under cache root', () async {
      final temp = await Directory.systemTemp.createTemp('share_cache_test_');
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });

      final cacheRoot = p.join(temp.path, 'shrimpsend');
      await Directory(cacheRoot).create(recursive: true);
      final stagingDir = Directory(p.join(cacheRoot, 'share_test'));
      await stagingDir.create();
      final stagingFile = File(p.join(stagingDir.path, 'photo.jpg'));
      await stagingFile.writeAsBytes([1, 2, 3]);

      final outside = File(p.join(temp.path, 'outside.jpg'));
      await outside.writeAsBytes([4, 5, 6]);

      expect(
        FileStore.isPathUnderDirectory(stagingFile.path, cacheRoot),
        isTrue,
      );
      expect(
        FileStore.isPathUnderDirectory(outside.path, cacheRoot),
        isFalse,
      );

      await SharePendingCache.deleteStagingFile(outside.path, cacheRoot: cacheRoot);
      expect(await outside.exists(), isTrue);

      await SharePendingCache.deleteStagingFile(stagingFile.path, cacheRoot: cacheRoot);
      expect(await stagingFile.exists(), isFalse);
      expect(await stagingDir.exists(), isFalse);
    });
  });

  group('ShareIngestPipeline reuse', () {
    test('isPathUnderDirectory detects share staging layout', () async {
      final temp = await Directory.systemTemp.createTemp('share_ingest_test_');
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });

      final cacheRoot = p.join(temp.path, 'shrimpsend');
      final messageDir = Directory(p.join(cacheRoot, 'share_uuid'));
      await messageDir.create(recursive: true);
      final staged = File(p.join(messageDir.path, 'doc.pdf'));
      await staged.writeAsBytes([9]);

      expect(FileStore.isPathUnderDirectory(staged.path, cacheRoot), isTrue);

      final platformFile = PlatformFile(
        name: 'doc.pdf',
        path: staged.path,
        size: 1,
      );
      expect(platformFile.path, staged.path);
    });
  });
}
