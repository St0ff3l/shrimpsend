import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_session_controller.dart';
import 'auth_provider.dart';

final authSessionControllerProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionPhase>((ref) {
  final controller = AuthSessionController(ref);
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (prev?.isLoggedIn == true && !next.isLoggedIn) {
      controller.syncLoggedOutFromAuth();
    }
  });
  return controller;
});

final authSessionPhaseProvider = Provider<AuthSessionPhase>((ref) {
  return ref.watch(authSessionControllerProvider);
});

/// 云端功能（Centrifugo、设备列表、S3 云传输等）是否可用。
final isCloudSessionActiveProvider = Provider<bool>((ref) {
  return ref.watch(authSessionPhaseProvider) == AuthSessionPhase.authenticated;
});
