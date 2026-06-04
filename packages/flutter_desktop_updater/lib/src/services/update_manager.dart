import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/update_config.dart';
import '../models/update_info.dart';
import 'platform_updater.dart';

enum UpdateStatus {
  initial,
  checking,
  updateAvailable,
  updating,
  readyToRestart,
  restarting,
  error,
}

class UpdateManager extends ChangeNotifier {
  static final UpdateManager _instance = UpdateManager._internal();
  factory UpdateManager() => _instance;
  UpdateManager._internal();

  UpdateStatus _status = UpdateStatus.initial;
  UpdateInfo? _updateInfo;
  double _progress = 0.0;
  String? _error;

  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  double get progress => _progress;
  String? get error => _error;

  final _updater = PlatformUpdater();

  Future<void> checkForUpdate() async {
    _log('Checking for updates...');
    _setStatus(UpdateStatus.checking);

    try {
      final updateJsonUrl = UpdateConfig().updateJsonUrl;

      final response = await http.get(Uri.parse(updateJsonUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final platform = _getPlatform();

      if (!json.containsKey(platform)) {
        throw Exception('No updates for $platform');
      }

      final info = UpdateInfo.fromJson(json[platform]);
      final packageInfo = await PackageInfo.fromPlatform();

      _log('Current: ${packageInfo.version}+${packageInfo.buildNumber}');
      _log('Available: ${info.version}+${info.buildNumber}');

      if (info.isNewerThan(packageInfo.version, packageInfo.buildNumber)) {
        _updateInfo = info;
        _setStatus(UpdateStatus.updateAvailable);
        _log('Update available');
      } else {
        _setStatus(UpdateStatus.initial);
        _log('Up to date');
      }
    } catch (e, st) {
      _log('Check failed: $e');
      UpdateConfig().logLine('[UpdateManager] stack: $st');
      if (kDebugMode) {
        // ignore: avoid_print
        print(st);
      }
      _setError('Failed to check for updates: $e');
    }
  }

  Future<void> startUpdate() async {
    if (_updateInfo == null) return;

    _log('Starting update...');
    _setStatus(UpdateStatus.updating);
    _progress = 0.0;

    try {
      final zipPath = await _download();
      if (zipPath == null) throw Exception('Download failed');

      _log('Installing...');
      final success = await _updater.installUpdate(zipPath);
      if (!success) {
        final detail = _updater.lastError;
        throw Exception(
          detail != null ? 'Installation failed: $detail' : 'Installation failed',
        );
      }

      _log('Update installed, ready to restart');
      _setStatus(UpdateStatus.readyToRestart);
    } catch (e, st) {
      _log('Update failed: $e');
      UpdateConfig().logLine('[UpdateManager] stack: $st');
      if (kDebugMode) {
        // ignore: avoid_print
        print(st);
      }
      _setError('Update failed: $e');
    }
  }

  Future<String?> _download() async {
    try {
      final tempDir = Directory.systemTemp;
      final savePath = '${tempDir.path}/app-update.zip';

      final request = http.Request('GET', Uri.parse(_updateInfo!.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) return null;

      final contentLength = response.contentLength ?? 0;
      final file = File(savePath);
      final sink = file.openWrite();
      int downloaded = 0;

      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;

        if (contentLength > 0) {
          _progress = downloaded / contentLength;
          notifyListeners();
        }
      }

      await sink.close();
      _log('Downloaded: ${(await file.length() / 1024 / 1024).toStringAsFixed(2)} MB');
      return savePath;
    } catch (e) {
      _log('Download error: $e');
      return null;
    }
  }

  Future<void> restartApp() async {
    _log('Restarting app...');
    _setStatus(UpdateStatus.restarting);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _updater.restartApp();
  }

  void dismiss() {
    _updateInfo = null;
    _setStatus(UpdateStatus.initial);
  }

  void _setStatus(UpdateStatus status) {
    _status = status;
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _status = UpdateStatus.error;
    UpdateConfig().reportError(message);
    notifyListeners();
  }

  String _getPlatform() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return '';
  }

  void _log(String msg) {
    UpdateConfig().logLine('[UpdateManager] $msg');
  }
}
