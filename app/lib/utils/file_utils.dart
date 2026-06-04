enum FileCategory { image, video, audio, pdf, archive, document, code, other }

const _extMap = <String, FileCategory>{
  'jpg': FileCategory.image,
  'jpeg': FileCategory.image,
  'png': FileCategory.image,
  'gif': FileCategory.image,
  'webp': FileCategory.image,
  'svg': FileCategory.image,
  'bmp': FileCategory.image,
  'heic': FileCategory.image,
  'ico': FileCategory.image,
  'tiff': FileCategory.image,
  'mp4': FileCategory.video,
  'mov': FileCategory.video,
  'avi': FileCategory.video,
  'mkv': FileCategory.video,
  'webm': FileCategory.video,
  'flv': FileCategory.video,
  'wmv': FileCategory.video,
  'mp3': FileCategory.audio,
  'wav': FileCategory.audio,
  'flac': FileCategory.audio,
  'aac': FileCategory.audio,
  'ogg': FileCategory.audio,
  'm4a': FileCategory.audio,
  'wma': FileCategory.audio,
  'pdf': FileCategory.pdf,
  'zip': FileCategory.archive,
  'rar': FileCategory.archive,
  '7z': FileCategory.archive,
  'tar': FileCategory.archive,
  'gz': FileCategory.archive,
  'bz2': FileCategory.archive,
  'xz': FileCategory.archive,
  'doc': FileCategory.document,
  'docx': FileCategory.document,
  'xls': FileCategory.document,
  'xlsx': FileCategory.document,
  'ppt': FileCategory.document,
  'pptx': FileCategory.document,
  'txt': FileCategory.document,
  'csv': FileCategory.document,
  'md': FileCategory.document,
  'rtf': FileCategory.document,
  'js': FileCategory.code,
  'ts': FileCategory.code,
  'jsx': FileCategory.code,
  'tsx': FileCategory.code,
  'py': FileCategory.code,
  'java': FileCategory.code,
  'go': FileCategory.code,
  'rs': FileCategory.code,
  'c': FileCategory.code,
  'cpp': FileCategory.code,
  'h': FileCategory.code,
  'html': FileCategory.code,
  'css': FileCategory.code,
  'json': FileCategory.code,
  'xml': FileCategory.code,
  'yaml': FileCategory.code,
  'yml': FileCategory.code,
  'sh': FileCategory.code,
  'dart': FileCategory.code,
  'swift': FileCategory.code,
  'kt': FileCategory.code,
};

FileCategory getFileCategory(String? fileName) {
  if (fileName == null || !fileName.contains('.')) return FileCategory.other;
  final ext = fileName.split('.').last.toLowerCase();
  return _extMap[ext] ?? FileCategory.other;
}

/// `.apk` plus QQ/WeChat download renames like `.apk.1`, `.apk.2`.
final _apkInstallerNameSuffix = RegExp(r'\.apk(\.\d+)?$', caseSensitive: false);

bool looksLikeApkInstallerFileName(String fileName) =>
    _apkInstallerNameSuffix.hasMatch(fileName);

String formatFileSize(int? bytes) {
  if (bytes == null || bytes < 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Parses strings produced by [formatFileSize] / [formatSize]-style labels (e.g. `12.3 MB`).
int? tryParseFormattedFileSize(String? input) {
  if (input == null || input.isEmpty) return null;
  final trimmed = input.trim();
  final m = RegExp(
    r'^([\d.]+)\s*(B|KB|MB|GB)\s*$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (m == null) return null;
  final n = double.tryParse(m.group(1)!);
  if (n == null || n < 0) return null;
  final unit = m.group(2)!.toUpperCase();
  final factor = switch (unit) {
    'B' => 1,
    'KB' => 1024,
    'MB' => 1024 * 1024,
    'GB' => 1024 * 1024 * 1024,
    _ => null,
  };
  if (factor == null) return null;
  return (n * factor).round();
}

/// Reads the last `( … )` segment from UI copy like `name (12.3 MB)` as bytes.
int? tryParseTrailingParenFileSize(String text) {
  final open = text.lastIndexOf('(');
  final close = text.lastIndexOf(')');
  if (open < 0 || close <= open) return null;
  return tryParseFormattedFileSize(text.substring(open + 1, close));
}
