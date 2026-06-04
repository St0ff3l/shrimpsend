import 'dart:io';

import 'package:app/file_save_preferences.dart';
import 'package:app/services/file_store.dart';
import 'package:app/utils/open_directory.dart';
import 'package:app/utils/windows_explorer_reveal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('normalizes mixed separators before passing paths to explorer', () {
    const mixedPath =
        r'C:\Users\Administrator\Documents\shrimpsend/message id/my file.txt';

    expect(
      windowsExplorerPath(mixedPath),
      r'C:\Users\Administrator\Documents\shrimpsend\message id\my file.txt',
    );
  });

  test(
    'normalizes custom save directory whitespace and trailing separator',
    () {
      final tempDir = Directory.systemTemp.createTempSync('shrimp send ');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final raw = '  ${tempDir.path}${Platform.pathSeparator}  ';
      final normalized = normalizeCustomSaveDirValue(raw);

      expect(normalized, p.normalize(tempDir.absolute.path));
      expect(normalized.endsWith(Platform.pathSeparator), isFalse);
    },
  );

  test('builds receive path under a directory with spaces', () {
    final tempDir = Directory.systemTemp.createTempSync('shrimp send ');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final rootWithTrailingSeparator =
        '${tempDir.path}${Platform.pathSeparator}';
    final receivePath = FileStore.buildReceivePathSync(
      rootWithTrailingSeparator,
      'message id',
      'my file.txt',
    );

    expect(p.basename(receivePath), 'my file.txt');
    expect(p.basename(p.dirname(receivePath)), 'message id');
    expect(
      p.normalize(receivePath),
      p.join(tempDir.absolute.path, 'message id', 'my file.txt'),
    );
  });

  // Smoke test that actually invokes the Win32 shell API and pops up an
  // Explorer window. Skipped by default to keep `flutter test` clean; opt in
  // via `RUN_WIN_SHELL_SMOKE=1` when manually verifying on Windows.
  test(
    'windowsRevealInExplorer succeeds for a path with spaces',
    () {
      final tempDir = Directory.systemTemp.createTempSync('shrimp send ');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final filePath = p.join(tempDir.path, 'my file.txt');
      File(filePath).writeAsStringSync('hello');

      expect(windowsRevealInExplorer(filePath), isTrue);
    },
    skip: !Platform.isWindows ||
            Platform.environment['RUN_WIN_SHELL_SMOKE'] != '1'
        ? 'set RUN_WIN_SHELL_SMOKE=1 on Windows to opt into this smoke test'
        : false,
  );
}
