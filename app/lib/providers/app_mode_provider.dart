import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

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

/// 已登录但服务器不可达时由 chat_screen._init 设为 true
final networkFallbackOfflineProvider = StateProvider<bool>((ref) => false);

/// 综合"未登录"和"网络不可达 fallback"的离线状态
final effectiveOfflineModeProvider = Provider<bool>((ref) {
  final authOffline = ref.watch(isOfflineModeProvider);
  final networkFallback = ref.watch(networkFallbackOfflineProvider);
  return authOffline || networkFallback;
});
