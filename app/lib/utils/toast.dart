import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';

/// 统一 Toast：基于 OKToast，悬浮在页面上侧约 30% 位置，所有提示均通过此处调用。
class AppToast {
  AppToast._();

  /// 默认显示时长
  static const Duration defaultDuration = Duration(seconds: 2);

  /// 页面上侧约 30% 位置（与 main 中 OKToast 的 ToastPosition 一致）
  static ToastPosition get _position => ToastPosition(
        align: const Alignment(0, -0.4),
        offset: 0,
      );

  /// 显示一条 Toast。
  /// [context] 用于 OKToast 查找 overlay；[message] 文案；[duration] 可选。
  static void show(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    showToast(
      message,
      context: context,
      duration: duration ?? defaultDuration,
      position: _position,
    );
  }
}
