import 'open_directory.dart';

/// Reveal [path] in the platform file manager (Finder / Explorer / file manager).
///
/// Thin wrapper around [revealFileInFileManager] kept for callers that don't
/// need the success boolean. Centralizing the implementation guarantees that
/// the Win32 shell-based fix used on Windows applies everywhere.
Future<void> revealFileInFolder(String path) async {
  await revealFileInFileManager(path);
}
