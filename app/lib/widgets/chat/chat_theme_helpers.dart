import 'package:flutter/material.dart';

import '../../color_theme.dart';
import '../../color_theme_store.dart';
import '../../ui/app_ui.dart';

class ChatColors {
  final Color background;
  final Color surface;
  final Color bubbleSent;
  final Color bubbleReceived;
  final Color upload;
  final Color download;
  final Color muted;
  final Color onBubbleSent;
  final Color onBubbleReceived;
  final Color onSurface;
  final Color progressBarBg;
  final Color appBarForeground;
  final Color inputHint;
  final Color success;
  final Color warning;
  final Color danger;
  final AppColorTheme colorTheme;
  final Brightness brightness;

  const ChatColors({
    required this.background,
    required this.surface,
    required this.bubbleSent,
    required this.bubbleReceived,
    required this.upload,
    required this.download,
    required this.muted,
    required this.onBubbleSent,
    required this.onBubbleReceived,
    required this.onSurface,
    required this.progressBarBg,
    required this.appBarForeground,
    required this.inputHint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.colorTheme,
    required this.brightness,
  });

  Color onBubble(bool isSentByMe) =>
      isSentByMe ? onBubbleSent : onBubbleReceived;

  Color bubbleMuted(bool isSentByMe) =>
      colorTheme.onBubbleMuted(brightness, isSentByMe: isSentByMe);

  Color bubbleSubtle(bool isSentByMe) =>
      colorTheme.onBubbleSubtle(brightness, isSentByMe: isSentByMe);

  Color bubbleTrack(bool isSentByMe) =>
      colorTheme.bubbleTrack(brightness, isSentByMe: isSentByMe);

  Color bubbleAccent(bool isSentByMe, Color accent) => colorTheme.bubbleAccent(
    brightness,
    isSentByMe: isSentByMe,
    accent: accent,
  );

  Color bubbleLink(bool isSentByMe) =>
      colorTheme.bubbleLink(brightness, isSentByMe: isSentByMe);

  static ChatColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final appColors = context.appColors;
    final colorTheme = ColorThemeStoreScope.of(context).notifier.value;
    return ChatColors(
      background: appColors.background,
      surface: appColors.surface,
      bubbleSent: colorTheme.bubbleSent(brightness),
      bubbleReceived: colorTheme.bubbleReceived(brightness),
      upload: appColors.success,
      download: AppColorTheme.s3Color,
      muted: appColors.textSecondary,
      onBubbleSent: colorTheme.onBubbleSent(brightness),
      onBubbleReceived: colorTheme.onBubbleReceived(brightness),
      onSurface: appColors.textPrimary,
      progressBarBg: appColors.border,
      appBarForeground: appColors.textPrimary,
      inputHint: appColors.textTertiary,
      success: appColors.success,
      warning: appColors.warning,
      danger: appColors.danger,
      colorTheme: colorTheme,
      brightness: brightness,
    );
  }
}

String transferTypeLabel(String? type) {
  return switch (type) {
    'lan' => 'HTTP',
    'webrtc' => 'WebRTC',
    's3' => 'S3',
    _ => '',
  };
}

/// API/DB may store flags as string `"true"`; [targetDeviceIds] implies LAN when `lan` is absent.
bool chatPayloadBoolTrue(dynamic value) {
  if (value == true) return true;
  if (value == false || value == null) return false;
  if (value == 1 || value == 1.0) return true;
  if (value is String) {
    final s = value.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

/// Derives `lan` | `webrtc` | `s3` from persisted/synced file payloads.
String? transferTypeFromFilePayload(Map payload) {
  if (chatPayloadBoolTrue(payload['lan'])) return 'lan';
  if (chatPayloadBoolTrue(payload['webrtc'])) return 'webrtc';
  final key = payload['key']?.toString();
  if (key != null && key.isNotEmpty) return 's3';
  final tIds = payload['targetDeviceIds'];
  if (tIds is List && tIds.isNotEmpty) return 'lan';
  return null;
}

final _httpLanBubbleTextRe = RegExp(
  r'HTTP\s*(发送|接收|Sending|Receiving)',
  caseSensitive: false,
);

/// Fallback when [transferType] was not stored on [_FileMeta] (legacy rows / stripped flags).
String? inferTransferTypeFromFileBubbleText(String text) {
  if (_httpLanBubbleTextRe.hasMatch(text)) return 'lan';
  if (text.contains('已通过 HTTP') ||
      text.contains('反向拉取') ||
      text.contains('received via HTTP') ||
      text.contains('reverse pull')) {
    return 'lan';
  }
  if (text.contains('WebRTC')) return 'webrtc';
  return null;
}
