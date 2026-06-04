import 'package:shared_preferences/shared_preferences.dart';

import 'typography.dart';

const _keyFontWeight = 'ultrasend_font_weight';

Future<FontWeightLevel> loadFontWeightLevel() async {
  final prefs = await SharedPreferences.getInstance();
  return decodeFontWeightLevel(prefs.getString(_keyFontWeight));
}

Future<void> persistFontWeightLevel(FontWeightLevel level) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyFontWeight, encodeFontWeightLevel(level));
}
