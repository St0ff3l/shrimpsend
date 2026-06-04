import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../l10n/generated/app_localizations.dart';
import '../logger.dart';
import '../utils/desktop_drop_files.dart';
import '../utils/runtime_platform.dart';
import '../utils/toast.dart';
import 'pending_files_store.dart';

typedef DesktopDropHandler = Future<void> Function(List<PlatformFile> files);

/// App-wide external file drop on desktop (mirrors [DesktopPasteDispatcher]).
final class DesktopFileDropDispatcher {
  DesktopFileDropDispatcher._();

  static final DesktopFileDropDispatcher instance = DesktopFileDropDispatcher._();

  final ValueNotifier<bool> isHovering = ValueNotifier(false);

  final List<_Registration> _handlers = [];

  /// [owner] is typically the [State] of the screen that registers.
  void register({
    required Object owner,
    required DesktopDropHandler handler,
  }) {
    _handlers.removeWhere((r) => r.owner == owner);
    _handlers.add(_Registration(owner, handler));
  }

  void unregister(Object owner) {
    _handlers.removeWhere((r) => r.owner == owner);
  }

  Future<void> dispatch(
    List<PlatformFile> files, {
    GlobalKey<NavigatorState>? navigatorKey,
    Locale? locale,
  }) async {
    if (files.isEmpty) return;
    if (_handlers.isNotEmpty) {
      await _handlers.last.handler(files);
      return;
    }
    await _persistFallback(files);
    _showFallbackToast(
      files,
      navigatorKey: navigatorKey,
      locale: locale,
    );
  }

  Future<void> _persistFallback(List<PlatformFile> files) async {
    final existing = await PendingFilesStore.load();
    final merged = _mergePending(existing.files, files);
    await PendingFilesStore.save(merged);
  }

  List<PlatformFile> _mergePending(
    List<PlatformFile> existing,
    List<PlatformFile> incoming,
  ) {
    final paths = existing
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toSet();
    final keys = existing
        .where((f) => f.path == null)
        .map((f) => '${f.name}_${f.size}')
        .toSet();
    final out = List<PlatformFile>.from(existing);
    for (final file in incoming) {
      if (file.path != null) {
        if (paths.add(file.path!)) out.add(file);
      } else {
        final key = '${file.name}_${file.size}';
        if (keys.add(key)) out.add(file);
      }
    }
    return out;
  }

  void _showFallbackToast(
    List<PlatformFile> files, {
    GlobalKey<NavigatorState>? navigatorKey,
    Locale? locale,
  }) {
    if (files.isEmpty) return;
    final ctx = navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final loc = locale != null
        ? lookupAppLocalizations(locale)
        : AppLocalizations.of(ctx);
    final message = files.length == 1
        ? loc.fmPendingAddedOne(files.first.name)
        : loc.fmPendingAddedMany(files.length);
    AppToast.show(ctx, message: message);
  }
}

class _Registration {
  _Registration(this.owner, this.handler);

  final Object owner;
  final DesktopDropHandler handler;
}

/// Wraps the app with a full-window [DropRegion] for inbound file drops.
class DesktopFileDropScope extends StatelessWidget {
  const DesktopFileDropScope({
    super.key,
    required this.child,
    this.navigatorKey,
    this.locale,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    if (!RuntimePlatform.isDesktop) return child;
    return _DesktopFileDropScopeBody(
      navigatorKey: navigatorKey,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      child: child,
    );
  }
}

class _DesktopFileDropScopeBody extends StatefulWidget {
  const _DesktopFileDropScopeBody({
    required this.child,
    this.navigatorKey,
    this.locale,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  final Locale? locale;

  @override
  State<_DesktopFileDropScopeBody> createState() =>
      _DesktopFileDropScopeBodyState();
}

class _DesktopFileDropScopeBodyState extends State<_DesktopFileDropScopeBody> {
  final _dispatcher = DesktopFileDropDispatcher.instance;

  bool _sessionHasExternalFiles(DropSession session) {
    for (final item in session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;
      final formats = reader.getFormats(const [...Formats.standardFormats]);
      if (formats.contains(Formats.fileUri) || formats.contains(Formats.uri)) {
        return true;
      }
    }
    return false;
  }

  Future<DropOperation> _onDropOver(DropOverEvent event) async {
    if (!_sessionHasExternalFiles(event.session)) {
      return DropOperation.none;
    }
    if (!_dispatcher.isHovering.value) {
      _dispatcher.isHovering.value = true;
    }
    return event.session.allowedOperations.contains(DropOperation.copy)
        ? DropOperation.copy
        : (event.session.allowedOperations.firstOrNull ?? DropOperation.none);
  }

  void _onDropLeave(DropEvent event) {
    _dispatcher.isHovering.value = false;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    _dispatcher.isHovering.value = false;
    try {
      final files = await platformFilesFromPerformDrop(event);
      if (files.isEmpty) return;
      logChat.info('desktop drop accepted count=${files.length}');
      await _dispatcher.dispatch(
        files,
        navigatorKey: widget.navigatorKey,
        locale: widget.locale,
      );
    } catch (e, st) {
      logChat.warning('desktop drop failed: $e', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: const [...Formats.standardFormats],
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: _onDropOver,
      onDropEnter: (event) {
        if (_sessionHasExternalFiles(event.session)) {
          _dispatcher.isHovering.value = true;
        }
      },
      onDropLeave: _onDropLeave,
      onDropEnded: (_) => _dispatcher.isHovering.value = false,
      onPerformDrop: _onPerformDrop,
      child: widget.child,
    );
  }
}
