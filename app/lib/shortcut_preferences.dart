import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SendShortcutMode { enter, modifierEnter }

const _keySendShortcut = 'ultrasend_send_shortcut';

final sendShortcutModeNotifier = ValueNotifier<SendShortcutMode>(
  SendShortcutMode.modifierEnter,
);

SendShortcutMode _parseSendShortcutMode(String? value) {
  if (value == 'enter') return SendShortcutMode.enter;
  return SendShortcutMode.modifierEnter;
}

String _encodeSendShortcutMode(SendShortcutMode mode) {
  switch (mode) {
    case SendShortcutMode.enter:
      return 'enter';
    case SendShortcutMode.modifierEnter:
      return 'modifier_enter';
  }
}

Future<void> loadSendShortcutMode() async {
  final prefs = await SharedPreferences.getInstance();
  sendShortcutModeNotifier.value = _parseSendShortcutMode(
    prefs.getString(_keySendShortcut),
  );
}

Future<SendShortcutMode> getSendShortcutMode() async {
  final prefs = await SharedPreferences.getInstance();
  return _parseSendShortcutMode(prefs.getString(_keySendShortcut));
}

Future<void> setSendShortcutMode(SendShortcutMode mode) async {
  sendShortcutModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keySendShortcut, _encodeSendShortcutMode(mode));
}

String encodeSendShortcutModeForAnalytics(SendShortcutMode mode) =>
    _encodeSendShortcutMode(mode);
