import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'window_state_store.dart';

const _kDesktopLifecycleChannel = MethodChannel(
  'dev.ultrasend/desktop_lifecycle',
);

bool get desktopTraySupported => Platform.isWindows || Platform.isMacOS;

final _DesktopWindowListener _windowListener = _DesktopWindowListener();
final _TrayShowListener _trayShowListener = _TrayShowListener();
bool _trayInitialized = false;

class _DesktopWindowListener with WindowListener {
  @override
  void onWindowClose() {
    Future<void>(() async {
      if (Platform.isWindows) {
        await windowManager.setSkipTaskbar(true);
      }
      await windowManager.hide();
    });
  }

  @override
  void onWindowMinimize() {
    // Keep normal Windows minimize semantics: the taskbar button should remain.
  }

  @override
  void onWindowMoved() => _saveWindowState();

  @override
  void onWindowResized() => _saveWindowState();

  void _saveWindowState() async {
    final pos = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await WindowStateStore.save(
      Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
    );
  }
}

class _TrayShowListener with TrayListener {
  @override
  void onTrayIconMouseUp() {
    bringMainWindowToFront();
  }

  @override
  void onTrayIconRightMouseUp() {
    if (Platform.isMacOS) {
      trayManager.popUpContextMenu();
    }
  }
}

Future<void> bringMainWindowToFront() async {
  if (!desktopTraySupported) return;
  if (Platform.isWindows) {
    await windowManager.setSkipTaskbar(false);
  }
  if (await windowManager.isMinimized()) {
    await windowManager.restore();
  }
  await windowManager.show();
  await windowManager.focus();
}

/// 在 [runApp] 之前调用：窗口管理、拦截关闭、与原生「唤起」通道。
Future<void> initDesktopWindowBeforeRunApp({bool startHidden = false}) async {
  if (!desktopTraySupported) return;

  _kDesktopLifecycleChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'bringToFront':
        await bringMainWindowToFront();
    }
  });

  await windowManager.ensureInitialized();
  windowManager.addListener(_windowListener);
  await windowManager.setPreventClose(true);

  final savedBounds = await WindowStateStore.load();

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: savedBounds != null
          ? Size(savedBounds.width, savedBounds.height)
          : const Size(1280, 720),
      center: savedBounds == null,
      title: 'ShrimpSend',
      skipTaskbar: startHidden && Platform.isWindows,
    ),
    () async {
      if (savedBounds != null) {
        await windowManager.setPosition(
          Offset(savedBounds.left, savedBounds.top),
        );
      }
      if (startHidden) {
        if (Platform.isWindows) {
          await windowManager.setSkipTaskbar(true);
        }
        await windowManager.hide();
        return;
      }
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

/// 在首帧之后调用（[tray_manager] 需要 binding）。
Future<void> initDesktopTrayAfterFirstFrame() async {
  if (!desktopTraySupported || _trayInitialized) return;
  _trayInitialized = true;

  final String trayIconAsset;
  if (Platform.isMacOS) {
    trayIconAsset = 'assets/tray_icon_mac.png';
  } else if (Platform.isWindows) {
    trayIconAsset = 'assets/tray_icon_windows.ico';
  } else {
    trayIconAsset = 'assets/logo.png';
  }
  await trayManager.setIcon(trayIconAsset, isTemplate: false);
  await trayManager.setToolTip('ShrimpSend');
  trayManager.addListener(_trayShowListener);

  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '显示主窗口',
          onClick: (_) {
            bringMainWindowToFront();
          },
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: '退出',
          onClick: (_) async {
            await trayManager.destroy();
            exit(0);
          },
        ),
      ],
    ),
  );
}
