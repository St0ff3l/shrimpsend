import 'dart:io';

import 'package:app/services/receive_dir_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ReceiveDirResolver.desktopDownloadsCandidatesFromEnv', () {
    test('returns Downloads then home on Windows when Downloads missing', () {
      final temp = Directory.systemTemp.createTempSync('receive_dir_test_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final candidates = ReceiveDirResolver.desktopDownloadsCandidatesFromEnv(
        {'USERPROFILE': temp.path},
        isWindows: true,
      );

      expect(candidates, [p.join(temp.path, 'Downloads'), temp.path]);
    });

    test('returns only Downloads when it exists on Unix', () {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return;

      final downloads = Directory(p.join(home, 'Downloads'));
      if (!downloads.existsSync()) return;

      final candidates = ReceiveDirResolver.desktopDownloadsCandidatesFromEnv(
        {'HOME': home},
        isWindows: false,
      );

      expect(candidates, [downloads.path.replaceAll('\\', '/')]);
    });

    test('returns empty list when home env is missing', () {
      expect(
        ReceiveDirResolver.desktopDownloadsCandidatesFromEnv(
          const {},
          isWindows: false,
        ),
        isEmpty,
      );
    });
  });

  group('ReceiveDirResolver Android helpers', () {
    test('androidPublicDownloadBases prefers sdcard alias first', () {
      expect(
        ReceiveDirResolver.androidPublicDownloadBases.first,
        '/sdcard/Download',
      );
      expect(
        ReceiveDirResolver.androidPublicDownloadBases,
        contains('/storage/emulated/0/Download'),
      );
    });

    test('isAndroidAppSpecificExternalPath detects app scoped paths', () {
      expect(
        ReceiveDirResolver.isAndroidAppSpecificExternalPath(
          '/storage/emulated/0/Android/data/com.example.app/files/Download',
        ),
        isTrue,
      );
      expect(
        ReceiveDirResolver.isAndroidAppSpecificExternalPath(
          '/storage/emulated/0/Android/media/com.example.app',
        ),
        isTrue,
      );
      expect(
        ReceiveDirResolver.isAndroidAppSpecificExternalPath(
          '/storage/emulated/0/Download',
        ),
        isFalse,
      );
      expect(
        ReceiveDirResolver.isAndroidAppSpecificExternalPath('/sdcard/Download'),
        isFalse,
      );
    });

    test('dedupeAndroidPublicBases keeps distinct paths', () {
      final deduped = ReceiveDirResolver.dedupeAndroidPublicBases([
        '/sdcard/Download',
        '/storage/emulated/0/Download',
      ]);
      expect(deduped.length, greaterThanOrEqualTo(1));
      expect(deduped.first, '/sdcard/Download');
    });

    test('dedupeAndroidPublicBases collapses exact duplicates', () {
      final deduped = ReceiveDirResolver.dedupeAndroidPublicBases([
        '/sdcard/Download/',
        '/sdcard/Download',
      ]);
      expect(deduped, ['/sdcard/Download']);
    });

    test('androidReceiveBaseCandidates orders public before app external', () {
      final appDownloads =
          '/storage/emulated/0/Android/data/dev.ultrasend.app/files/Download';
      final candidates = ReceiveDirResolver.androidReceiveBaseCandidates(
        pathProviderDownloads: appDownloads,
        externalStorageDir: '/storage/emulated/0/Android/data/dev.ultrasend.app/files',
      );

      expect(candidates.first.kind, ReceiveStorageKind.publicExternal);
      expect(
        candidates.last.kind,
        ReceiveStorageKind.appExternal,
      );
      expect(
        candidates.any((c) => c.path == appDownloads),
        isTrue,
      );
    });

    test('androidReceiveBaseCandidates dedupes identical provider paths', () {
      final same =
          '/storage/emulated/0/Android/data/dev.ultrasend.app/files/Download';
      final candidates = ReceiveDirResolver.androidReceiveBaseCandidates(
        pathProviderDownloads: same,
        externalStorageDir: same,
      );

      final appExternal = candidates
          .where((c) => c.kind == ReceiveStorageKind.appExternal)
          .toList();
      expect(appExternal.length, 1);
    });
  });

  group('ReceiveDirResolver iOS Files fallback', () {
    test('defaultReceiveDirName matches Documents subfolder', () {
      expect(ReceiveDirResolver.defaultReceiveDirName, 'shrimpsend');
    });

    test('iosDownloadsDirName is Downloads', () {
      expect(ReceiveDirResolver.iosDownloadsDirName, 'Downloads');
    });
  });
}
