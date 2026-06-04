import 'dart:io' show Platform;

import 'package:path/path.dart' as p;

/// Windows device names (case-insensitive), with or without extension.
final _reservedWindowsNames = <String>{
  'CON',
  'PRN',
  'AUX',
  'NUL',
  for (var i = 0; i <= 9; i++) 'COM$i',
  for (var i = 0; i <= 9; i++) 'LPT$i',
};

/// Returns a single path segment safe for the current OS receive directory.
/// Preserves Unicode (e.g. CJK); strips path components, control characters,
/// and characters invalid in Windows file names.
String sanitizeFileNameForLocalStorage(String fileName) {
  var base = p.posix.basename(fileName.replaceAll(r'\', '/'));
  if (base.isEmpty || base == '.' || base == '..') {
    return 'file';
  }

  final sb = StringBuffer();
  for (final c in base.split('')) {
    final code = c.codeUnitAt(0);
    if (code < 0x20 || code == 0x7f) {
      sb.write('_');
      continue;
    }
    if (_isForbiddenFileNameChar(c)) {
      sb.write('_');
      continue;
    }
    sb.write(c);
  }
  base = sb.toString();
  if (base.isEmpty) return 'file';

  if (Platform.isWindows) {
    base = base.replaceAll(RegExp(r'[.\s]+$'), '');
    if (base.isEmpty) return 'file';
    final stem = p.basenameWithoutExtension(base).toUpperCase();
    if (_reservedWindowsNames.contains(stem)) {
      base = '${base}_';
    }
  }

  return base.isEmpty ? 'file' : base;
}

bool _isForbiddenFileNameChar(String c) {
  return c == '/' ||
      c == r'\' ||
      c == '<' ||
      c == '>' ||
      c == ':' ||
      c == '"' ||
      c == '|' ||
      c == '?' ||
      c == '*';
}
