// Stub for window_manager, tray_manager, hotkey_manager on non-desktop platforms.
// Real packages loaded only on desktop via conditional imports.

// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── WindowListener ────────────────────────────────────────────────
mixin WindowListener {
  void onWindowClose() {}
  void onWindowMaximize() {}
  void onWindowUnmaximize() {}
  void onWindowMinimize() {}
  void onWindowRestore() {}
  void onWindowResize() {}
  void onWindowMove() {}
  void onWindowFocus() {}
  void onWindowBlur() {}
}

// ── window_manager stub ───────────────────────────────────────────
class _WindowManagerStub {
  Future<void> ensureInitialized() async {}
  Future<void> waitUntilReadyToShow(dynamic options, Future<void> Function() callback) async {}
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> focus() async {}
  Future<void> minimize() async {}
  Future<void> maximize() async {}
  Future<void> unmaximize() async {}
  Future<void> restore() async {}
  Future<void> close() async {}
  Future<void> setAsFrameless() async {}
  Future<void> setPreventClose(bool value) async {}
  Future<void> startDragging() async {}
  Future<bool> isVisible() async => true;
  Future<bool> isMinimized() async => false;
  Future<bool> isMaximized() async => false;
  Future<void> setSize(Size size) async {}
  Future<void> setMinimumSize(Size size) async {}
  Future<void> setTitle(String title) async {}
  void addListener(WindowListener listener) {}
  void removeListener(WindowListener listener) {}
}

final windowManager = _WindowManagerStub();

class WindowOptions {
  const WindowOptions({
    this.size,
    this.minimumSize,
    this.center,
    this.title,
    this.backgroundColor,
    this.titleBarStyle,
    this.windowButtonVisibility,
    this.skipTaskbar,
  });
  final Size? size;
  final Size? minimumSize;
  final bool? center;
  final String? title;
  final Color? backgroundColor;
  final dynamic titleBarStyle;
  final bool? windowButtonVisibility;
  final bool? skipTaskbar;
}

class TitleBarStyle {
  static const hidden = 'hidden';
  static const normal = 'normal';
}

// ── tray_manager stub ─────────────────────────────────────────────
mixin TrayListener {
  void onTrayIconMouseDown() {}
  void onTrayIconRightMouseDown() {}
  void onTrayMenuItemClick(MenuItem menuItem) {}
}

class MenuItem {
  final String? key;
  final String? label;
  final bool disabled;

  const MenuItem({this.key, this.label, this.disabled = false});
  static MenuItem separator() => const MenuItem(label: '-');
}

class Menu {
  final List<MenuItem> items;
  const Menu({required this.items});
}

class _TrayManagerStub {
  void addListener(TrayListener listener) {}
  void removeListener(TrayListener listener) {}
  Future<void> setIcon(String path) async {}
  Future<void> setToolTip(String tip) async {}
  Future<void> setContextMenu(Menu menu) async {}
  Future<void> popUpContextMenu() async {}
  Future<void> destroy() async {}
}

final trayManager = _TrayManagerStub();

// ── hotkey_manager stub ───────────────────────────────────────────
enum HotKeyModifier { meta, shift, alt, control }
enum HotKeyScope { system, inapp }

class HotKey {
  final PhysicalKeyboardKey key;
  final List<HotKeyModifier> modifiers;
  final HotKeyScope scope;
  const HotKey({required this.key, required this.modifiers, required this.scope});
}

class _HotKeyManagerStub {
  Future<void> unregisterAll() async {}
  Future<void> register(HotKey hotKey, {Function? keyDownHandler}) async {}
  Future<void> unregister(HotKey hotKey) async {}
}

final hotKeyManager = _HotKeyManagerStub();
