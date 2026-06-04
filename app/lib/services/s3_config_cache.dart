import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logger.dart';

const _storageKey = 's3_config_local';

/// Locally-cached S3 configuration so that file transfers can call S3 directly
/// without routing through the backend.
class S3LocalConfig {
  final String endpoint;
  final String region;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final bool pathStyleAccessEnabled;

  S3LocalConfig({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.pathStyleAccessEnabled = true,
  });

  /// Normalised endpoint without trailing slash.
  String get normalizedEndpoint => endpoint.replaceFirst(RegExp(r'/$'), '');

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'region': region,
    'bucket': bucket,
    'accessKeyId': accessKeyId,
    'secretAccessKey': secretAccessKey,
    'pathStyleAccessEnabled': pathStyleAccessEnabled,
  };

  factory S3LocalConfig.fromJson(Map<String, dynamic> j) => S3LocalConfig(
    endpoint: j['endpoint'] as String,
    region: j['region'] as String? ?? 'cn-east-1',
    bucket: j['bucket'] as String,
    accessKeyId: j['accessKeyId'] as String,
    secretAccessKey: j['secretAccessKey'] as String,
    pathStyleAccessEnabled: j['pathStyleAccessEnabled'] as bool? ?? true,
  );
}

class S3ConfigCache {
  S3ConfigCache._();
  static final instance = S3ConfigCache._();

  S3LocalConfig? _cache;

  Future<void> save(S3LocalConfig config) async {
    _cache = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(config.toJson()));
    logChat.info('S3ConfigCache saved endpoint=${config.endpoint}');
  }

  Future<S3LocalConfig?> load() async {
    if (_cache != null) return _cache;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return null;
    try {
      _cache = S3LocalConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cache;
    } catch (e) {
      logChat.warning('S3ConfigCache load failed: $e');
      return null;
    }
  }

  Future<void> clear() async {
    _cache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  bool get hasCached => _cache != null;
}
