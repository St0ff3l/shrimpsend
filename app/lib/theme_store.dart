import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyTheme = 'ultrasend_theme';

class ThemeStore {
  ThemeStore() {
    _load();
  }

  final ValueNotifier<ThemeMode> notifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyTheme);
    ThemeMode mode = ThemeMode.system;
    if (v == 'light')
      mode = ThemeMode.light;
    else if (v == 'dark')
      mode = ThemeMode.dark;
    notifier.value = mode;
  }

  Future<void> setTheme(ThemeMode mode) async {
    notifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    String v = 'system';
    if (mode == ThemeMode.light)
      v = 'light';
    else if (mode == ThemeMode.dark)
      v = 'dark';
    await prefs.setString(_keyTheme, v);
  }
}

class ThemeStoreScope extends InheritedWidget {
  const ThemeStoreScope({super.key, required this.store, required super.child});

  final ThemeStore store;

  static ThemeStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeStoreScope>();
    assert(scope != null, 'ThemeStoreScope not found');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(ThemeStoreScope oldWidget) =>
      store != oldWidget.store;
}
