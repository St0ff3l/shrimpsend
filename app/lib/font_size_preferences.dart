import 'package:shared_preferences/shared_preferences.dart';

import 'typography.dart';

const _keyFontSize = 'ultrasend_font_size';

Future<FontSizeLevel> loadFontSizeLevel() async {
  final prefs = await SharedPreferences.getInstance();
  return decodeFontSizeLevel(prefs.getString(_keyFontSize));
}

Future<void> persistFontSizeLevel(FontSizeLevel level) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyFontSize, encodeFontSizeLevel(level));
}
