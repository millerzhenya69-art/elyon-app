import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart'
    if (dart.library.js_interop) '../stubs/window_manager_stub.dart'
    if (dart.library.js) '../stubs/window_manager_stub.dart';
import 'package:hotkey_manager/hotkey_manager.dart'
    if (dart.library.js_interop) '../stubs/window_manager_stub.dart'
    if (dart.library.js) '../stubs/window_manager_stub.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) '../stubs/window_manager_stub.dart'
    if (dart.library.js) '../stubs/window_manager_stub.dart';

/// Windows-only: system tray icon, global hotkeys, and window management.
/// Call [WindowsServices.init] in main() before runApp (Windows only).
class WindowsServices with TrayListener {
  static final WindowsServices _instance = WindowsServices._();
  factory WindowsServices() => _instance;
  WindowsServices._();

  bool _visible = true;
  String _currentModelLabel = 'Elyon Core';

  // ── Init ─────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!Platform.isWindows) return;
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size:            Size(900, 680),
      minimumSize:     Size(520, 420),
      center:          true,
      title:           'Elyon AI',
      backgroundColor: Colors.transparent,
      titleBarStyle:   TitleBarStyle.hidden,
      windowButtonVisibility: false,
      skipTaskbar:     false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.show();
      await windowManager.focus();
    });

    await _instance._setupTray();
    await _instance._setupHotkeys();
  }

  // ── Tray ──────────────────────────────────────────────────────

  Future<void> _setupTray() async {
    trayManager.addListener(this);

    try {
      await trayManager.setIcon('assets/images/elyon_logo.ico');
    } catch (_) {
      // fallback — tray покажет системную иконку
    }

    await trayManager.setToolTip('Elyon AI — $_currentModelLabel');
    await _refreshTrayMenu();
  }

  /// Стилизованное меню трея под фирменный стиль приложения:
  /// эмодзи-иконки для каждого пункта + текущая модель в заголовке +
  /// горячие клавиши указаны рядом с действиями.
  Future<void> _refreshTrayMenu() async {
    await trayManager.setContextMenu(Menu(items: [
      // Заголовок — текущая активная модель, неактивный пункт
      MenuItem(
        label:    '✦  $_currentModelLabel',
        disabled: true,
      ),
      MenuItem.separator(),

      MenuItem(
        key:   'show',
        label: '◎  Show Elyon',
      ),

      MenuItem.separator(),

      MenuItem(
        key:   'new',
        label: '✎  New chat            Win+Shift+N',
      ),
      MenuItem(
        key:   'copy_last',
        label: '⧉  Copy last reply     Win+Shift+C',
      ),

      MenuItem.separator(),

      MenuItem(
        key:   'settings',
        label: '⚙  Settings            Win+Shift+S',
      ),

      MenuItem.separator(),

      MenuItem(
        key:   'quit',
        label: '✕  Quit Elyon AI',
      ),
    ]));
  }

  /// Call when the active subscription tier / model changes so the tray
  /// tooltip and header reflect it (e.g. "Elyon Nova", "Elyon Absolution").
  Future<void> updateModelLabel(String label) async {
    if (_currentModelLabel == label) return;
    _currentModelLabel = label;
    await trayManager.setToolTip('Elyon AI — $_currentModelLabel');
    await _refreshTrayMenu();
  }

  // ── Tray events ──────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => _toggleWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await _showWindow();

      case 'new':
        await _showWindow();
        _onNewChatHotkey?.call();

      case 'copy_last':
        _onCopyLastHotkey?.call();

      case 'settings':
        await _showWindow();
        _onSettingsHotkey?.call();

      case 'quit':
        await trayManager.destroy();
        await hotKeyManager.unregisterAll();
        exit(0);
    }
  }

  // ── Hotkeys ──────────────────────────────────────────────────

  VoidCallback? _onNewChatHotkey;
  VoidCallback? _onFocusHotkey;
  VoidCallback? _onCopyLastHotkey;
  VoidCallback? _onSettingsHotkey;

  void setCallbacks({
    VoidCallback? onNewChat,
    VoidCallback? onFocus,
    VoidCallback? onCopyLast,
    VoidCallback? onSettings,
  }) {
    _onNewChatHotkey   = onNewChat;
    _onFocusHotkey     = onFocus;
    _onCopyLastHotkey  = onCopyLast;
    _onSettingsHotkey  = onSettings;
  }

  Future<void> _setupHotkeys() async {
    await hotKeyManager.unregisterAll();

    await hotKeyManager.register(
      HotKey(
        key:       PhysicalKeyboardKey.keyE,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope:     HotKeyScope.system,
      ),
      keyDownHandler: (_) async {
        await _showWindow();
        _onFocusHotkey?.call();
      },
    );

    await hotKeyManager.register(
      HotKey(
        key:       PhysicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope:     HotKeyScope.system,
      ),
      keyDownHandler: (_) async {
        await _showWindow();
        _onNewChatHotkey?.call();
      },
    );

    await hotKeyManager.register(
      HotKey(
        key:       PhysicalKeyboardKey.keyC,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope:     HotKeyScope.system,
      ),
      keyDownHandler: (_) async {
        _onCopyLastHotkey?.call();
      },
    );

    await hotKeyManager.register(
      HotKey(
        key:       PhysicalKeyboardKey.keyS,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope:     HotKeyScope.system,
      ),
      keyDownHandler: (_) async {
        await _showWindow();
        _onSettingsHotkey?.call();
      },
    );
  }

  // ── Window helpers ────────────────────────────────────────────

  Future<void> _toggleWindow() async {
    if (_visible) {
      await windowManager.hide();
      _visible = false;
    } else {
      await _showWindow();
    }
  }

  Future<void> _showWindow() async {
    _visible = true;
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.focus();
  }

  /// Wire this to the window's close button via WindowListener.
  Future<bool> onWindowClose() async {
    await windowManager.hide();
    _visible = false;
    return false;
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
