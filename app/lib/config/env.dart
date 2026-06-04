import 'package:flutter/foundation.dart';

import '../preferences/service_region.dart';
import 'env.secrets.dart';

enum AppEnv { dev, prod }

class Env {
  Env._();

  /// 出海发行包：编译时 `--dart-define=OVERSEAS_BUILD=true`，默认国家/地区美国、海外集群。
  static const overseasBuild = bool.fromEnvironment(
    'OVERSEAS_BUILD',
    defaultValue: false,
  );

  /// 面向 Google Play 等需合规清单的 Android 包：与 `play` Gradle flavor 对齐，应同时传入
  /// `--dart-define=ANDROID_PLAY_DISTRIBUTION=true`；用于隐藏 APK 发送/安装并配合 Manifest 移除敏感权限。
  static const androidPlayDistribution = bool.fromEnvironment(
    'ANDROID_PLAY_DISTRIBUTION',
    defaultValue: false,
  );

  static const _devApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:9000',
  );

  static const _devCentrifugoWs = String.fromEnvironment(
    'CENTRIFUGO_WS',
    defaultValue: 'ws://localhost:8000/connection/websocket',
  );

  static const _prodApiXiachuan = String.fromEnvironment(
    'API_URL_PROD_CN',
    defaultValue: EnvSecrets.prodApiCn,
  );
  static const _prodWsXiachuan = String.fromEnvironment(
    'CENTRIFUGO_WS_PROD_CN',
    defaultValue: EnvSecrets.prodWsCn,
  );
  static const _prodApiShrimpsend = String.fromEnvironment(
    'API_URL_PROD_INTL',
    defaultValue: EnvSecrets.prodApiIntl,
  );
  static const _prodWsShrimpsend = String.fromEnvironment(
    'CENTRIFUGO_WS_PROD_INTL',
    defaultValue: EnvSecrets.prodWsIntl,
  );

  /// Resolved from [LocaleRegionStore] / prefs before networking.
  static ServiceRegion _prodServiceRegion = ServiceRegion.mainlandChina;

  static ServiceRegion get prodServiceRegion => _prodServiceRegion;

  static void setProdServiceRegion(ServiceRegion region) {
    _prodServiceRegion = region;
  }

  static String get _prodApiUrlResolved => switch (_prodServiceRegion) {
        ServiceRegion.mainlandChina => _prodApiXiachuan,
        ServiceRegion.international => _prodApiShrimpsend,
      };

  static String get _prodCentrifugoWsResolved =>
      switch (_prodServiceRegion) {
        ServiceRegion.mainlandChina => _prodWsXiachuan,
        ServiceRegion.international => _prodWsShrimpsend,
      };

  /// RevenueCat Test Store 公钥（本地 debug/profile 默认使用）。
  /// 值来自 gitignored [env.secrets.dart] 或 `--dart-define=RC_TEST_STORE_API_KEY`。
  static const _rcTestStoreApiKey = String.fromEnvironment(
    'RC_TEST_STORE_API_KEY',
    defaultValue: EnvSecrets.rcTestStoreApiKey,
  );

  /// ShrimpSend intl iOS — RevenueCat 海外 Project 公钥（`appl_` 前缀，release intl 包）。
  static const _rcAppleApiKeyProdIntl = String.fromEnvironment(
    'RC_APPLE_API_KEY_INTL',
    defaultValue: EnvSecrets.rcAppleApiKeyProdIntl,
  );

  /// 虾传 cn iOS — RevenueCat 国内 Project 公钥（release cn 包）。
  static const _rcAppleApiKeyProdCn = String.fromEnvironment(
    'RC_APPLE_API_KEY_CN',
    defaultValue: EnvSecrets.rcAppleApiKeyProdCn,
  );

  /// RevenueCat 正式 Google 公钥（`goog_` 前缀，仅 release 构建使用；空则回退 Apple 正式 key）。
  static const _rcGoogleApiKeyProd = String.fromEnvironment(
    'RC_GOOGLE_API_KEY',
    defaultValue: EnvSecrets.rcGoogleApiKeyProd,
  );
  static const _rcProductMini = String.fromEnvironment(
    'RC_PRODUCT_MINI',
    defaultValue: 'ultrasend_mini_lifetime',
  );
  static const _rcProductPro = String.fromEnvironment(
    'RC_PRODUCT_PRO',
    defaultValue: 'ultrasend_pro_lifetime',
  );
  static const _rcProductAddon5 = String.fromEnvironment(
    'RC_PRODUCT_ADDON_5',
    defaultValue: 'ultrasend_addon_5_devices',
  );

  /// ShrimpSend overseas subscription (RevenueCat product ids — align with backend `app.membership.overseas.rc-*`).
  static const rcPlusMonthly = String.fromEnvironment(
    'RC_PLUS_MONTHLY',
    defaultValue: 'shrimpsend_plus_monthly',
  );
  static const rcPlusYearly = String.fromEnvironment(
    'RC_PLUS_YEARLY',
    defaultValue: 'shrimpsend_plus_yearly',
  );
  static const rcProMonthly = String.fromEnvironment(
    'RC_PRO_MONTHLY',
    defaultValue: 'shrimpsend_pro_monthly',
  );
  static const rcProYearly = String.fromEnvironment(
    'RC_PRO_YEARLY',
    defaultValue: 'shrimpsend_pro_yearly',
  );
  static const rcUltraMonthly = String.fromEnvironment(
    'RC_ULTRA_MONTHLY',
    defaultValue: 'shrimpsend_ultra_monthly',
  );
  static const rcUltraYearly = String.fromEnvironment(
    'RC_ULTRA_YEARLY',
    defaultValue: 'shrimpsend_ultra_yearly',
  );

  /// Stripe Price IDs for desktop/web checkout. Must align with backend
  /// `app.membership.overseas.stripe-price-*`. Leave blank to disable Stripe entry on this build.
  static const stripePricePlusMonthly = String.fromEnvironment(
    'STRIPE_PRICE_PLUS_MONTHLY',
    defaultValue: '',
  );
  static const stripePricePlusYearly = String.fromEnvironment(
    'STRIPE_PRICE_PLUS_YEARLY',
    defaultValue: '',
  );
  static const stripePriceProMonthly = String.fromEnvironment(
    'STRIPE_PRICE_PRO_MONTHLY',
    defaultValue: '',
  );
  static const stripePriceProYearly = String.fromEnvironment(
    'STRIPE_PRICE_PRO_YEARLY',
    defaultValue: '',
  );
  static const stripePriceUltraMonthly = String.fromEnvironment(
    'STRIPE_PRICE_ULTRA_MONTHLY',
    defaultValue: '',
  );
  static const stripePriceUltraYearly = String.fromEnvironment(
    'STRIPE_PRICE_ULTRA_YEARLY',
    defaultValue: '',
  );

  /// Returns the Stripe Price ID corresponding to a backend tier code such as `PLUS_MONTHLY`.
  /// Empty string means not configured for this build.
  static String stripePriceIdForTierCode(String tierCode) {
    switch (tierCode.toUpperCase()) {
      case 'PLUS_MONTHLY':
        return stripePricePlusMonthly;
      case 'PLUS_YEARLY':
        return stripePricePlusYearly;
      case 'PRO_MONTHLY':
        return stripePriceProMonthly;
      case 'PRO_YEARLY':
        return stripePriceProYearly;
      case 'ULTRA_MONTHLY':
        return stripePriceUltraMonthly;
      case 'ULTRA_YEARLY':
        return stripePriceUltraYearly;
      default:
        return '';
    }
  }

  static AppEnv _current = kReleaseMode ? AppEnv.prod : AppEnv.dev;

  static AppEnv get current => _current;

  static bool get canSwitch => !kReleaseMode;

  static void switchTo(AppEnv env) {
    if (kReleaseMode) return;
    _current = env;
  }

  static String get apiUrl =>
      _current == AppEnv.prod ? _prodApiUrlResolved : _devApiUrl;

  static String get centrifugoWs =>
      _current == AppEnv.prod ? _prodCentrifugoWsResolved : _devCentrifugoWs;

  static String get label => _current == AppEnv.prod ? '线上' : '测试';

  static String get rcAppleApiKey {
    if (!kReleaseMode) return _rcTestStoreApiKey;
    return overseasBuild ? _rcAppleApiKeyProdIntl : _rcAppleApiKeyProdCn;
  }

  /// Google Play RevenueCat public key; release 未配置时回退 intl Apple 正式 key。
  static String get rcGoogleApiKey {
    if (kReleaseMode) {
      return _rcGoogleApiKeyProd.isNotEmpty
          ? _rcGoogleApiKeyProd
          : _rcAppleApiKeyProdIntl;
    }
    return _rcTestStoreApiKey;
  }

  /// `test` = Test Store（debug/profile）；`prod` = 正式商店 key（release）。
  static String get rcStoreMode => kReleaseMode ? 'prod' : 'test';

  /// Platform-appropriate RevenueCat SDK public key.
  static String get rcApiKey {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return rcGoogleApiKey;
    }
    return rcAppleApiKey;
  }

  static String get rcProductMini => _rcProductMini;

  static String get rcProductPro => _rcProductPro;

  static String get rcProductAddon5 => _rcProductAddon5;
}
