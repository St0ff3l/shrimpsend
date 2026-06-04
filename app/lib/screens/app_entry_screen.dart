import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences/locale_region_store.dart';
import '../providers/auth_provider.dart';
import 'chat_screen.dart';
import 'locale_region_gate_screen.dart';
import 'login_screen.dart';

/// Chooses gate → login → chat based on prefs and auth.
class AppEntryScreen extends ConsumerStatefulWidget {
  const AppEntryScreen({
    super.key,
    required this.localeRegionStore,
    this.initialOfflineWithoutLogin = false,
  });

  final LocaleRegionStore localeRegionStore;
  final bool initialOfflineWithoutLogin;

  @override
  ConsumerState<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends ConsumerState<AppEntryScreen> {
  late bool _offlineWithoutLogin;

  @override
  void initState() {
    super.initState();
    _offlineWithoutLogin = widget.initialOfflineWithoutLogin;
  }

  Future<void> _enterOfflineWithoutLogin() async {
    await setOfflineWithoutLogin(true);
    if (!mounted) return;
    setState(() => _offlineWithoutLogin = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return ValueListenableBuilder<LocaleRegionState>(
      valueListenable: widget.localeRegionStore.notifier,
      builder: (context, lr, _) {
        if (!lr.localeGateCompleted) {
          return LocaleRegionGateScreen(store: widget.localeRegionStore);
        }

        if (auth.isLoggedIn || _offlineWithoutLogin) {
          return const ChatScreen();
        }

        return LoginScreen(
          onOfflineMode: _enterOfflineWithoutLogin,
        );
      },
    );
  }
}
