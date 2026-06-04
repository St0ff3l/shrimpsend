import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart';
import '../device_id.dart';
import '../logger.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../services/openpanel_bootstrap.dart';
import '../services/revenuecat_service.dart';

const _keyAccessToken = 'accessToken';
const _keyRefreshToken = 'refreshToken';
const _keyUserId = 'userId';
const _keyOfflineUserId = 'ultrasend_offline_user_id';
const _keyOfflineWithoutLogin = 'ultrasend_offline_without_login';

class AuthState {
  final bool isLoggedIn;
  final String? userId;
  final String? accessToken;

  const AuthState({
    this.isLoggedIn = false,
    this.userId,
    this.accessToken,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? userId,
    String? accessToken,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        userId: userId ?? this.userId,
        accessToken: accessToken ?? this.accessToken,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_keyAccessToken);
    final refreshToken = prefs.getString(_keyRefreshToken);
    final userId = prefs.getString(_keyUserId);
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty) {
      setAccessToken(accessToken);
      state = AuthState(
        isLoggedIn: true,
        userId: userId,
        accessToken: accessToken,
      );
      logAuth.info('AuthNotifier loadFromStorage restored userId=$userId');
      RevenueCatService.instance.configureIfNeeded(userId);
      OpenpanelBootstrap.identifyLoggedInUser(userId);
    } else {
      if (accessToken != null && accessToken.isNotEmpty) {
        logAuth.warning(
          'AuthNotifier loadFromStorage incomplete session (missing refreshToken or userId), clearing',
        );
        await _clearStorage();
      } else {
        logAuth.info('AuthNotifier loadFromStorage no stored auth');
      }
    }
  }

  Future<void> login(AuthResponse auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, auth.accessToken);
    await prefs.setString(_keyRefreshToken, auth.refreshToken);
    await prefs.setString(_keyUserId, auth.userId);
    setAccessToken(auth.accessToken);

    state = AuthState(
      isLoggedIn: true,
      userId: auth.userId,
      accessToken: auth.accessToken,
    );
    logAuth.info('AuthNotifier login userId=${auth.userId}');
    RevenueCatService.instance.configureIfNeeded(auth.userId);
    OpenpanelBootstrap.identifyLoggedInUser(auth.userId);
  }

  Future<void> logout() async {
    var apiOk = true;
    try {
      final deviceId = await getOrCreateDeviceId();
      await apiLogout(deviceId: deviceId);
    } catch (e) {
      apiOk = false;
      logAuth.warning('AuthNotifier logout API call failed: $e');
    }
    await RevenueCatService.instance.logOutIfNeeded();
    await _clearStorage();
    OpenpanelBootstrap.onLogout();
    Analytics.track(AnalyticsEvents.logout, {'api_logout_ok': apiOk});
    logAuth.info('AuthNotifier logout');
  }

  Future<void> clearAuth() async {
    await RevenueCatService.instance.logOutIfNeeded();
    await _clearStorage();
    OpenpanelBootstrap.onLogout();
    logAuth.info('AuthNotifier clearAuth');
  }

  Future<void> refreshTokenSuccess(AuthResponse auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, auth.accessToken);
    await prefs.setString(_keyRefreshToken, auth.refreshToken);
    await prefs.setString(_keyUserId, auth.userId);
    setAccessToken(auth.accessToken);
    state = AuthState(
      isLoggedIn: true,
      userId: auth.userId,
      accessToken: auth.accessToken,
    );
    RevenueCatService.instance.configureIfNeeded(auth.userId);
    OpenpanelBootstrap.identifyLoggedInUser(auth.userId);
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    setAccessToken(null);
    state = const AuthState();
  }

}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

Future<String?> getStoredRefreshToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyRefreshToken);
}

Future<String?> getStoredUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyUserId);
}

Future<String> getOrCreateOfflineUserId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_keyOfflineUserId);
  if (id == null || id.isEmpty) {
    final deviceId = await getOrCreateDeviceId();
    id = 'offline_$deviceId';
    await prefs.setString(_keyOfflineUserId, id);
  }
  return id;
}

Future<String?> getOfflineUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyOfflineUserId);
}

Future<bool> loadOfflineWithoutLogin() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyOfflineWithoutLogin) ?? false;
}

Future<void> setOfflineWithoutLogin(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyOfflineWithoutLogin, value);
}
