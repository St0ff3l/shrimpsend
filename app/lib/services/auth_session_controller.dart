import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../logger.dart';
import '../providers/auth_provider.dart';

/// 云端会话阶段：单一真相源，替代 networkFallbackOfflineProvider。
enum AuthSessionPhase {
  unauthenticated,
  validating,
  authenticated,
  sessionExpired,
  networkUnavailable,
}

class AuthSessionController extends StateNotifier<AuthSessionPhase> {
  AuthSessionController(this.ref) : super(AuthSessionPhase.unauthenticated);

  final Ref ref;

  Completer<RefreshSessionOutcome>? _refreshInFlight;
  bool _invalidateInProgress = false;
  bool _invalidatingSession = false;
  Timer? _proactiveRefreshTimer;

  static const _proactiveRefreshBuffer = Duration(minutes: 3);
  static const _defaultAccessTtl = Duration(minutes: 15);

  /// 由 main.dart 注入：清会话后导航登录页并 toast。
  Future<void> Function()? onSessionExpiredNavigate;

  void onStorageLoaded({required bool isLoggedIn}) {
    if (isLoggedIn) {
      state = AuthSessionPhase.validating;
    } else {
      state = AuthSessionPhase.unauthenticated;
    }
  }

  void onLoginSuccess() {
    state = AuthSessionPhase.validating;
    unawaited(
      bootstrapSession(
        useRetry: false,
        waitForNetwork: () async {},
      ),
    );
  }

  void onLogout() {
    cancelProactiveRefresh();
    state = AuthSessionPhase.unauthenticated;
  }

  void syncLoggedOutFromAuth() {
    if (_invalidatingSession) return;
    onLogout();
  }

  void markServerReachable() {
    if (!ref.read(authProvider).isLoggedIn) return;
    if (state == AuthSessionPhase.sessionExpired) return;
    state = AuthSessionPhase.authenticated;
  }

  void markNetworkUnavailable() {
    if (!ref.read(authProvider).isLoggedIn) return;
    if (state == AuthSessionPhase.sessionExpired) return;
    state = AuthSessionPhase.networkUnavailable;
  }

  Future<void> bootstrapSession({
    required bool useRetry,
    required Future<void> Function() waitForNetwork,
  }) async {
    if (!ref.read(authProvider).isLoggedIn) return;

    state = AuthSessionPhase.validating;
    logAuth.info('auth session bootstrap begin useRetry=$useRetry');

    await waitForNetwork();

    final outcome = await refreshSingleFlight(useRetry: useRetry);
    if (outcome == RefreshSessionOutcome.permanentFailure ||
        outcome == RefreshSessionOutcome.noRefreshToken) {
      logAuth.warning('auth session bootstrap permanent failure ($outcome)');
      await invalidateSession(showToast: true);
      return;
    }
    if (outcome == RefreshSessionOutcome.success) {
      logAuth.info('auth session bootstrap success');
      state = AuthSessionPhase.authenticated;
      unawaited(scheduleProactiveRefresh());
      return;
    }
    logAuth.warning('auth session bootstrap transient failure, keeping session');
    state = AuthSessionPhase.networkUnavailable;
    unawaited(scheduleProactiveRefresh());
  }

  void cancelProactiveRefresh() {
    _proactiveRefreshTimer?.cancel();
    _proactiveRefreshTimer = null;
  }

  Future<void> scheduleProactiveRefresh() async {
    cancelProactiveRefresh();
    if (!ref.read(authProvider).isLoggedIn) return;

    final expiresAt =
        await ref.read(authProvider.notifier).getAccessTokenExpiresAt();
    final refreshAt = expiresAt != null
        ? expiresAt.subtract(_proactiveRefreshBuffer)
        : DateTime.now().add(_defaultAccessTtl - _proactiveRefreshBuffer);

    final delay = refreshAt.difference(DateTime.now());
    if (delay.isNegative) {
      unawaited(_runProactiveRefresh());
      return;
    }

    _proactiveRefreshTimer = Timer(delay, () {
      unawaited(_runProactiveRefresh());
    });
  }

  Future<void> _runProactiveRefresh() async {
    if (!ref.read(authProvider).isLoggedIn) return;
    logAuth.info('auth session proactive refresh');
    final outcome = await refreshSingleFlight();
    if (outcome == RefreshSessionOutcome.success) {
      if (state != AuthSessionPhase.sessionExpired) {
        state = AuthSessionPhase.authenticated;
      }
      await scheduleProactiveRefresh();
      return;
    }
    if (outcome == RefreshSessionOutcome.permanentFailure ||
        outcome == RefreshSessionOutcome.noRefreshToken) {
      logAuth.warning('auth session proactive refresh permanent failure ($outcome)');
      await invalidateSession(showToast: true);
    }
  }

