import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsFlutterBinding;
import 'package:package_info_plus/package_info_plus.dart';

/// Dart `HttpClient` / Dio reject header values outside observable ASCII (e.g. CJK app names).
String _headerSafeAscii(String raw, {String fallback = 'App'}) {
  final buf = StringBuffer();
  for (final unit in raw.codeUnits) {
    if (unit >= 0x20 && unit < 0x7f) {
      buf.writeCharCode(unit);
    } else {
      buf.write('_');
    }
  }
  final out = buf.toString().trim();
  return out.isEmpty ? fallback : out;
}

class DeviceUserAgent {
  final DeviceInfoPlugin _deviceInfo;

  DeviceUserAgent({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  Future<String> getUserAgent() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      var appName = _headerSafeAscii(packageInfo.appName, fallback: '');
      if (appName.isEmpty || RegExp(r'^_+$').hasMatch(appName)) {
        appName = _headerSafeAscii(packageInfo.packageName, fallback: 'App');
      }
      final appVersion = packageInfo.version;
      final appBuild = packageInfo.buildNumber;

      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return _buildWebUserAgent(webInfo, appName, appVersion, appBuild);
      }

      final raw = switch (defaultTargetPlatform) {
        TargetPlatform.android => _buildAndroidUserAgent(
            await _deviceInfo.androidInfo, appName, appVersion, appBuild),
        TargetPlatform.iOS => _buildIosUserAgent(
            await _deviceInfo.iosInfo, appName, appVersion, appBuild),
        TargetPlatform.macOS => _buildMacOsUserAgent(
            await _deviceInfo.macOsInfo, appName, appVersion, appBuild),
        TargetPlatform.windows => _buildWindowsUserAgent(
            await _deviceInfo.windowsInfo, appName, appVersion, appBuild),
        TargetPlatform.linux => _buildLinuxUserAgent(
            await _deviceInfo.linuxInfo, appName, appVersion, appBuild),
        _ => _defaultUserAgent(appName, appVersion, appBuild),
      };
      return _headerSafeAscii(raw, fallback: _defaultUserAgent(appName, appVersion, appBuild));
    } catch (e) {
      return _defaultUserAgent("UnknownApp", "1.0", "0", error: e.toString());
    }
  }

  String _defaultUserAgent(String appName, String appVersion, String appBuild,
      {String? error}) {
    final err = error != null
        ? '; Error: ${_headerSafeAscii(error, fallback: 'error')}'
        : '';
    return '$appName/$appVersion (Unknown Device; build:$appBuild$err)';
  }

  String _buildWebUserAgent(
      WebBrowserInfo info, String appName, String appVersion, String appBuild) {
    final browser = _headerSafeAscii(
      '${info.browserName.name}/${info.appVersion ?? "Unknown"}',
      fallback: 'browser/0',
    );
    final plat = _headerSafeAscii(info.platform ?? 'Web', fallback: 'Web');
    return '$appName/$appVersion ($browser; $plat; build:$appBuild)';
  }

  String _buildAndroidUserAgent(AndroidDeviceInfo info, String appName,
      String appVersion, String appBuild) {
    final osVersion =
        _headerSafeAscii(info.version.release, fallback: 'Unknown');
    final manufacturer = _headerSafeAscii(info.manufacturer, fallback: 'OEM');
    final model = _headerSafeAscii(info.model, fallback: 'device');

    final resolution = _getScreenResolution();
    final pixelRatio = _getDevicePixelRatio();

    return '$appName/$appVersion '
        '(Android $osVersion; $model; build:$appBuild) '
        'oem/$manufacturer '
        'model/$model '
        'screen/$resolution/$pixelRatio';
  }

  String _buildIosUserAgent(
      IosDeviceInfo info, String appName, String appVersion, String appBuild) {
    final resolution = _getScreenResolution();
    final pixelRatio = _getDevicePixelRatio();
    final model = _headerSafeAscii(info.model, fallback: 'iPhone');

    return '$appName/$appVersion '
        '(iOS ${info.systemVersion}; ${_headerSafeAscii(info.utsname.machine, fallback: 'arm64')}; build:$appBuild) '
        'oem/Apple '
        'model/$model '
        'screen/$resolution/$pixelRatio';
  }

  String _buildMacOsUserAgent(MacOsDeviceInfo info, String appName,
      String appVersion, String appBuild) {
    final model = _headerSafeAscii(info.model, fallback: 'Mac');
    final osRelease =
        _headerSafeAscii(info.osRelease, fallback: 'Unknown');
    return '$appName/$appVersion (macOS $osRelease; $model; build:$appBuild)';
  }

  String _buildWindowsUserAgent(WindowsDeviceInfo info, String appName,
      String appVersion, String appBuild) {
    final host = _headerSafeAscii(info.computerName, fallback: 'PC');
    final displayVersion =
        _headerSafeAscii(info.displayVersion, fallback: 'Unknown');
    return '$appName/$appVersion (Windows $displayVersion; $host; build:$appBuild)';
  }

  String _buildLinuxUserAgent(LinuxDeviceInfo info, String appName,
      String appVersion, String appBuild) {
    final name = _headerSafeAscii(info.name, fallback: 'Linux');
    final version =
        _headerSafeAscii(info.version ?? 'Unknown', fallback: 'Unknown');
    return '$appName/$appVersion (Linux $version; $name; build:$appBuild)';
  }

  /// Gets the screen resolution
  String _getScreenResolution() {
    WidgetsFlutterBinding.ensureInitialized();
    final size =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    return '${size.width.toInt()}x${size.height.toInt()}';
  }

  /// Gets the screen pixel ratio
  double _getDevicePixelRatio() {
    WidgetsFlutterBinding.ensureInitialized();
    return WidgetsBinding
        .instance.platformDispatcher.views.first.devicePixelRatio;
  }
}
