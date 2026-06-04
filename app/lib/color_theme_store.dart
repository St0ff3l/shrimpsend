import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'color_theme.dart';

const _keyColorTheme = 'ultrasend_color_theme';

class ColorThemeStore {
  ColorThemeStore() {
    _load();
  }

  final ValueNotifier<AppColorTheme> notifier = ValueNotifier<AppColorTheme>(
    AppColorTheme.emerald,
  );

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyColorTheme);
    if (id != null) {
      notifier.value = AppColorTheme.fromId(id);
    }
  }

  Future<void> setTheme(AppColorTheme theme) async {
    notifier.value = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyColorTheme, theme.id);
  }
}

class ColorThemeStoreScope extends InheritedWidget {
  const ColorThemeStoreScope({
    super.key,
    required this.store,
    required super.child,
  });

  final ColorThemeStore store;

  static ColorThemeStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ColorThemeStoreScope>();
    assert(scope != null, 'ColorThemeStoreScope not found');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(ColorThemeStoreScope oldWidget) =>
      store != oldWidget.store;
}
