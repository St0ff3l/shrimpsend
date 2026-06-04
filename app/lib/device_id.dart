import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mobile_device_identifier/mobile_device_identifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _keyDeviceId = 'ultrasend_device_id';
const _keyDeviceName = 'ultrasend_device_name';

String get _platformPrefix {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  if (Platform.isMacOS) return 'macos';
  return 'unknown';
}

Future<String?> _getPcDeviceId(DeviceInfoPlugin info) async {
  if (Platform.isMacOS) {
    final mac = await info.macOsInfo;
    return mac.systemGUID;
  } else if (Platform.isWindows) {
    final win = await info.windowsInfo;
    return win.deviceId;
  } else if (Platform.isLinux) {
    final linux = await info.linuxInfo;
    return linux.machineId;
  }
  return null;
}

Future<String> _generateDeviceId() async {
  final prefix = _platformPrefix;
  try {
    String? nativeId;
    if (Platform.isAndroid || Platform.isIOS) {
      nativeId = await MobileDeviceIdentifier().getDeviceId();
    } else {
      nativeId = await _getPcDeviceId(DeviceInfoPlugin());
    }
    if (nativeId != null && nativeId.isNotEmpty) {
      final hash = md5.convert(utf8.encode(nativeId)).toString();
      return '${prefix}_$hash';
    }
  } catch (_) {
    // fall through to UUID fallback
  }
  return '${prefix}_uuid_${const Uuid().v4()}';
}

Future<String> _generateDeviceName() async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final brand = android.brand;
      final model = android.model;
      final capitalizedBrand = brand.isEmpty
          ? ''
          : brand[0].toUpperCase() + brand.substring(1);
      return '$capitalizedBrand $model'.trim();
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return ios.name;
    } else if (Platform.isMacOS) {
      final mac = await info.macOsInfo;
      return mac.computerName;
    } else if (Platform.isWindows) {
      final win = await info.windowsInfo;
      return win.computerName;
    } else if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      return linux.prettyName;
    }
  } catch (_) {
    // fall through to default
  }
  return _platformPrefix;
}

bool _isLegacyDeviceId(String id) {
  return id.startsWith('flutter_');
}

bool _isLegacyDeviceName(String name) {
  return name == 'Flutter';
}

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_keyDeviceId);
  if (id == null || id.isEmpty || _isLegacyDeviceId(id)) {
    id = await _generateDeviceId();
    await prefs.setString(_keyDeviceId, id);
  }
  return id;
}

Future<String> getDeviceName() async {
  final prefs = await SharedPreferences.getInstance();
  var name = prefs.getString(_keyDeviceName);
  if (name == null || name.isEmpty || _isLegacyDeviceName(name)) {
    name = await _generateDeviceName();
    await prefs.setString(_keyDeviceName, name);
  }
  return name;
}

Future<void> setDeviceName(String name) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyDeviceName, name);
}

/// 登录/注册 API 的 `platform` 字段；Web 多台浏览器在后端计 1 台设备。
Future<String> getAuthPlatformLabel() async {
  if (kIsWeb) return 'web';
  return _platformPrefix;
}
