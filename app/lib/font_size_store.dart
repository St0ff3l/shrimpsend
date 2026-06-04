import 'package:flutter/material.dart';

import 'font_size_preferences.dart';
import 'font_weight_preferences.dart';
import 'typography.dart';

class FontSizeStore {
  FontSizeStore();

  final ValueNotifier<FontSizeLevel> notifier =
      ValueNotifier<FontSizeLevel>(FontSizeLevel.standard);
  final ValueNotifier<FontWeightLevel> weightNotifier =
      ValueNotifier<FontWeightLevel>(FontWeightLevel.normal);

  double get scale => scaleForFontSizeLevel(notifier.value);

  double get baseWght => wghtForFontWeightLevel(weightNotifier.value);

  Future<void> load() async {
    notifier.value = await loadFontSizeLevel();
    weightNotifier.value = await loadFontWeightLevel();
  }

  Future<void> setLevel(FontSizeLevel level) async {
    notifier.value = level;
    await persistFontSizeLevel(level);
  }

  Future<void> setWeightLevel(FontWeightLevel level) async {
    weightNotifier.value = level;
    await persistFontWeightLevel(level);
  }
}

class FontSizeStoreScope extends InheritedWidget {
  const FontSizeStoreScope({
    super.key,
    required this.store,
    required super.child,
  });

  final FontSizeStore store;

  static FontSizeStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FontSizeStoreScope>();
    assert(scope != null, 'FontSizeStoreScope not found');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(FontSizeStoreScope oldWidget) =>
      store != oldWidget.store;
}
