import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'auth_session_provider.dart';
import '../services/auth_session_controller.dart';

enum AppMode { online, offline }

final appModeProvider = Provider<AppMode>((ref) {
  final auth = ref.watch(authProvider);
  return auth.isLoggedIn ? AppMode.online : AppMode.offline;
});

final isOfflineModeProvider = Provider<bool>((ref) {
  return ref.watch(appModeProvider) == AppMode.offline;
});

final isOnlineModeProvider = Provider<bool>((ref) {
  return ref.watch(appModeProvider) == AppMode.online;
});

/// 综合未登录、验证中、会话过期、服务器不可达时的离线 fallback（LAN 仍可用）。
final effectiveOfflineModeProvider = Provider<bool>((ref) {
  final phase = ref.watch(authSessionPhaseProvider);
  return phase == AuthSessionPhase.unauthenticated ||
      phase == AuthSessionPhase.validating ||
      phase == AuthSessionPhase.sessionExpired ||
      phase == AuthSessionPhase.networkUnavailable;
});
