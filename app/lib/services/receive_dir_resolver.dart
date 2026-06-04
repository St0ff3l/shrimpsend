import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path;

import '../file_save_preferences.dart';
import 'saf_storage_service.dart';
import 'visible_export_target.dart';

/// How the active receive root is classified for settings UI.
enum ReceiveStorageKind {
  publicExternal,
  appExternal,
  appDocuments,
  appCache,
}

/// Ordered receive root base candidate (platform-specific).
class ReceiveBaseCandidate {
  final String path;
  final ReceiveStorageKind kind;

  const ReceiveBaseCandidate({
    required this.path,
    required this.kind,
  });
}

/// Result of resolving the default receive directory (before custom override).
class ReceiveDirResolution {
  final String path;
  final ReceiveStorageKind kind;
  final bool usedFallback;
  final bool isCustom;
  final String? intendedPath;
  final String? fallbackReason;
  /// Android SAF tree URI when user picked an external mirror folder.
  final String? customSafTreeUri;
  /// Human-readable label for [customSafTreeUri] (settings UI).
  final String? customSafDisplayName;
  /// User-visible flat export destination (Downloads / Documents / custom).
  final VisibleExportTarget? visibleExportTarget;

  const ReceiveDirResolution({
    required this.path,
    required this.kind,
    this.usedFallback = false,
    this.isCustom = false,
    this.intendedPath,
    this.fallbackReason,
    this.customSafTreeUri,
    this.customSafDisplayName,
    this.visibleExportTarget,
  });
}

/// Platform-specific default receive root under a dedicated app folder.
class ReceiveDirResolver {
  static const defaultReceiveDirName = 'shrimpsend';

  /// iOS user-visible receive folder under Documents (Files app).
  static const iosDownloadsDirName = 'Downloads';

  /// Public Download bases for Android (probe order: sdcard alias first).
  static const List<String> androidPublicDownloadBases = [
    '/sdcard/Download',
    '/storage/emulated/0/Download',
  ];

