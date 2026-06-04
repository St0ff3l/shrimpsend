import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralizes platform classification used by membership / payment flows.
///
/// Keep this module free of Flutter widget imports so it can be referenced from
/// pure-Dart logic (e.g. `membership_channel_guard.dart`) and easily faked in tests.
class RuntimePlatform {
  RuntimePlatform._();

  /// macOS / Windows / Linux desktop (Flutter desktop embedding).
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  static bool get isIos => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Tag passed to backend `success_url` / order creation so the post-payment page
  /// can hint "return to your app" when paid from desktop.
  static String get platformTag {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'desktop-macos';
    if (Platform.isWindows) return 'desktop-windows';
    if (Platform.isLinux) return 'desktop-linux';
    return 'unknown';
  }
}
