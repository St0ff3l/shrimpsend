import 'package:flutter/foundation.dart';
import 'package:openpanel_flutter/openpanel_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../config/openpanel_env.dart';
import '../preferences/service_region.dart';

bool _initialized = false;

/// 启动时初始化 OpenPanel，并在登录态变化时同步 profile。
class OpenpanelBootstrap {
  OpenpanelBootstrap._();

  static bool get isInitialized => _initialized;

  /// 供 [env_snapshot] 打印；不含 secret。
  static String snapshotSummary() {
    if (!_initialized) {
      final region = Env.prodServiceRegion;
      if (region == ServiceRegion.international) {
        if (OpenpanelEnv.intlAppClientId.isEmpty) {
          return 'disabled (missing OP_INTL_APP_CLIENT_ID)';
        }
        return 'disabled (not initialized)';
      }
      if (OpenpanelEnv.cnAppClientId.isEmpty) {
        return 'disabled (missing OP_CN_APP_CLIENT_ID)';
      }
      return 'disabled (not initialized)';
    }
    return 'enabled base=${_displayBase(Openpanel.instance.options.url)}';
  }

  static String _displayBase(String? url) {
    if (url == null || url.isEmpty) return '(default cloud)';
    return url;
  }

  static String _normalizeApiBase(String raw, {required String emptyFallback}) {
    var s = raw.trim();
    if (s.isEmpty) {
      s = emptyFallback;
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.endsWith('/api')) {
      s = '$s/api';
    }
    return s;
  }

  /// 在 [LocaleRegionStore.loadSync] 之后调用（保证 [Env.prodServiceRegion] 已就绪）。
  static Future<void> initIfEligible() async {
    if (_initialized) return;

    if (Env.prodServiceRegion == ServiceRegion.international) {
      if (OpenpanelEnv.intlAppClientId.isEmpty) {
        return;
      }
      await Openpanel.instance.initialize(
        options: OpenpanelOptions(
          url: _normalizeApiBase(
            OpenpanelEnv.intlApiBase,
            emptyFallback: 'https://openpanel.shrimpsend.com/api',
          ),
          clientId: OpenpanelEnv.intlAppClientId,
          clientSecret: OpenpanelEnv.intlAppClientSecret.isEmpty
              ? null
              : OpenpanelEnv.intlAppClientSecret,
          verbose: kDebugMode,
        ),
      );
      _initialized = true;
      return;
    }

    if (OpenpanelEnv.cnAppClientId.isEmpty) {
      return;
    }

    await Openpanel.instance.initialize(
      options: OpenpanelOptions(
        url: _normalizeApiBase(
          OpenpanelEnv.cnApiBase,
          emptyFallback: 'https://openpanel.sdtsdt.net/api',
        ),
        clientId: OpenpanelEnv.cnAppClientId,
        clientSecret: OpenpanelEnv.cnAppClientSecret.isEmpty
            ? null
            : OpenpanelEnv.cnAppClientSecret,
        verbose: kDebugMode,
      ),
    );
    _initialized = true;
  }

  static void identifyLoggedInUser(String userId) {
    if (!_initialized || userId.isEmpty) return;
    Openpanel.instance.updateProfile(
      payload: UpdateProfilePayload(profileId: userId),
    );
  }

  /// 登出后恢复为匿名 profile，避免后续事件仍挂在旧账号上。
  static void onLogout() {
    if (!_initialized) return;
    Openpanel.instance.setProfileId(const Uuid().v4());
  }
}
