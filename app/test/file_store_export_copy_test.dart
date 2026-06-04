import 'dart:io';

import 'package:app/services/file_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileStore.exportCopyVerified', () {
    late Directory tmp;
    late Directory srcDir;
    late Directory destDir;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ultrasend_export_test_');
      srcDir = Directory(p.join(tmp.path, 'src'));
      destDir = Directory(p.join(tmp.path, 'dest'));
      await srcDir.create();
      await destDir.create();
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('copies full file and leaves no .part residue', () async {
      final source = File(p.join(srcDir.path, 'photo.jpg'));
      await source.writeAsBytes(List<int>.generate(4096, (i) => i % 256));

      final out = await FileStore.exportCopyVerified(
        sourcePath: source.path,
        directoryPath: destDir.path,
        fileName: 'photo.jpg',
      );

      expect(await File(out).exists(), isTrue);
      expect(await File(out).length(), 4096);
      expect(File(p.join(destDir.path, 'photo.jpg.part')).existsSync(), isFalse);
    });

    test('throws when source is missing', () async {
      expect(
        () => FileStore.exportCopyVerified(
          sourcePath: p.join(srcDir.path, 'missing.bin'),
          directoryPath: destDir.path,
          fileName: 'missing.bin',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('resolveUniquePath avoids overwrite', () async {
      final existing = File(p.join(destDir.path, 'dup.txt'));
      await existing.writeAsString('old');

      final unique = FileStore.resolveUniquePath(destDir.path, 'dup.txt');
      expect(unique, isNot(existing.path));
      expect(File(unique).existsSync(), isFalse);
    });
  });
}
