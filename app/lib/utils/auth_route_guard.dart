import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

/// Returns `true` when the user is signed in.
/// Otherwise pops the current route (if any) and navigates to `/login`.
bool ensureLoggedInForRoute(BuildContext context, WidgetRef ref) {
  if (ref.read(authProvider).isLoggedIn) return true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    Navigator.of(context).pushNamed('/login');
  });
  return false;
}
