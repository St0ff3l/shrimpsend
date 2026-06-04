import 'package:flutter/material.dart';

class AppColorTheme {
  final String id;
  final Color accent;

  final Color bubbleSentLight;
  final Color bubbleSentDark;
  final Color bubbleReceivedLight;
  final Color bubbleReceivedDark;
  final Color onBubbleSentLight;
  final Color onBubbleSentDark;
  final Color onBubbleReceivedLight;
  final Color onBubbleReceivedDark;

  const AppColorTheme({
    required this.id,
    required this.accent,
    required this.bubbleSentLight,
    required this.bubbleSentDark,
    required this.bubbleReceivedLight,
    required this.bubbleReceivedDark,
    required this.onBubbleSentLight,
    required this.onBubbleSentDark,
    required this.onBubbleReceivedLight,
    required this.onBubbleReceivedDark,
  });

  Color bubbleSent(Brightness brightness) =>
      brightness == Brightness.dark ? bubbleSentDark : bubbleSentLight;

  Color bubbleReceived(Brightness brightness) =>
      brightness == Brightness.dark ? bubbleReceivedDark : bubbleReceivedLight;

  Color onBubbleSent(Brightness brightness) =>
      brightness == Brightness.dark ? onBubbleSentDark : onBubbleSentLight;

  Color onBubbleReceived(Brightness brightness) => brightness == Brightness.dark
      ? onBubbleReceivedDark
      : onBubbleReceivedLight;

  Color bubbleBackground(Brightness brightness, {required bool isSentByMe}) =>
      isSentByMe ? bubbleSent(brightness) : bubbleReceived(brightness);

  Color onBubble(Brightness brightness, {required bool isSentByMe}) =>
      isSentByMe ? onBubbleSent(brightness) : onBubbleReceived(brightness);

  Color onBubbleMuted(Brightness brightness, {required bool isSentByMe}) {
    final base = onBubble(brightness, isSentByMe: isSentByMe);
    final background = bubbleBackground(brightness, isSentByMe: isSentByMe);
    final backgroundIsDark = background.computeLuminance() < 0.22;
    return base.withValues(alpha: backgroundIsDark ? 0.82 : 0.68);
  }

  Color onBubbleSubtle(Brightness brightness, {required bool isSentByMe}) {
    final base = onBubble(brightness, isSentByMe: isSentByMe);
    final background = bubbleBackground(brightness, isSentByMe: isSentByMe);
    final backgroundIsDark = background.computeLuminance() < 0.22;
    return base.withValues(alpha: backgroundIsDark ? 0.62 : 0.5);
  }

  Color bubbleTrack(Brightness brightness, {required bool isSentByMe}) {
    final base = onBubble(brightness, isSentByMe: isSentByMe);
    final background = bubbleBackground(brightness, isSentByMe: isSentByMe);
    final backgroundIsDark = background.computeLuminance() < 0.22;
    return base.withValues(alpha: backgroundIsDark ? 0.22 : 0.1);
  }

  Color bubbleAccent(
    Brightness brightness, {
    required bool isSentByMe,
    required Color accent,
  }) {
    final background = bubbleBackground(brightness, isSentByMe: isSentByMe);
    final foreground = onBubble(brightness, isSentByMe: isSentByMe);
    final backgroundIsDark = background.computeLuminance() < 0.22;
    if (!backgroundIsDark) {
      return accent;
    }
    return Color.alphaBlend(foreground.withValues(alpha: 0.22), accent);
  }

  /// Link color tuned for bubble contrast: light foreground on dark bubbles,
  /// theme accent on light received bubbles.
  Color bubbleLink(Brightness brightness, {required bool isSentByMe}) {
    final background = bubbleBackground(brightness, isSentByMe: isSentByMe);
    final foreground = onBubble(brightness, isSentByMe: isSentByMe);
    if (background.computeLuminance() < 0.45) {
      return foreground;
    }
    return accent;
  }

