import 'package:app/services/receive_dir_resolver.dart';
import 'package:app/services/visible_export_target.dart';
import 'package:app/utils/effective_save_dir_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatEffectiveSaveDir', () {
    test('returns custom posixPath instead of cache staging path', () {
      const cachePath = r'C:\Users\Admin\AppData\Local\Temp\shrimpsend';
      const customPath = r'D:\TestSave';

      final resolution = ReceiveDirResolution(
        path: cachePath,
        kind: ReceiveStorageKind.appCache,
        isCustom: true,
        visibleExportTarget: VisibleExportTarget(
          kind: VisibleExportKind.customDir,
          displayName: 'TestSave',
          posixPath: customPath,
        ),
      );

      expect(formatEffectiveSaveDir(resolution), customPath);
      expect(formatEffectiveSaveDir(resolution), isNot(cachePath));
    });

    test('returns downloads posixPath when no custom dir is set', () {
      const cachePath = '/var/folders/xx/T/shrimpsend';
      const downloadsPath = '/Users/me/Downloads';

      final resolution = ReceiveDirResolution(
        path: cachePath,
        kind: ReceiveStorageKind.appCache,
        visibleExportTarget: VisibleExportTarget(
          kind: VisibleExportKind.downloads,
          displayName: 'Downloads',
          posixPath: downloadsPath,
        ),
      );

      expect(formatEffectiveSaveDir(resolution), downloadsPath);
      expect(formatEffectiveSaveDir(resolution), isNot(cachePath));
    });

    test('falls back to SAF display name when visible target is absent', () {
      const cachePath = '/data/user/0/com.example/cache/shrimpsend';

      final resolution = ReceiveDirResolution(
        path: cachePath,
        kind: ReceiveStorageKind.appCache,
        customSafTreeUri: 'content://com.android.externalstorage.documents/tree/primary%3ADownload',
        customSafDisplayName: 'Download',
      );

      expect(formatEffectiveSaveDir(resolution), 'Download');
    });

    test('falls back to SAF URI when display name is empty', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3ADownload';

      final resolution = ReceiveDirResolution(
        path: '/cache/shrimpsend',
        kind: ReceiveStorageKind.appCache,
        customSafTreeUri: uri,
      );

      expect(formatEffectiveSaveDir(resolution), uri);
    });

    test('falls back to resolution.path when no export target is available', () {
      const cachePath = '/tmp/shrimpsend';

      final resolution = ReceiveDirResolution(
        path: cachePath,
        kind: ReceiveStorageKind.appCache,
      );

      expect(formatEffectiveSaveDir(resolution), cachePath);
    });

    test('uses displayName when visible target has no posixPath', () {
      final resolution = ReceiveDirResolution(
        path: '/tmp/shrimpsend',
        kind: ReceiveStorageKind.appCache,
        visibleExportTarget: const VisibleExportTarget(
          kind: VisibleExportKind.safTree,
          displayName: 'MyFolder',
          safTreeUri: 'content://tree/example',
        ),
      );

      expect(formatEffectiveSaveDir(resolution), 'MyFolder');
    });
  });
}
