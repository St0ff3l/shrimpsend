import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';

/// Mirrors [LocaleRegionStore.notifier] so providers can call [lookupAppLocalizations].
/// Synced from [main.dart] after the store loads.
final appLocaleProvider = StateProvider<Locale>(
  (ref) => Env.overseasBuild ? const Locale('en') : const Locale('zh', 'CN'),
);
