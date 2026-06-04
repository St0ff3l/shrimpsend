import '../utils/runtime_platform.dart';

/// UI-only performance switches for platform-specific rendering fallbacks.
///
/// Windows desktop is more sensitive to tiny continuous animations, clipped
/// ink ripples, and shader-heavy glass effects in this app.
class AppPlatformPerformance {
  AppPlatformPerformance._();

  static bool get preferStaticBusyIndicators => RuntimePlatform.isWindows;
  static bool get preferLightweightTapFeedback => RuntimePlatform.isWindows;
  static bool get preferPlainNarrowNavigation => RuntimePlatform.isWindows;
}
