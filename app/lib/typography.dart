// App typography: WenYuan Sans SC on Windows; system fonts elsewhere.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

const kAppFontFamily = 'UltrasendWenYuanSansSC';

bool get useBundledWenYuanFont => !kIsWeb && Platform.isWindows;

enum FontWeightLevel {
  lighter,
  light,
  normal,
  medium,
  semibold,
}

const List<FontWeightLevel> kFontWeightLevels = FontWeightLevel.values;

double wghtForFontWeightLevel(FontWeightLevel level) {
  switch (level) {
    case FontWeightLevel.lighter:
      return 350;
    case FontWeightLevel.light:
      return 400;
    case FontWeightLevel.normal:
      return 450;
    case FontWeightLevel.medium:
      return 500;
    case FontWeightLevel.semibold:
      return 550;
  }
}

int indexForFontWeightLevel(FontWeightLevel level) => level.index;

FontWeightLevel fontWeightLevelFromIndex(int index) {
  final clamped = index.clamp(0, kFontWeightLevels.length - 1);
  return kFontWeightLevels[clamped];
}

String encodeFontWeightLevel(FontWeightLevel level) {
  switch (level) {
    case FontWeightLevel.lighter:
      return 'lighter';
    case FontWeightLevel.light:
      return 'light';
    case FontWeightLevel.normal:
      return 'normal';
    case FontWeightLevel.medium:
      return 'medium';
    case FontWeightLevel.semibold:
      return 'semibold';
  }
}

FontWeightLevel decodeFontWeightLevel(String? raw) {
  switch (raw) {
    case 'lighter':
      return FontWeightLevel.lighter;
    case 'light':
      return FontWeightLevel.light;
    case 'medium':
      return FontWeightLevel.medium;
    case 'semibold':
      return FontWeightLevel.semibold;
    default:
      return FontWeightLevel.normal;
  }
}

double effectiveWght(TextStyle style, double baseWght) {
  final fw = style.fontWeight;
  if (fw == null) return baseWght;
  final value = fw.value;
  if (value >= 700) return (baseWght + 250).clamp(100, 900);
  if (value >= 600) return (baseWght + 150).clamp(100, 900);
  if (value >= 500) return (baseWght + 50).clamp(100, 900);
  if (value <= 300) return (baseWght - 100).clamp(100, 900);
  return baseWght;
}

FontWeight systemFontWeightForBase(double baseWght, FontWeight? existing) {
  if (existing != null && existing.value >= 600) return existing;
  if (baseWght >= 525) return FontWeight.w500;
  if (baseWght >= 475) return FontWeight.w400;
  if (baseWght >= 425) return FontWeight.w400;
  return FontWeight.w300;
}

TextStyle withAppFont(TextStyle style, {double? baseWght}) {
  final resolvedBase =
      baseWght ?? wghtForFontWeightLevel(FontWeightLevel.normal);
  if (!useBundledWenYuanFont) {
    return style.copyWith(
      fontWeight: systemFontWeightForBase(resolvedBase, style.fontWeight),
      height: style.height ?? 1.5,
    );
  }
  final wght = effectiveWght(style, resolvedBase);
  return style.copyWith(
    fontFamily: kAppFontFamily,
    fontVariations: [FontVariation('wght', wght)],
    height: style.height ?? 1.5,
  );
}

TextStyle? withAppFontNullable(TextStyle? style, {double? baseWght}) =>
    style == null ? null : withAppFont(style, baseWght: baseWght);

@immutable
class AppTypographyConfig extends ThemeExtension<AppTypographyConfig> {
  const AppTypographyConfig({required this.baseWght});

  final double baseWght;

  @override
  AppTypographyConfig copyWith({double? baseWght}) {
    return AppTypographyConfig(baseWght: baseWght ?? this.baseWght);
  }

  @override
  AppTypographyConfig lerp(ThemeExtension<AppTypographyConfig>? other, double t) {
    if (other is! AppTypographyConfig) return this;
    return AppTypographyConfig(
      baseWght: baseWght + (other.baseWght - baseWght) * t,
    );
  }
}

extension AppTypographyContext on BuildContext {
  double get appBaseWght =>
      Theme.of(this).extension<AppTypographyConfig>()?.baseWght ??
      wghtForFontWeightLevel(FontWeightLevel.normal);
}

enum FontSizeLevel {
  smaller,
  small,
  standard,
  large,
  larger,
}

const List<FontSizeLevel> kFontSizeLevels = FontSizeLevel.values;

double scaleForFontSizeLevel(FontSizeLevel level) {
  switch (level) {
    case FontSizeLevel.smaller:
      return 0.88;
    case FontSizeLevel.small:
      return 0.94;
    case FontSizeLevel.standard:
      return 1.0;
    case FontSizeLevel.large:
      return 1.07;
    case FontSizeLevel.larger:
      return 1.14;
  }
}

int indexForFontSizeLevel(FontSizeLevel level) => level.index;

FontSizeLevel fontSizeLevelFromIndex(int index) {
  final clamped = index.clamp(0, kFontSizeLevels.length - 1);
  return kFontSizeLevels[clamped];
}

String encodeFontSizeLevel(FontSizeLevel level) {
  switch (level) {
    case FontSizeLevel.smaller:
      return 'smaller';
    case FontSizeLevel.small:
      return 'small';
    case FontSizeLevel.standard:
      return 'standard';
    case FontSizeLevel.large:
      return 'large';
    case FontSizeLevel.larger:
      return 'larger';
  }
}

FontSizeLevel decodeFontSizeLevel(String? raw) {
  switch (raw) {
    case 'smaller':
      return FontSizeLevel.smaller;
    case 'small':
      return FontSizeLevel.small;
    case 'large':
      return FontSizeLevel.large;
    case 'larger':
      return FontSizeLevel.larger;
    default:
      return FontSizeLevel.standard;
  }
}
