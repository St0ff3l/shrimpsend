import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../config/update_config.dart';

class PlatformUpdater {
  String? _preparedScriptPath;
  String? _lastError;

  /// Last failure reason when [installUpdate] returned false (for UI / logging).
  String? get lastError => _lastError;

  void _clearError() {
    _lastError = null;
  }

  void _fail(String reason) {
    _lastError = reason;
    _log(reason);
  }

  void _log(String message) {
    UpdateConfig().logLine('[PlatformUpdater] $message');
  }

  Future<bool> installUpdate(String zipPath) async {
    _clearError();
    try {
      _log('Starting installation: $zipPath');

      final extractPath = await _extractZip(zipPath);
      if (extractPath == null) {
        _fail('Failed to extract ZIP');
        return false;
      }

      final newAppPath = await _findApp(extractPath);
      if (newAppPath == null) {
        _fail('Failed to find app in extracted files (check appExecutableBaseName matches packaged exe)');
        return false;
      }

      final scriptPath = await _createUpdateScript(newAppPath);
      if (scriptPath == null) {
        _fail('Failed to create update script');
        return false;
      }

      _preparedScriptPath = scriptPath;
      _log('Update ready, waiting for user to restart');

      return true;
    } catch (e, st) {
      _fail('Error: $e');
      UpdateConfig().logLine('[PlatformUpdater] stack: $st');
      if (kDebugMode) {
        // ignore: avoid_print
        print(st);
      }
      return false;
    }
  }

  Future<String?> _extractZip(String zipPath) async {
    if (Platform.isMacOS) {
      return await _extractWithDitto(zipPath);
    }

    return await _extractWithArchivePackage(zipPath);
  }

  Future<String?> _extractWithDitto(String zipPath) async {
    try {
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extractPath = path.join(tempDir.path, 'app-update-extracted-$timestamp');

      _log('Extracting with ditto to: $extractPath');

      await Directory(extractPath).create(recursive: true);

      final result = await Process.run('ditto', [
        '-x',
        '-k',
        zipPath,
        extractPath,
      ]);

      if (result.exitCode != 0) {
        _log('Ditto error: ${result.stderr}');
        throw Exception('ditto failed: ${result.stderr}');
      }

      _log('Extraction complete with ditto');
      return extractPath;
    } catch (e) {
      _log('Ditto extract error: $e');
      return null;
    }
  }

  Future<String?> _extractWithArchivePackage(String zipPath) async {
    try {
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extractPath = path.join(tempDir.path, 'app-update-extracted-$timestamp');

      _log('Reading ZIP file...');
      final bytes = await File(zipPath).readAsBytes();

      _log('Decoding ZIP...');
      final archive = ZipDecoder().decodeBytes(bytes);

      _log('Extracting ${archive.length} files to: $extractPath');
      final extractDir = Directory(extractPath);
      await extractDir.create(recursive: true);

      for (final file in archive) {
        final filename = path.join(extractPath, file.name);

        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);

          if (Platform.isMacOS || Platform.isLinux) {
            try {
              await Process.run('chmod', ['+x', filename]);
            } catch (e) {
              // Ignore chmod errors for non-executables
            }
          }
        } else {
          await Directory(filename).create(recursive: true);
        }
      }

