import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_session_provider.dart';

/// 监听 App 生命周期，在 resume 时补刷即将过期的 JWT。
class AuthSessionLifecycle extends ConsumerStatefulWidget {
  const AuthSessionLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthSessionLifecycle> createState() =>
      _AuthSessionLifecycleState();
}

class _AuthSessionLifecycleState extends ConsumerState<AuthSessionLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authSessionControllerProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
