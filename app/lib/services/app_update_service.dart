import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path/path.dart' as p;

import '../api/client.dart';
import '../config/env.dart';
import '../logger.dart';

const _prefDownloadedVersion = 'app_update_downloaded_version';
/// Legacy: full path under old receive dir; migrated once to [apkPathForVersion].
const _prefDownloadedPath = 'app_update_downloaded_path';
const _prefDismissedVersion = 'app_update_dismissed_version';

/// Remote version info from server.
class UpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final String iosStoreUrl;
  final String? releasedAt;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.iosStoreUrl,
    this.releasedAt,
  });

  static UpdateInfo? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final version = j['version'] as String?;
    final buildNumber = j['buildNumber'];
    final downloadUrl = j['downloadUrl'] as String?;
    if (version == null || buildNumber == null) return null;
    return UpdateInfo(
      version: version,
      buildNumber: buildNumber is int ? buildNumber : int.tryParse(buildNumber.toString()) ?? 0,
      downloadUrl: downloadUrl ?? '',
      releaseNotes: j['releaseNotes'] as String? ?? '',
      iosStoreUrl: j['iosStoreUrl'] as String? ?? '',
      releasedAt: j['releasedAt'] as String?,
    );
  }
}

/// Whether [remote] is strictly newer than the installed app.
///
/// Primary signal is [UpdateInfo.buildNumber] vs [PackageInfo.buildNumber].
/// If build numbers match, treats as newer only when [UpdateInfo.version] and
/// [PackageInfo.version] differ (unusual edge case).
bool isUpdateNewerThanInstalled(UpdateInfo remote, PackageInfo current) {
  final currentBuild = int.tryParse(current.buildNumber) ?? 0;
  return remote.buildNumber > currentBuild ||
      (remote.buildNumber == currentBuild && remote.version != current.version);
}