      _log('Extraction complete: $extractPath');
      return extractPath;
    } catch (e) {
      _log('Extract error: $e');
      return null;
    }
  }

  Future<String?> _findApp(String extractPath) async {
    try {
      _log('Searching for app in: $extractPath');
      final dir = Directory(extractPath);
      final baseName = UpdateConfig().appExecutableBaseName;

      if (Platform.isMacOS) {
        String? bestMatch;
        int bestDepth = 1 << 30;
        await for (final entity in dir.list(recursive: true)) {
          if (entity is! Directory) continue;
          final name = path.basename(entity.path);
          if (!name.endsWith('.app')) continue;
          final rel = path.relative(entity.path, from: extractPath);
          final depth = path.split(rel).length;
          if (depth < bestDepth) {
            bestDepth = depth;
            bestMatch = entity.path;
          }
        }
        if (bestMatch != null) {
          _log('Found macOS app: $bestMatch (depth=$bestDepth)');
          return bestMatch;
        }
        _log('No .app found under $extractPath');
        return null;
      }

      await for (final entity in dir.list(recursive: true)) {
        final name = path.basename(entity.path);

        if (Platform.isWindows) {
          if (entity is File && name.toLowerCase().endsWith('.exe')) {
            final stem = path.basenameWithoutExtension(name).toLowerCase();
            final matches = baseName != null
                ? stem == baseName.toLowerCase()
                : name.toLowerCase().contains('staffco');
            if (matches) {
              _log('Found Windows exe: ${entity.parent.path}');
              return entity.parent.path;
            }
          }
        } else if (Platform.isLinux) {
          if (entity is File) {
            if (name.endsWith('.AppImage')) {
              _log('Found Linux AppImage: ${entity.parent.path}');
              return entity.parent.path;
            }
            final n = name.toLowerCase();
            if (baseName != null) {
              if (n == baseName.toLowerCase() && await _isExecutable(entity.path)) {
                _log('Found Linux binary: ${entity.parent.path}');
                return entity.parent.path;
              }
            } else if (n == 'staffco' && await _isExecutable(entity.path)) {
              _log('Found Linux binary: ${entity.parent.path}');
              return entity.parent.path;
            }
          }
        }
      }

      _log('App not found in extracted files');
      return null;
    } catch (e) {
      _log('Find app error: $e');
      return null;
    }
  }

  /// VBS strings use `""` as the escape for `"`. Backslashes need no escaping.
  String _escapeVbsString(String input) => input.replaceAll('"', '""');

  /// wscript only reliably handles non-ASCII paths embedded in script content
  /// when the file is UTF-16 LE with a BOM. UTF-8 (with or without BOM) gets
  /// misinterpreted as the system ANSI codepage on many Chinese installs.
  Future<void> _writeUtf16LeWithBom(String filePath, String content) async {
    final units = content.codeUnits;
    final bytes = Uint8List(2 + units.length * 2);
    bytes[0] = 0xFF;
    bytes[1] = 0xFE;
    var i = 2;
    for (final unit in units) {
      bytes[i++] = unit & 0xFF;
      bytes[i++] = (unit >> 8) & 0xFF;
    }
    await File(filePath).writeAsBytes(bytes, flush: true);
  }

  Future<bool> _isExecutable(String filePath) async {
    try {
      final result = await Process.run('test', ['-x', filePath]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _createUpdateScript(String newAppPath) async {
    try {
      final tempDir = Directory.systemTemp;
      final currentExe = Platform.resolvedExecutable;

      if (Platform.isMacOS) {
        final currentAppPath = _getMacOSAppPath(currentExe);
        final scriptPath = path.join(tempDir.path, 'update_helper.sh');

        bool needsSudo = false;
        if (currentAppPath.startsWith('/Applications/')) {
          try {
            final ownerResult = await Process.run('stat', ['-f', '%Su', currentAppPath]);
            final userResult = await Process.run('whoami', []);

            final owner = ownerResult.stdout.toString().trim();
            final currentUser = userResult.stdout.toString().trim();

            needsSudo = (owner != currentUser);
            _log('Path: $currentAppPath');
            _log('Owner: $owner, User: $currentUser');
            _log('Needs sudo: $needsSudo');
          } catch (e) {
            _log('Could not check ownership: $e');
          }
        }

        final script = needsSudo
            ? _createMacOSSudoScript(currentAppPath, newAppPath, scriptPath)
            : _createMacOSNormalScript(currentAppPath, newAppPath, scriptPath);

        await File(scriptPath).writeAsString(script);
        await Process.run('chmod', ['+x', scriptPath]);

        _log('Created macOS script: $scriptPath');
        return scriptPath;
      } else if (Platform.isWindows) {
        final currentDir = path.dirname(currentExe);
        final vbsPath = path.join(tempDir.path, 'update_silent.vbs');

        final needsAdmin = currentDir.toLowerCase().contains('program files');
        _log('Installation path: $currentDir');
        _log('Needs admin: $needsAdmin');

        final escSrc = _escapeVbsString(newAppPath);
        final escDst = _escapeVbsString(currentDir);
        final escExe = _escapeVbsString(currentExe);
        final needsAdminLiteral = needsAdmin ? 'True' : 'False';

        final vbsScript = '''
Option Explicit

Dim args, currentPID, phase, sh, fso, i, ok, rc, exePath, needsAdmin
Dim srcDir, dstDir, xcopyCmd

Set args = WScript.Arguments
If args.Count < 1 Then WScript.Quit 1
currentPID = args(0)
phase = ""
If args.Count >= 2 Then phase = args(1)

needsAdmin = $needsAdminLiteral
srcDir = "$escSrc"
dstDir = "$escDst"
exePath = "$escExe"

If needsAdmin And phase <> "elevated" Then
    Dim shellApp
    Set shellApp = CreateObject("Shell.Application")
    shellApp.ShellExecute "wscript.exe", _
        """" & WScript.ScriptFullName & """ " & currentPID & " elevated", _
        "", "runas", 0
    WScript.Quit 0
End If

Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

WScript.Sleep 3000

On Error Resume Next
sh.Run "taskkill /F /PID " & currentPID, 0, True
Err.Clear
On Error Goto 0

WScript.Sleep 1500

xcopyCmd = "xcopy /E /I /Y /Q /R /H """ & srcDir & "\\*"" """ & dstDir & "\\"""

ok = False
For i = 1 To 8
    On Error Resume Next
    rc = sh.Run(xcopyCmd, 0, True)
    If Err.Number = 0 And rc = 0 Then
        ok = True
        Err.Clear
        On Error Goto 0
        Exit For
    End If
    Err.Clear
    On Error Goto 0
    WScript.Sleep 1000
Next

If ok Then
    On Error Resume Next
    sh.Run """" & exePath & """", 1, False
    Err.Clear
    On Error Goto 0
End If

On Error Resume Next
fso.DeleteFile WScript.ScriptFullName, True
''';

        await _writeUtf16LeWithBom(vbsPath, vbsScript);

        _log(
          'Wrote VBS (UTF-16 LE+BOM, ${vbsScript.length} chars): '
          '$vbsPath, needsAdmin=$needsAdmin',
        );
        return vbsPath;
      } else if (Platform.isLinux) {
        final currentDir = path.dirname(currentExe);
        final scriptPath = path.join(tempDir.path, 'update_helper.sh');

        final script = '''
#!/bin/bash
CURRENT_PID=\$1

echo "[Update Script] Starting update process..."
sleep 3

echo "[Update Script] Killing current app (PID: \$CURRENT_PID)..."
kill -9 \$CURRENT_PID 2>/dev/null

sleep 2

echo "[Update Script] Copying new files..."
cp -rf "$newAppPath"/* "$currentDir/"

echo "[Update Script] Setting permissions..."
chmod +x "$currentExe"

sleep 1

echo "[Update Script] Starting new app..."
"$currentExe" &

echo "[Update Script] Cleaning up..."
rm -f "$scriptPath"

echo "[Update Script] Done!"
''';

        await File(scriptPath).writeAsString(script);
        await Process.run('chmod', ['+x', scriptPath]);

        _log('Created Linux script: $scriptPath');
        return scriptPath;
      }

      return null;
    } catch (e) {
      _log('Script creation error: $e');
      return null;
    }
  }

  String _getMacOSAppPath(String executablePath) {
    final parts = executablePath.split('/');
    final appIndex = parts.indexWhere((part) => part.endsWith('.app'));
    if (appIndex != -1) {
      return parts.sublist(0, appIndex + 1).join('/');
    }
    return executablePath;
  }

  String _createMacOSSudoScript(String currentAppPath, String newAppPath, String scriptPath) {
    final appBaseName = UpdateConfig().appExecutableBaseName ?? 'app';
    return '''
#!/bin/bash
LOG="/tmp/app_update_helper.log"
exec >> "\$LOG" 2>&1
set -x
echo "=== Update (sudo) started at \$(date) ==="
echo "currentAppPath=$currentAppPath"
echo "newAppPath=$newAppPath"

case "$currentAppPath" in
  /private/var/folders/*/AppTranslocation/*)
    echo "ERROR: App is running from a translocated path. Please move the app to /Applications and try again."
    exit 10
    ;;
esac

osascript -e 'do shell script "sleep 3 && kill -9 '"\$1"' 2>/dev/null ; killall \\"$appBaseName\\" 2>/dev/null ; sleep 2 && rm -rf \\"$currentAppPath\\" && ditto \\"$newAppPath\\" \\"$currentAppPath\\" && chmod -R +x \\"$currentAppPath/Contents/MacOS/\\" && xattr -dr com.apple.quarantine \\"$currentAppPath\\" 2>/dev/null ; sleep 1 && open -n \\"$currentAppPath\\"" with administrator privileges'

echo "[Update Script] Cleaning up..."
rm -f "$scriptPath"

echo "=== Update (sudo) finished at \$(date) ==="
''';
  }

  String _createMacOSNormalScript(String currentAppPath, String newAppPath, String scriptPath) {
    final appBaseName = UpdateConfig().appExecutableBaseName ?? 'app';
    return '''
#!/bin/bash
LOG="/tmp/app_update_helper.log"
exec >> "\$LOG" 2>&1
set -x
echo "=== Update started at \$(date) ==="
CURRENT_PID=\$1
echo "currentPID=\$CURRENT_PID"
echo "currentAppPath=$currentAppPath"
echo "newAppPath=$newAppPath"

case "$currentAppPath" in
  /private/var/folders/*/AppTranslocation/*)
    echo "ERROR: App is running from a translocated path. macOS Gatekeeper has sandboxed the running .app to a temporary location, so it cannot replace itself in-place."
    echo "Please move the application to /Applications (or any non-translocated location) and try again."
    exit 10
    ;;
esac

PARENT_DIR="\$(dirname "$currentAppPath")"
if [ ! -w "\$PARENT_DIR" ]; then
  echo "ERROR: Parent directory not writable: \$PARENT_DIR"
  exit 11
fi

echo "[Update] Waiting for current app to exit..."
sleep 2

echo "[Update] Killing current app (PID: \$CURRENT_PID, name: $appBaseName)..."
kill -9 \$CURRENT_PID 2>/dev/null
killall "$appBaseName" 2>/dev/null

for i in 1 2 3 4 5; do
  if pgrep -x "$appBaseName" > /dev/null; then
    echo "[Update] $appBaseName still running, waiting..."
    sleep 1
  else
    break
  fi
done

echo "[Update] Removing old app: $currentAppPath"
rm -rf "$currentAppPath"
if [ -e "$currentAppPath" ]; then
  echo "ERROR: Failed to remove old app at $currentAppPath"
  exit 12
fi

echo "[Update] Copying new app with ditto (preserves code signature)..."
ditto "$newAppPath" "$currentAppPath"
if [ \$? -ne 0 ] || [ ! -d "$currentAppPath" ]; then
  echo "ERROR: ditto failed; new app was not installed."
  exit 13
fi

echo "[Update] Setting permissions..."
chmod -R +x "$currentAppPath/Contents/MacOS/"

echo "[Update] Removing quarantine attribute (if any)..."
xattr -dr com.apple.quarantine "$currentAppPath" 2>/dev/null || true

echo "[Update] Refreshing LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$currentAppPath" 2>/dev/null || true

sleep 1

echo "[Update] Opening new app..."
open -n "$currentAppPath"

echo "[Update] Cleaning up..."
rm -f "$scriptPath"

echo "=== Update finished at \$(date) ==="
''';
  }

  Future<void> restartApp() async {
    _log('User clicked restart button');

    if (_preparedScriptPath == null) {
      _log('No script prepared, just exiting');
      exit(0);
    }

    _log('Launching update script: $_preparedScriptPath');

    final currentPID = pid.toString();
    _log('Current PID: $currentPID');

    if (Platform.isWindows) {
      _log('Launching: wscript.exe "$_preparedScriptPath" $currentPID');
      await Process.start(
        'wscript.exe',
        [_preparedScriptPath!, currentPID],
        mode: ProcessStartMode.detached,
      );
    } else {
      await Process.start(
        'nohup',
        ['/bin/sh', _preparedScriptPath!, currentPID],
        mode: ProcessStartMode.detached,
        workingDirectory: Directory.systemTemp.path,
      );
    }

    _log('Script launched with PID, exiting app...');

    await Future.delayed(const Duration(milliseconds: 500));

    exit(0);
  }
}
