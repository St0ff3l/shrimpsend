import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/desktop_paste_dispatcher.dart';

/// Registers [onPasteFiles] with [DesktopPasteDispatcher] while mounted.
///
/// Unlike [Shortcuts], this works anywhere in the app window while the
/// registering screen is active — no focus on a text field is required.
class DesktopPasteShortcuts extends StatefulWidget {
  const DesktopPasteShortcuts({
    super.key,
    required this.child,
    required this.onPasteFiles,
  });

  final Widget child;
  final Future<void> Function(List<PlatformFile> files) onPasteFiles;

  @override
  State<DesktopPasteShortcuts> createState() => _DesktopPasteShortcutsState();
}

class _DesktopPasteShortcutsState extends State<DesktopPasteShortcuts> {
  @override
  void initState() {
    super.initState();
    DesktopPasteDispatcher.instance.ensureInstalled();
    DesktopPasteDispatcher.instance.register(
      owner: this,
      handler: widget.onPasteFiles,
    );
  }

  @override
  void didUpdateWidget(DesktopPasteShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onPasteFiles != widget.onPasteFiles) {
      DesktopPasteDispatcher.instance.register(
        owner: this,
        handler: widget.onPasteFiles,
      );
    }
  }

  @override
  void dispose() {
    DesktopPasteDispatcher.instance.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
