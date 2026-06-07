import '../services/receive_dir_resolver.dart';

/// User-visible save path label for settings (prefers full [posixPath]).
String formatEffectiveSaveDir(ReceiveDirResolution resolution) {
  final visible = resolution.visibleExportTarget;
  if (visible != null) {
    final posix = visible.posixPath?.trim();
    if (posix != null && posix.isNotEmpty) return posix;
    return visible.displayName;
  }
  if (resolution.customSafTreeUri != null) {
    final name = resolution.customSafDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return resolution.customSafTreeUri!;
  }
  return resolution.path;
}