  /// Public Downloads base (no app subfolder), for desktop export copies.
  static Future<String?> getPublicDownloadsBase() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      for (final base in dedupeAndroidPublicBases(androidPublicDownloadBases)) {
        if (await _isPublicDownloadBaseWritable(base)) {
          return base;
        }
      }
      return null;
    }

    try {
      final base = await _resolvePreferredBasePath();
      if (base.kind == ReceiveStorageKind.publicExternal) {
        return _normalizePath(base.path);
      }
    } catch (_) {}

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      for (final candidate in desktopDownloadsCandidatesFromEnv(
        Platform.environment,
        isWindows: Platform.isWindows,
      )) {
        if (await Directory(candidate).exists()) {
          return _normalizePath(candidate);
        }
      }
    }
    return null;
  }

  static Future<ReceiveDirResolution> resolveDefault() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _resolveAndroidDefault();
    }

    final base = await _resolvePreferredBasePath();
    final intended = p.join(base.path, defaultReceiveDirName);
    try {
      final resolvedPath = await _prepareReceiveDir(intended);
      await clearReceiveDirFallback();
      return ReceiveDirResolution(
        path: resolvedPath,
        kind: base.kind,
        usedFallback: false,
      );
    } catch (e) {
      return _fallbackToAppCache(
        intendedPath: intended,
        reason: _formatError(e),
      );
    }
  }

  static Future<ReceiveDirResolution> _resolveAndroidDefault() async {
    final pathProviderDownloads = await path.getDownloadsDirectory();
    final externalStorage = await path.getExternalStorageDirectory();
    final candidates = androidReceiveBaseCandidates(
      pathProviderDownloads: pathProviderDownloads?.path,
      externalStorageDir: externalStorage?.path,
    );

    Object? lastError;
    String? firstIntended;

    for (final candidate in candidates) {
      final intended = p.join(candidate.path, defaultReceiveDirName);
      firstIntended ??= intended;
      try {
        final resolvedPath = await _prepareReceiveDir(intended);
        await clearReceiveDirFallback();
        return ReceiveDirResolution(
          path: resolvedPath,
          kind: candidate.kind,
          usedFallback: false,
        );
      } catch (e) {
        lastError = e;
      }
    }

    final fallbackIntended =
        firstIntended ??
        p.join(androidPublicDownloadBases.first, defaultReceiveDirName);
    return _fallbackToAppCache(
      intendedPath: fallbackIntended,
      reason: _formatError(lastError ?? 'No writable Android receive base'),
    );
  }

  /// Whether [path] is under app-scoped external storage (cleared with app data).
  static bool isAndroidAppSpecificExternalPath(String path) {
    final normalized = _normalizePath(path);
    return normalized.contains('/Android/data/') ||
        normalized.contains('/Android/media/');
  }

  /// Deduplicate public Download bases (symlink-equivalent paths).
  static List<String> dedupeAndroidPublicBases(List<String> bases) {
    final seen = <String>{};
    final out = <String>[];
    for (final base in bases) {
      final trimmed = _trimTrailingSlashes(_normalizePath(base));
      if (trimmed.isEmpty) continue;
      final key = _canonicalDedupeKey(trimmed);
      if (seen.add(key)) {
        out.add(trimmed);
      }
    }
    return out;
  }

  /// Android receive bases: public Download(s) first, then app-specific external.
  static List<ReceiveBaseCandidate> androidReceiveBaseCandidates({
    String? pathProviderDownloads,
    String? externalStorageDir,
  }) {
    final out = <ReceiveBaseCandidate>[];
    final seen = <String>{};

    void add(String rawPath, ReceiveStorageKind kind) {
      final normalized = _trimTrailingSlashes(_normalizePath(rawPath));
      if (normalized.isEmpty) return;
      final key = _canonicalDedupeKey(normalized);
      if (!seen.add(key)) return;
      out.add(ReceiveBaseCandidate(path: normalized, kind: kind));
    }

    for (final base in dedupeAndroidPublicBases(androidPublicDownloadBases)) {
      add(base, ReceiveStorageKind.publicExternal);
    }

    for (final raw in [pathProviderDownloads, externalStorageDir]) {
      if (raw == null || raw.trim().isEmpty) continue;
      final normalized = _normalizePath(raw);
      if (isAndroidAppSpecificExternalPath(normalized)) {
        add(normalized, ReceiveStorageKind.appExternal);
      }
    }

    return out;
  }

  static Future<_BasePath> _resolvePreferredBasePath() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw StateError(
          'Use _resolveAndroidDefault instead of _resolvePreferredBasePath',
        );
      case TargetPlatform.iOS:
        final dir = await path.getApplicationDocumentsDirectory();
        return _BasePath(
          path: _normalizePath(dir.path),
          kind: ReceiveStorageKind.appDocuments,
        );
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        var downloadDir = await path.getDownloadsDirectory();
        if (downloadDir == null) {
          final candidates = desktopDownloadsCandidatesFromEnv(
            Platform.environment,
            isWindows: defaultTargetPlatform == TargetPlatform.windows,
          );
          for (final candidate in candidates) {
            final dir = Directory(candidate);
            if (dir.existsSync()) {
              downloadDir = dir;
              break;
            }
          }
          if (downloadDir == null && candidates.isNotEmpty) {
            downloadDir = Directory(candidates.first);
          }
        }
        if (downloadDir == null) {
          throw const FileSystemException('Downloads directory unavailable');
        }
        return _BasePath(
          path: _normalizePath(downloadDir.path),
          kind: ReceiveStorageKind.publicExternal,
        );
      case TargetPlatform.fuchsia:
        final dir = await path.getDownloadsDirectory();
        if (dir != null) {
          return _BasePath(
            path: _normalizePath(dir.path),
            kind: ReceiveStorageKind.publicExternal,
          );
        }
        final docs = await path.getApplicationDocumentsDirectory();
        return _BasePath(
          path: _normalizePath(docs.path),
          kind: ReceiveStorageKind.appDocuments,
        );
    }
  }

  /// Desktop Downloads candidates from environment (testable).
  static List<String> desktopDownloadsCandidatesFromEnv(
    Map<String, String> environment, {
    required bool isWindows,
  }) {
    final homeKey = isWindows ? 'USERPROFILE' : 'HOME';
    final homeDir = environment[homeKey];
    if (homeDir == null || homeDir.trim().isEmpty) return const [];
    final home = _normalizePath(homeDir);
    final downloads = p.join(home, 'Downloads');
    if (Directory(downloads).existsSync()) {
      return [downloads];
    }
    return [downloads, home];
  }

  static Future<bool> _isPublicDownloadBaseWritable(String base) async {
    try {
      await _prepareReceiveDir(p.join(base, defaultReceiveDirName));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Receive root used when the preferred base cannot be prepared.
  /// iOS uses Documents/Downloads (visible in Files); other platforms use app cache (tmp).
  static Future<String> fallbackReceiveRootPath() async {
    if (Platform.isIOS) {
      final downloads = await resolveIosDownloadsBase();
      return p.join(downloads, defaultReceiveDirName);
    }
    final cache = await path.getTemporaryDirectory();
    return p.join(_normalizePath(cache.path), defaultReceiveDirName);
  }

  static ReceiveStorageKind get _fallbackStorageKind => Platform.isIOS
      ? ReceiveStorageKind.appDocuments
      : ReceiveStorageKind.appCache;

  static Future<ReceiveDirResolution> _fallbackToAppCache({
    required String intendedPath,
    required String reason,
  }) async {
    final fallbackPath = await fallbackReceiveRootPath();
    try {
      final resolvedPath = await _prepareReceiveDir(fallbackPath);
      await setReceiveDirFallback(
        intendedPath: intendedPath,
        fallbackReason: reason,
        currentPath: resolvedPath,
      );
      return ReceiveDirResolution(
        path: resolvedPath,
        kind: _fallbackStorageKind,
        usedFallback: true,
        intendedPath: intendedPath,
        fallbackReason: reason,
      );
    } catch (e) {
      final nested = _formatError(e);
      await setReceiveDirFallback(
        intendedPath: intendedPath,
        fallbackReason: '$reason; cache: $nested',
        currentPath: fallbackPath,
      );
      return ReceiveDirResolution(
        path: fallbackPath,
        kind: _fallbackStorageKind,
        usedFallback: true,
        intendedPath: intendedPath,
        fallbackReason: '$reason; cache: $nested',
      );
    }
  }

  static Future<String> _prepareReceiveDir(String dirPath) async {
    await ensureDirectory(dirPath);
    await assertWritableDirectory(dirPath);
    return dirPath;
  }

  static Future<String> ensureDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<void> assertWritableDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw FileSystemException('Directory does not exist', dirPath);
    }
    final probe = File(
      p.join(
        dir.path,
        '.shrimpsend_write_test_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await probe.writeAsString('ok', flush: true);
    try {
      await probe.delete();
    } catch (_) {}
  }

  static String _normalizePath(String value) {
    return value.replaceAll('\\', '/');
  }

  static String _trimTrailingSlashes(String value) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  static String _canonicalDedupeKey(String normalizedPath) {
    try {
      final dir = Directory(normalizedPath);
      if (dir.existsSync()) {
        return _normalizePath(dir.resolveSymbolicLinksSync());
      }
    } catch (_) {}
    return normalizedPath.toLowerCase();
  }

  static String _formatError(Object e) {
    if (e is FileSystemException) {
      return e.message.isNotEmpty ? e.message : e.toString();
    }
    final text = e.toString();
    return text.length > 240 ? '${text.substring(0, 237)}...' : text;
  }

  /// Staging directory for in-flight receives: `<temp>/shrimpsend`.
  static Future<String> resolveCacheDir() async {
    final cache = await path.getTemporaryDirectory();
    final dir = p.join(_normalizePath(cache.path), defaultReceiveDirName);
    return ensureDirectory(dir);
  }

  /// Default iOS visible export root: Documents/Downloads (keeps SQLite out of the same folder).
  static Future<String> resolveIosDownloadsBase() async {
    final docs = await path.getApplicationDocumentsDirectory();
    return ensureDirectory(
      p.join(_normalizePath(docs.path), iosDownloadsDirName),
    );
  }

  /// Resolve where completed files are copied for user-visible access.
  static Future<VisibleExportTarget> resolveVisibleExportTarget() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final treeUri = await getCustomSaveTreeUri();
      if (treeUri != null && treeUri.isNotEmpty) {
        final storedName = await getCustomSaveTreeDisplayName();
        final displayName = storedName?.trim().isNotEmpty == true
            ? storedName!.trim()
            : (SafStorageService.isSupported
                ? await SafStorageService.getDisplayName(treeUri)
                : treeUri);
        return VisibleExportTarget(
          kind: VisibleExportKind.safTree,
          displayName: displayName,
          safTreeUri: treeUri,
        );
      }
      return const VisibleExportTarget(
        kind: VisibleExportKind.downloads,
        displayName: 'Download',
      );
    }

    final customDir = await getCustomSaveDir();
    if (customDir != null && customDir.trim().isNotEmpty) {
      final resolved = await ensureDirectory(customDir);
      return VisibleExportTarget(
        kind: VisibleExportKind.customDir,
        displayName: p.basename(resolved),
        posixPath: resolved,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final downloads = await resolveIosDownloadsBase();
      return VisibleExportTarget(
        kind: VisibleExportKind.downloads,
        displayName: 'Downloads',
        posixPath: downloads,
      );
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloads = await getPublicDownloadsBase();
      if (downloads != null && downloads.isNotEmpty) {
        final resolved = await ensureDirectory(downloads);
        return VisibleExportTarget(
          kind: VisibleExportKind.downloads,
          displayName: p.basename(resolved),
          posixPath: resolved,
        );
      }
    }

    return VisibleExportTarget(
      kind: VisibleExportKind.downloads,
      displayName: 'Downloads',
      posixPath: await fallbackReceiveRootPath(),
    );
  }
}

class _BasePath {
  final String path;
  final ReceiveStorageKind kind;

  const _BasePath({
    required this.path,
    required this.kind,
  });
}
