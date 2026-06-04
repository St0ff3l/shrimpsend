import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'windows_explorer_reveal.dart';

/// 在系统文件管理器中打开目录（桌面端用于打开日志所在文件夹等）。
Future<bool> openDirectoryInFileManager(String directoryPath) async {
  final dir = Directory(directoryPath);
  if (!await dir.exists()) return false;

  final normalized = directoryPath.endsWith(Platform.pathSeparator)
      ? directoryPath
      : '$directoryPath${Platform.pathSeparator}';
  final uri = Uri.file(normalized);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (_) {}

  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [windowsExplorerPath(directoryPath)]);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [directoryPath]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [directoryPath]);
      return true;
    }
  } catch (_) {}
  return false;
}

/// Last-line defense for paths headed to Windows shell APIs / `explorer.exe`:
/// some historical index rows still mix forward and back slashes.
String windowsExplorerPath(String filePath) {
  return filePath.replaceAll('/', r'\');
}

/// 在系统文件管理器中显示文件所在位置，并尽量选中文件。
Future<bool> revealFileInFileManager(String filePath) async {
  final file = File(filePath);
  final normalizedPath = file.absolute.path;
  final parentPath = file.parent.absolute.path;
  final exists = await file.exists();

  if (!exists) {
    return openDirectoryInFileManager(parentPath);
  }

  try {
    if (Platform.isWindows) {
      final shellPath = windowsExplorerPath(normalizedPath);
      // Prefer the Win32 shell API: it bypasses Dart's command-line argument
      // escaping, which mangled `/select,` calls for paths with spaces.
      if (windowsRevealInExplorer(shellPath)) {
        return true;
      }
      // If the shell API failed for any reason, fall back to opening the
      // parent directory rather than nothing.
      return openDirectoryInFileManager(parentPath);
    }
    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-R', normalizedPath]);
      if (result.exitCode == 0) return true;
      return openDirectoryInFileManager(parentPath);
    }
    if (Platform.isLinux) {
      return openDirectoryInFileManager(parentPath);
    }
  } catch (_) {
    return openDirectoryInFileManager(parentPath);
  }
  return false;
}
