import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// 持久化桌面窗口的位置与大小，下次启动时直接恢复。
final class WindowStateStore {
  WindowStateStore._();

  static const _keyX = 'window_state_x';
  static const _keyY = 'window_state_y';
  static const _keyW = 'window_state_w';
  static const _keyH = 'window_state_h';

  static const _minWidth = 400.0;
  static const _minHeight = 300.0;

  /// 读取上次保存的窗口矩形；首次启动或数据不完整时返回 null。
  static Future<Rect?> load() async {
    final p = await SharedPreferences.getInstance();
    final x = p.getDouble(_keyX);
    final y = p.getDouble(_keyY);
    final w = p.getDouble(_keyW);
    final h = p.getDouble(_keyH);
    if (x == null || y == null || w == null || h == null) return null;

    final width = w.clamp(_minWidth, double.infinity);
    final height = h.clamp(_minHeight, double.infinity);

    return Rect.fromLTWH(x, y, width, height);
  }

  /// 保存窗口矩形。
  static Future<void> save(Rect bounds) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setDouble(_keyX, bounds.left),
      p.setDouble(_keyY, bounds.top),
      p.setDouble(_keyW, bounds.width),
      p.setDouble(_keyH, bounds.height),
    ]);
  }
}