  static const lanColor = Color(0xFF3D9B7E);
  static const s3Color = Color(0xFF4A72C4);
  static const webrtcColor = Color(0xFF7B65B0);

  static Color protocolColor(String? protocol) {
    return switch (protocol) {
      'lan' => lanColor,
      's3' => s3Color,
      'webrtc' => webrtcColor,
      _ => const Color(0xFFa1a1aa),
    };
  }

  static const List<AppColorTheme> presets = [
    emerald,
    ocean,
    sunset,
    lavender,
    rose,
    graphite,
  ];

  static const emerald = AppColorTheme(
    id: 'emerald',
    accent: Color(0xFF3D9B7E),
    bubbleSentLight: Color(0xFF3D9B7E),
    bubbleSentDark: Color(0xFF2D6B57),
    bubbleReceivedLight: Color(0xFFE4E4E7),
    bubbleReceivedDark: Color(0xFF27272A),
    onBubbleSentLight: Colors.white,
    onBubbleSentDark: Colors.white,
    onBubbleReceivedLight: Color(0xFF18181b),
    onBubbleReceivedDark: Colors.white,
  );

  static const ocean = AppColorTheme(
    id: 'ocean',
    accent: Color(0xFF4A72C4),
    bubbleSentLight: Color(0xFF4A72C4),
    bubbleSentDark: Color(0xFF2E4B73),
    bubbleReceivedLight: Color(0xFFE4E4E7),
    bubbleReceivedDark: Color(0xFF27272A),
    onBubbleSentLight: Colors.white,
    onBubbleSentDark: Colors.white,
    onBubbleReceivedLight: Color(0xFF18181b),
    onBubbleReceivedDark: Colors.white,
  );

  static const sunset = AppColorTheme(
    id: 'sunset',
    accent: Color(0xFFD07840),
    bubbleSentLight: Color(0xFFD07840),
    bubbleSentDark: Color(0xFF8B5530),
    bubbleReceivedLight: Color(0xFFE4E4E7),
    bubbleReceivedDark: Color(0xFF27272A),
    onBubbleSentLight: Colors.white,
    onBubbleSentDark: Colors.white,
    onBubbleReceivedLight: Color(0xFF18181b),
    onBubbleReceivedDark: Colors.white,
  );

  static const lavender = AppColorTheme(
    id: 'lavender',
    accent: Color(0xFF7B65B0),
    bubbleSentLight: Color(0xFF7B65B0),
    bubbleSentDark: Color(0xFF504080),
    bubbleReceivedLight: Color(0xFFE4E4E7),
    bubbleReceivedDark: Color(0xFF27272A),
    onBubbleSentLight: Colors.white,
    onBubbleSentDark: Colors.white,
    onBubbleReceivedLight: Color(0xFF18181b),
    onBubbleReceivedDark: Colors.white,
  );

  static const rose = AppColorTheme(
    id: 'rose',
    accent: Color(0xFFC4506A),
    bubbleSentLight: Color(0xFFC4506A),
    bubbleSentDark: Color(0xFF8B3A50),
    bubbleReceivedLight: Color(0xFFE4E4E7),
    bubbleReceivedDark: Color(0xFF27272A),
    onBubbleSentLight: Colors.white,
    onBubbleSentDark: Colors.white,
    onBubbleReceivedLight: Color(0xFF18181b),
    onBubbleReceivedDark: Colors.white,
  );

  static const graphite = AppColorTheme(
    id: 'graphite',
    accent: Color(0xFF475569),
    bubbleSentLight: Color(0xFF475569),
    bubbleSentDark: Color(0xFF334155),
    bubbleReceivedLight: Color(0xFFE4E4E7),
    bubbleReceivedDark: Color(0xFF27272A),
    onBubbleSentLight: Colors.white,
    onBubbleSentDark: Colors.white,
    onBubbleReceivedLight: Color(0xFF18181b),
    onBubbleReceivedDark: Colors.white,
  );

  static AppColorTheme fromId(String id) {
    return presets.firstWhere((t) => t.id == id, orElse: () => emerald);
  }
}
