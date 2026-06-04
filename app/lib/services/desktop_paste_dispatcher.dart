import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../utils/runtime_platform.dart';
import 'desktop_file_clipboard.dart';

typedef DesktopPasteHandler = Future<void> Function(List<PlatformFile> files);

/// App-wide Ctrl/Cmd+V file paste on desktop (does not require widget focus).
final class DesktopPasteDispatcher {
  DesktopPasteDispatcher._();

  static final DesktopPasteDispatcher instance = DesktopPasteDispatcher._();

  final List<_Registration> _handlers = [];
  bool _hooked = false;

  void ensureInstalled() {
    if (!RuntimePlatform.isDesktop || _hooked) return;
    _hooked = true;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// [owner] is typically the [State] of the screen that registers.
  void register({
    required Object owner,
    required DesktopPasteHandler handler,
  }) {
    _handlers.removeWhere((r) => r.owner == owner);
    _handlers.add(_Registration(owner, handler));
  }

  void unregister(Object owner) {
    _handlers.removeWhere((r) => r.owner == owner);
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyV) return false;
    final pressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!pressed || _handlers.isEmpty) return false;

    unawaited(_dispatchPaste());
    return false;
  }

  Future<void> _dispatchPaste() async {
    final files = await DesktopFileClipboard.readFilesForPending();
    if (files.isEmpty) return;
    await _handlers.last.handler(files);
  }
}

class _Registration {
  _Registration(this.owner, this.handler);

  final Object owner;
  final DesktopPasteHandler handler;
}
