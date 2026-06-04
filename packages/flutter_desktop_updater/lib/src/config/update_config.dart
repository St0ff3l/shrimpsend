import 'package:flutter/foundation.dart';

class UpdateConfig {
  static UpdateConfig? _instance;

  factory UpdateConfig() {
    _instance ??= UpdateConfig._internal();
    return _instance!;
  }

  UpdateConfig._internal();

  String? _updateJsonUrl;
  String? _appExecutableBaseName;
  void Function(String message)? _onLog;
  void Function(String message)? _onError;

  /// [appExecutableBaseName] — basename without extension of the main executable
  /// (e.g. `xiachuan` for `xiachuan.exe` / Linux binary). Required for reliable
  /// Windows/Linux discovery when the upstream template name (`staffco`) does not apply.
  ///
  /// [onLog] — optional pipeline messages (check, download, install steps).
  /// [onError] — user-visible / failure messages (check errors, install failures).
  void configure({
    required String updateJsonUrl,
    String? appExecutableBaseName,
    void Function(String message)? onLog,
    void Function(String message)? onError,
  }) {
    _updateJsonUrl = updateJsonUrl;
    _appExecutableBaseName = appExecutableBaseName;
    _onLog = onLog;
    _onError = onError;
  }

  String get updateJsonUrl {
    if (_updateJsonUrl == null) {
      throw Exception(
        'UpdateConfig not initialized!\n'
        'Please call UpdateConfig().configure(updateJsonUrl: "...") '
        'in your main() function before using the update system.',
      );
    }
    return _updateJsonUrl!;
  }

  bool get isConfigured => _updateJsonUrl != null;

  /// Basename (no extension) of the packaged app executable, e.g. `xiachuan`.
  String? get appExecutableBaseName => _appExecutableBaseName;

  void logLine(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
    _onLog?.call(message);
  }

  void reportError(String message) {
    _onError?.call(message);
  }
}
