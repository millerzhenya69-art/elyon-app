import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) '../stubs/window_manager_stub.dart'
    if (dart.library.js) '../stubs/window_manager_stub.dart';
import '../theme/app_theme.dart';
import 'elyon_logo.dart';

/// Кастомный titlebar для frameless-окна на Windows.
///
/// Заменяет системную рамку: даёт drag-area, свои кнопки
/// minimize / maximize / close, и логотип + название слева.
/// Используется поверх содержимого приложения внутри
/// [AppWindowShell].
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((v) {
        if (mounted) setState(() => _isMaximized = v);
      });
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final elyon = context.elyon;

    return GestureDetector(
      // Двойной клик по titlebar — максимизация (как в Windows)
      onDoubleTap: _toggleMaximize,
      // Зажать и тащить — перемещение окна
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: elyon.surfaceBg,
          border: Border(
            bottom: BorderSide(color: elyon.borderColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const SizedBox(width: 16, height: 16, child: ElyonLogo(size: 16)),
            const SizedBox(width: 8),
            Text(
              'Elyon AI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: elyon.mutedText,
              ),
            ),
            const Spacer(),
            _TitleBarButton(
              icon: Icons.remove_rounded,
              onTap: () => windowManager.minimize(),
              tooltip: 'Minimize',
            ),
            _TitleBarButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              iconSize: _isMaximized ? 13 : 14,
              onTap: _toggleMaximize,
              tooltip: _isMaximized ? 'Restore' : 'Maximize',
            ),
            _TitleBarButton(
              icon: Icons.close_rounded,
              onTap: () => windowManager.close(),
              tooltip: 'Close',
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconSize = 15,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double iconSize;
  final bool isClose;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;

    final hoverBg = widget.isClose
        ? const Color(0xFFE81123)
        : elyon.card2Bg;
    final iconColor = widget.isClose && _hover
        ? Colors.white
        : elyon.mutedText;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 46,
          height: 36,
          color: _hover ? hoverBg : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
        ),
      ),
    );
  }
}
