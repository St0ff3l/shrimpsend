import 'package:openpanel_flutter/openpanel_flutter.dart';

import '../openpanel_bootstrap.dart';

/// 轻量封装：守卫初始化、清洗属性、吞掉异常，不阻塞 UI。
class Analytics {
  Analytics._();

  static Map<String, dynamic> _cleanProps(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return {};
    final out = <String, dynamic>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is String && v.isEmpty) continue;
      out[e.key] = v;
    }
    return out;
  }

  static void track(String name, [Map<String, dynamic>? properties]) {
    if (!OpenpanelBootstrap.isInitialized) return;
    try {
      Openpanel.instance.event(
        name: name,
        properties: _cleanProps(properties),
      );
    } catch (_) {}
  }

  /// 文件总字节数分桶（不上报精确值）。
  static String sizeBucket(int bytes) {
    if (bytes < 0) return 'unknown';
    if (bytes < 1024 * 1024) return 'lt_1mb';
    if (bytes < 10 * 1024 * 1024) return '1mb_10mb';
    if (bytes < 100 * 1024 * 1024) return '10mb_100mb';
    if (bytes < 1024 * 1024 * 1024) return '100mb_1gb';
    return 'gt_1gb';
  }

  /// 文本长度分桶。
  static String lengthBucket(int len) {
    if (len < 10) return 'lt_10';
    if (len < 50) return '10_50';
    if (len < 200) return '50_200';
    return 'gt_200';
  }
}
