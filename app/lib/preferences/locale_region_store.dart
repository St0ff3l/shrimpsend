import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import 'country_cluster.dart';
import 'service_region.dart';

const _keyLocaleTag = 'ultrasend_locale_tag';
const _keyServiceRegion = 'ultrasend_service_region';
const _keyCountryCode = 'ultrasend_country_code';
const _keyGateCompleted = 'ultrasend_locale_gate_completed';

/// Supported UI locales (BCP 47 tags stored in prefs).
const List<Locale> kSupportedAppLocales = [
  Locale('zh', 'CN'),
  Locale('en'),
];

class LocaleRegionState {
  final Locale locale;
  /// ISO 3166-1 alpha-2 (e.g. CN, US).
  final String countryCode;
  final bool localeGateCompleted;

  const LocaleRegionState({
    required this.locale,
    required this.countryCode,
    required this.localeGateCompleted,
  });

  ServiceRegion get serviceRegion => serviceRegionForCountryCode(countryCode);

  LocaleRegionState copyWith({
    Locale? locale,
    String? countryCode,
    bool? localeGateCompleted,
  }) =>
      LocaleRegionState(
        locale: locale ?? this.locale,
        countryCode: countryCode ?? this.countryCode,
        localeGateCompleted: localeGateCompleted ?? this.localeGateCompleted,
      );
}

/// Persists language, country (prod cluster), and first-launch gate state.
class LocaleRegionStore {
  LocaleRegionStore();

  /// Release 构建下国家/地区由 [Env.overseasBuild] 锁定，不可在应用内切换。
  static bool get countryLocked => kReleaseMode;

  final ValueNotifier<LocaleRegionState> notifier =
      ValueNotifier<LocaleRegionState>(
    LocaleRegionState(
      locale: Env.overseasBuild ? const Locale('en') : const Locale('zh', 'CN'),
      countryCode: Env.overseasBuild ? 'US' : 'CN',
      localeGateCompleted: false,
    ),
  );

  static String _normalizeCountryCode(String? raw) {
    final u = (raw ?? '').trim().toUpperCase();
    if (u.length == 2 && RegExp(r'^[A-Z]{2}$').hasMatch(u)) return u;
    return Env.overseasBuild ? 'US' : 'CN';
  }

  /// Call from [main] after construction, before [runApp].
  Future<void> loadSync() async {
    final prefs = await SharedPreferences.getInstance();
    final tag = prefs.getString(_keyLocaleTag);
    final gate = prefs.getBool(_keyGateCompleted);

    late String cc;
    if (countryLocked) {
      cc = Env.overseasBuild ? 'US' : 'CN';
      await prefs.setString(_keyCountryCode, cc);
      await prefs.setString(
        _keyServiceRegion,
        serviceRegionForCountryCode(cc).storageValue,
      );
    } else {
      var fromPrefs = prefs.getString(_keyCountryCode);
      if (fromPrefs == null || fromPrefs.isEmpty) {
        final legacy = prefs.getString(_keyServiceRegion);
        fromPrefs = Env.overseasBuild
            ? 'US'
            : (legacy == 'international' ? 'US' : 'CN');
        await prefs.setString(_keyCountryCode, _normalizeCountryCode(fromPrefs));
      }
      cc = _normalizeCountryCode(fromPrefs);
    }

    final locale = _localeFromTag(tag) ??
        (Env.overseasBuild ? const Locale('en') : const Locale('zh', 'CN'));
    final gateDone = gate ?? false;

    final region = serviceRegionForCountryCode(cc);
    Env.setProdServiceRegion(region);
    notifier.value = LocaleRegionState(
      locale: locale,
      countryCode: cc,
      localeGateCompleted: gateDone,
    );
  }

  /// Logged-in users without saved prefs: 国内默认 zh_CN + CN；出海包默认 en + US；gate 已完成。
  Future<void> applyLoggedInDefaultsIfNeeded(bool isLoggedIn) async {
    if (!isLoggedIn) return;
    final prefs = await SharedPreferences.getInstance();
    final hasLocale = prefs.containsKey(_keyLocaleTag);
    final hasCountry = prefs.containsKey(_keyCountryCode);
    final hasLegacyRegion = prefs.containsKey(_keyServiceRegion);
    if (hasLocale && (hasCountry || hasLegacyRegion)) return;

    final fallback = LocaleRegionState(
      locale: Env.overseasBuild ? const Locale('en') : const Locale('zh', 'CN'),
      countryCode: Env.overseasBuild ? 'US' : 'CN',
      localeGateCompleted: true,
    );
    await prefs.setString(_keyLocaleTag, _tagFromLocale(fallback.locale));
    await prefs.setString(_keyCountryCode, fallback.countryCode);
    await prefs.setString(
      _keyServiceRegion,
      fallback.serviceRegion.storageValue,
    );
    await prefs.setBool(_keyGateCompleted, true);

    Env.setProdServiceRegion(fallback.serviceRegion);
    notifier.value = fallback;
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocaleTag, _tagFromLocale(locale));
    notifier.value = notifier.value.copyWith(locale: locale);
  }

  Future<void> setCountryCode(String code) async {
    if (countryLocked) return;
    final prefs = await SharedPreferences.getInstance();
    final cc = _normalizeCountryCode(code);
    final region = serviceRegionForCountryCode(cc);
    await prefs.setString(_keyCountryCode, cc);
    await prefs.setString(_keyServiceRegion, region.storageValue);
    Env.setProdServiceRegion(region);
    notifier.value = notifier.value.copyWith(countryCode: cc);
  }

  Future<void> setLocaleGateCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGateCompleted, completed);
    notifier.value = notifier.value.copyWith(localeGateCompleted: completed);
  }

  /// Restore prefs + Env after a rolled-back cluster switch.
  Future<void> restoreState(LocaleRegionState snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocaleTag, _tagFromLocale(snapshot.locale));
    await prefs.setString(_keyCountryCode, snapshot.countryCode);
    await prefs.setString(
      _keyServiceRegion,
      snapshot.serviceRegion.storageValue,
    );
    await prefs.setBool(_keyGateCompleted, snapshot.localeGateCompleted);
    Env.setProdServiceRegion(snapshot.serviceRegion);
    notifier.value = snapshot;
  }

  String _tagFromLocale(Locale l) {
    if (l.countryCode != null && l.countryCode!.isNotEmpty) {
      return '${l.languageCode}_${l.countryCode}';
    }
    return l.languageCode;
  }

  Locale? _localeFromTag(String? tag) {
    if (tag == null || tag.isEmpty) return null;
    final parts = tag.split('_');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }
}

class LocaleRegionStoreScope extends InheritedWidget {
  const LocaleRegionStoreScope({
    super.key,
    required this.store,
    required super.child,
  });

  final LocaleRegionStore store;

  static LocaleRegionStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LocaleRegionStoreScope>();
    assert(scope != null, 'LocaleRegionStoreScope not found');
    return scope!.store;
  }

  static LocaleRegionStore? maybeOf(BuildContext context) {
    final el = context
        .getElementForInheritedWidgetOfExactType<LocaleRegionStoreScope>();
    final w = el?.widget;
    if (w is LocaleRegionStoreScope) return w.store;
    return null;
  }

  @override
  bool updateShouldNotify(LocaleRegionStoreScope oldWidget) =>
      store != oldWidget.store;
}