  Future<void> onAppResumed() async {
    if (!ref.read(authProvider).isLoggedIn) return;
    if (state == AuthSessionPhase.sessionExpired) return;

    final expiresAt =
        await ref.read(authProvider.notifier).getAccessTokenExpiresAt();
    final threshold = expiresAt?.subtract(_proactiveRefreshBuffer) ??
        DateTime.now().add(_defaultAccessTtl - _proactiveRefreshBuffer);
    if (DateTime.now().isBefore(threshold)) return;

    logAuth.info('auth session resume refresh');
    final outcome = await refreshSingleFlight(useRetry: true);
    if (outcome == RefreshSessionOutcome.success) {
      state = AuthSessionPhase.authenticated;
      await scheduleProactiveRefresh();
      return;
    }
    if (outcome == RefreshSessionOutcome.transientFailure) {
      markNetworkUnavailable();
    }
  }

  Future<RefreshSessionOutcome> refreshSingleFlight({
    bool useRetry = false,
    int attempt = 1,
  }) async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<RefreshSessionOutcome>();
    _refreshInFlight = completer;

    try {
      final outcome = useRetry
          ? await _refreshWithRetry()
          : await _tryRefreshStoredSession(attempt: attempt);
      completer.complete(outcome);
      return outcome;
    } catch (e, st) {
      logAuth.warning('refreshSingleFlight error: $e', e, st);
      completer.complete(RefreshSessionOutcome.transientFailure);
      return RefreshSessionOutcome.transientFailure;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<RefreshSessionOutcome> _refreshWithRetry() async {
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    var lastOutcome = RefreshSessionOutcome.transientFailure;

    for (var attempt = 1; attempt <= retryDelays.length; attempt++) {
      if (attempt > 1) {
        await Future.delayed(retryDelays[attempt - 1]);
        logAuth.info('auth session refresh retry attempt=$attempt');
      }
      lastOutcome = await _tryRefreshStoredSession(attempt: attempt);
      if (lastOutcome == RefreshSessionOutcome.success ||
          lastOutcome == RefreshSessionOutcome.permanentFailure ||
          lastOutcome == RefreshSessionOutcome.noRefreshToken) {
        return lastOutcome;
      }
    }
    return lastOutcome;
  }

  Future<RefreshSessionOutcome> _tryRefreshStoredSession({int attempt = 1}) {
    return refreshStoredSession(
      readRefreshToken: getStoredRefreshToken,
      onSuccess: (auth) async {
        await ref.read(authProvider.notifier).refreshTokenSuccess(auth);
      },
      onAttemptFinished:
          ({
            required outcome,
            required failureKind,
            error,
            httpStatus,
            attempt = 1,
          }) {
            if (outcome == RefreshSessionOutcome.success) {
              logAuth.info('tryRefreshStoredSession success attempt=$attempt');
              return;
            }
            logAuth.warning(
              'tryRefreshStoredSession failed attempt=$attempt '
              'outcome=$outcome failureKind=$failureKind '
              'httpStatus=$httpStatus error=$error',
            );
          },
      attempt: attempt,
    );
  }

  Future<void> invalidateSession({required bool showToast}) async {
    if (_invalidateInProgress) return;
    _invalidateInProgress = true;
    _invalidatingSession = true;
    cancelProactiveRefresh();
    try {
      state = AuthSessionPhase.sessionExpired;
      await ref.read(authProvider.notifier).clearAuth();
      if (showToast && onSessionExpiredNavigate != null) {
        await onSessionExpiredNavigate!();
      }
      state = AuthSessionPhase.unauthenticated;
    } finally {
      _invalidatingSession = false;
      _invalidateInProgress = false;
    }
  }

  /// 供 [withAuthRetry] 调用：401 → refresh → 重试或抛出 [SessionUnavailableException]。
  Future<T> handle401WithRetry<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on AuthException catch (authError) {
      logApi.info('withAuthRetry: auth failed, attempting refresh');
      final outcome = await refreshSingleFlight();
      if (outcome == RefreshSessionOutcome.success) {
        logApi.info('withAuthRetry: refresh ok, retrying');
        try {
          return await fn();
        } on AuthException catch (_) {
          logApi.warning(
            'withAuthRetry: still 401 after refresh, invalidating session',
          );
          await invalidateSession(showToast: true);
          throw SessionUnavailableException(
            SessionUnavailableKind.expired,
            authError.message,
          );
        }
      }
      if (outcome == RefreshSessionOutcome.transientFailure) {
        logApi.warning(
          'withAuthRetry: transient refresh failure, network unavailable',
        );
        markNetworkUnavailable();
        throw const SessionUnavailableException(
          SessionUnavailableKind.transient,
          '服务器暂不可达，请稍后重试',
        );
      }
      await invalidateSession(showToast: true);
      throw SessionUnavailableException(
        SessionUnavailableKind.expired,
        authError.message,
      );
    }
  }
}