/// Update flow state.
enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  downloading,
  downloaded,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final UpdateInfo? info;
  final double progress;
  final String? downloadedPath;
  /// Version label of the APK at [downloadedPath] (matches server [UpdateInfo.version]).
  final String? downloadedVersion;
  final String? errorMessage;

  const UpdateState({
    required this.status,
    this.info,
    this.progress = 0,
    this.downloadedPath,
    this.downloadedVersion,
    this.errorMessage,
  });
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  final ValueNotifier<UpdateState> state = ValueNotifier(const UpdateState(status: UpdateStatus.idle));
  PackageInfo? _packageInfo;
  http.Client? _downloadClient;

  static const _apkUpdatesSubdir = 'apk_updates';
  static const _updatesDirName = 'updates';

  Future<PackageInfo> _getPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  /// App-private directory for OTA APKs only (not the user receive / 待发 folder).
  static Future<String> getAppUpdateDownloadDir() async {
    final support = await getApplicationSupportDirectory();
    return _ensureDir(p.join(support.path, _apkUpdatesSubdir));
  }

  static Future<String> _ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Stable filename for [version] (server string); must match between download and lookup.
  static String apkBasenameForVersion(String version) {
    final safe = version.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return 'app_$safe.apk';
  }

  /// Full path to the cached APK for exactly this server [version] string.
  static Future<String> apkPathForVersion(String version) async {
    final dir = await getAppUpdateDownloadDir();
    return p.join(dir, apkBasenameForVersion(version));
  }

  /// One-time: move APK from legacy receive-dir path into [getAppUpdateDownloadDir].
  Future<void> _migrateLegacyDownloadedPathIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_prefDownloadedPath);
      if (legacy == null || legacy.isEmpty) return;
      final oldFile = File(legacy);
      if (!await oldFile.exists()) {
        await prefs.remove(_prefDownloadedPath);
        return;
      }
      final parsed = _parseApkVersionFromPath(legacy);
      if (parsed == null) {
        await prefs.remove(_prefDownloadedPath);
        return;
      }
      final newPath = await apkPathForVersion(parsed);
      if (p.normalize(legacy) != p.normalize(newPath)) {
        try {
          await File(newPath).parent.create(recursive: true);
          await oldFile.copy(newPath);
          await oldFile.delete();
        } catch (e) {
          logUpdate.warning('migrate legacy apk failed: $e');
        }
      }
      await prefs.setString(_prefDownloadedVersion, parsed);
      await prefs.remove(_prefDownloadedPath);
      logUpdate.info('migrated legacy app update apk to $newPath');
    } catch (e) {
      logUpdate.warning('_migrateLegacyDownloadedPathIfNeeded failed: $e');
    }
  }

  static String? _parseApkVersionFromPath(String filePath) {
    final base = p.basename(filePath);
    if (_isAppUpdateApkBasename(base)) {
      return base.substring(4, base.length - 4);
    }
    return null;
  }

  static bool _isAppUpdateApkBasename(String base) {
    final lower = base.toLowerCase();
    return lower.startsWith('app_') && lower.endsWith('.apk');
  }

  static Future<void> _deleteOtherAppUpdateApksExcept(String dirPath, String keepPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;
    final normalizedKeep = p.normalize(keepPath);
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!_isAppUpdateApkBasename(p.basename(path))) continue;
        if (p.normalize(path) == normalizedKeep) continue;
        try {
          await entity.delete();
          logUpdate.info('removed stale app update apk: $path');
        } catch (e) {
          logUpdate.warning('failed to remove stale apk $path: $e');
        }
      }
    } catch (e) {
      logUpdate.warning('_deleteOtherAppUpdateApksExcept failed: $e');
    }
  }

  Future<void> _clearPendingApkAndPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefDownloadedVersion);
      await prefs.remove(_prefDownloadedPath);
      await _deleteAllAppUpdateApksInDir(await getAppUpdateDownloadDir());
    } catch (e) {
      logUpdate.warning('_clearPendingApkAndPrefs failed: $e');
    }
  }

  static Future<void> _deleteAllAppUpdateApksInDir(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!_isAppUpdateApkBasename(p.basename(entity.path))) continue;
      try {
        await entity.delete();
        logUpdate.info('removed app update apk: ${entity.path}');
      } catch (e) {
        logUpdate.warning('failed to remove ${entity.path}: $e');
      }
    }
  }

  /// If network [checkForUpdate] fails, restore "downloaded" from prefs + on-disk file only.
  Future<void> _tryRestorePendingApkFromLocalOnly() async {
    if (!Platform.isAndroid) return;
    if (Env.androidPlayDistribution) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefDownloadedVersion);
      if (v == null || v.isEmpty) return;
      final path = await apkPathForVersion(v);
      if (!await File(path).exists()) {
        await prefs.remove(_prefDownloadedVersion);
        return;
      }
      state.value = UpdateState(
        status: UpdateStatus.downloaded,
        downloadedPath: path,
        downloadedVersion: v,
      );
      logUpdate.info('_tryRestorePendingApkFromLocalOnly path=$path');
    } catch (e) {
      logUpdate.warning('_tryRestorePendingApkFromLocalOnly failed: $e');
    }
  }

  /// Check for update; returns [UpdateInfo] when a newer version exists **and** no matching APK is cached yet.
  ///
  /// After fetching the server, if the latest [UpdateInfo.version] matches an on-disk APK under
  /// [getAppUpdateDownloadDir], state becomes [UpdateStatus.downloaded] and this returns `null`
  /// (so the "发现新版本" dialog is skipped; install is offered via UI / listener).
  Future<UpdateInfo?> checkForUpdate() async {
    // Play 包不参与应用内 OTA：跳过任何远端检查、缓存恢复以及下载提示。
    if (Platform.isAndroid && Env.androidPlayDistribution) {
      state.value = const UpdateState(status: UpdateStatus.idle);
      return null;
    }
    await _migrateLegacyDownloadedPathIfNeeded();
    state.value = const UpdateState(status: UpdateStatus.checking);
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final uri = Uri.parse('$apiBaseUrl/api/app/version').replace(
        queryParameters: {'platform': platform},
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('检查更新超时'),
      );
      if (response.statusCode == 404) {
        state.value = const UpdateState(status: UpdateStatus.idle);
        return null;
      }
      if (response.statusCode != 200) {
        state.value = UpdateState(status: UpdateStatus.error, errorMessage: '请求失败: ${response.statusCode}');
        return null;
      }
      Map<String, dynamic>? data;
      if (response.body.isNotEmpty && response.body.trim().startsWith('{')) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        } catch (_) {}
      }
      final info = UpdateInfo.fromJson(data);
      if (info == null) {
        state.value = const UpdateState(status: UpdateStatus.idle);
        return null;
      }
      if (Platform.isAndroid && info.downloadUrl.trim().isEmpty) {
        state.value = const UpdateState(status: UpdateStatus.idle);
        return null;
      }
      if (Platform.isIOS &&
          info.iosStoreUrl.trim().isEmpty &&
          info.downloadUrl.trim().isEmpty) {
        state.value = const UpdateState(status: UpdateStatus.idle);
        return null;
      }
      final current = await _getPackageInfo();
      if (!isUpdateNewerThanInstalled(info, current)) {
        await _clearPendingApkAndPrefs();
        state.value = const UpdateState(status: UpdateStatus.idle);
        return null;
      }

      if (Platform.isAndroid && !Env.androidPlayDistribution) {
        final expectedPath = await apkPathForVersion(info.version);
        final cached = File(expectedPath);
        if (await cached.exists()) {
          if (!await shouldShowStartupDialog(info)) {
            state.value = UpdateState(status: UpdateStatus.updateAvailable, info: info);
            logUpdate.info(
              'checkForUpdate cached apk exists but version ${info.version} was dismissed; skip install prompt',
            );
            return null;
          }
          await _deleteOtherAppUpdateApksExcept(await getAppUpdateDownloadDir(), expectedPath);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefDownloadedVersion, info.version);
          state.value = UpdateState(
            status: UpdateStatus.downloaded,
            downloadedPath: expectedPath,
            downloadedVersion: info.version,
            info: info,
          );
          logUpdate.info('checkForUpdate using cached apk for server version=${info.version} path=$expectedPath');
          return null;
        }
      }

      state.value = UpdateState(status: UpdateStatus.updateAvailable, info: info);
      logUpdate.info(
        'checkForUpdate found newer version=${info.version} build=${info.buildNumber} '
        'downloadUrl=${info.downloadUrl}',
      );
      return info;
    } catch (e, st) {
      logUpdate.warning('checkForUpdate failed: $e $st');
      await _tryRestorePendingApkFromLocalOnly();
      if (state.value.status == UpdateStatus.downloaded) {
        return null;
      }
      state.value = UpdateState(status: UpdateStatus.error, errorMessage: e.toString());
      return null;
    }
  }

  /// Save that user dismissed the update prompt for this version (skip startup dialog).
  Future<void> dismissVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDismissedVersion, version);
    } catch (_) {}
  }

  /// Whether to show startup dialog for this [info] (not dismissed for this version).
  Future<bool> shouldShowStartupDialog(UpdateInfo info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_prefDismissedVersion);
      return dismissed != info.version;
    } catch (_) {
      return true;
    }
  }

  /// User chose not to install the downloaded APK: persist [dismissVersion] for [version]
  /// (same key as "发现新版本 / 不再提示") and clear [UpdateStatus.downloaded] so the install
  /// prompt does not show again after restart; [checkForUpdate] will keep [UpdateStatus.updateAvailable] if applicable.
  Future<void> dismissPendingInstallForVersion(String version) async {
    await dismissVersion(version);
    final info = state.value.info;
    if (info != null) {
      state.value = UpdateState(status: UpdateStatus.updateAvailable, info: info);
    } else {
      state.value = const UpdateState(status: UpdateStatus.idle);
    }
  }

  /// Download APK into app-private [getAppUpdateDownloadDir] (not user receive directory).
  Future<void> downloadApk(String url, {required String version}) async {
    if (Env.androidPlayDistribution) {
      state.value = UpdateState(
        status: UpdateStatus.error,
        errorMessage: '当前分发渠道不支持应用内下载安装包',
        info: state.value.info,
      );
      return;
    }
    if (url.isEmpty) {
      state.value = UpdateState(status: UpdateStatus.error, errorMessage: '无下载地址');
      return;
    }
    final keepInfo = state.value.info;
    state.value = UpdateState(status: UpdateStatus.downloading, progress: 0, info: keepInfo);
    _downloadClient?.close();
    _downloadClient = http.Client();
    try {
      final receiveDir = await getAppUpdateDownloadDir();
      final file = File(p.join(receiveDir, apkBasenameForVersion(version)));
      if (await file.exists()) await file.delete();

      logUpdate.info('downloadApk GET version=$version url=$url');
      final request = http.Request('GET', Uri.parse(url));
      final response = await _downloadClient!.send(request);
      if (response.statusCode != 200) {
        var bodySnippet = '';
        try {
          final raw = await response.stream.toBytes();
          bodySnippet = utf8.decode(raw, allowMalformed: true);
          if (bodySnippet.length > 512) {
            bodySnippet = '${bodySnippet.substring(0, 512)}…';
          }
          bodySnippet = bodySnippet.replaceAll(RegExp(r'\s+'), ' ').trim();
        } catch (e) {
          bodySnippet = '(read body failed: $e)';
        }
        logUpdate.warning(
          'downloadApk HTTP ${response.statusCode} version=$version url=$url '
          'reason=${response.reasonPhrase ?? ''} bodySnippet=$bodySnippet',
        );
        state.value = UpdateState(
          status: UpdateStatus.error,
          errorMessage: '下载失败: ${response.statusCode}',
          info: keepInfo,
        );
        return;
      }
      final contentLength = response.contentLength ?? 0;
      final out = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        out.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final progress = (received / contentLength).clamp(0.0, 1.0);
          state.value = UpdateState(status: UpdateStatus.downloading, progress: progress, info: keepInfo);
        }
      }
      await out.close();

      await _deleteOtherAppUpdateApksExcept(receiveDir, file.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDownloadedVersion, version);
      await prefs.remove(_prefDownloadedPath);

      state.value = UpdateState(
        status: UpdateStatus.downloaded,
        downloadedPath: file.path,
        downloadedVersion: version,
        info: keepInfo,
      );
      logUpdate.info('downloadApk done path=${file.path}');
    } catch (e, st) {
      logUpdate.warning('downloadApk failed: $e $st');
      state.value = UpdateState(status: UpdateStatus.error, errorMessage: e.toString(), info: keepInfo);
    } finally {
      _downloadClient?.close();
      _downloadClient = null;
    }
  }

  /// Returns a path under app cache suitable for FileProvider install (Android).
  /// If [filePath] is already under cache, returns it; otherwise copies to cache and returns the copy path.
  static Future<String> pathForInstall(String filePath) async {
    final cache = await getTemporaryDirectory();
    final normalized = filePath.replaceAll('\\', '/');
    final cachePrefix = cache.path.replaceAll('\\', '/');
    if (normalized.startsWith(cachePrefix)) return filePath;
    final destDir = Directory('${cache.path}/$_updatesDirName');
    if (!await destDir.exists()) await destDir.create(recursive: true);
    final dest = File('${destDir.path}/install.apk');
    await File(filePath).copy(dest.path);
    return dest.path;
  }

  /// Remove downloaded APK and clear persisted version.
  Future<void> clearDownloaded() async {
    final path = state.value.downloadedPath;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      try {
        await _deleteAllAppUpdateApksInDir(await getAppUpdateDownloadDir());
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefDownloadedVersion);
      await prefs.remove(_prefDownloadedPath);
    }
    state.value = const UpdateState(status: UpdateStatus.idle);
  }
}
