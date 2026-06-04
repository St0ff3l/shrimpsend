/// Where received files are exported for user-visible storage.
enum VisibleExportKind {
  /// Android MediaStore Downloads or desktop ~/Downloads.
  downloads,

  /// iOS application Documents (Files app).
  documents,

  /// User-selected POSIX directory (desktop / iOS).
  customDir,

  /// Android SAF document tree URI.
  safTree,
}

/// Resolved visible export destination (default or user override).
class VisibleExportTarget {
  final VisibleExportKind kind;
  final String displayName;

  /// POSIX directory for flat file copy (custom / documents / desktop downloads).
  final String? posixPath;

  /// Android SAF `content://` tree URI.
  final String? safTreeUri;

  const VisibleExportTarget({
    required this.kind,
    required this.displayName,
    this.posixPath,
    this.safTreeUri,
  });

  bool get isCustom =>
      kind == VisibleExportKind.customDir || kind == VisibleExportKind.safTree;
}

/// Export pipeline status stored in `received_files.export_status`.
enum ExportStatus {
  pending,
  exporting,
  done,
  failed,

  /// Pre-migration rows that already lived in the old receive root.
  legacy,
}

/// Recorded export backend for analytics / settings display.
enum ExportTargetKind {
  downloads,
  documents,
  custom,
  saf,
  gallery,
}
