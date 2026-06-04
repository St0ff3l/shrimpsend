import 'dart:convert';

import 'package:openpanel_flutter/src/models/open_panel_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class PreferencesService {
  final SharedPreferences _sharedPreferences;

  PreferencesService(this._sharedPreferences);

  Future<void> persistState(OpenpanelState state) async {
    final jsonString = jsonEncode(state.toJson());
    await _sharedPreferences.setString(_key, jsonString);
  }

  Future<OpenpanelState?> getSavedState() async {
    final jsonString = _sharedPreferences.getString(_key);
    if (jsonString == null) {
      return null;
    }
    return OpenpanelState.fromJson(jsonDecode(jsonString));
  }

  static const _key = 'openpanel_state';
}
