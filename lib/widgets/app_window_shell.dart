import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'custom_titlebar.dart';

/// Оборачивает экран приложения скруглённым углами окном
/// и кастомным titlebar (только на Windows, при frameless-окне).
///
/// На других платформах просто возвращает [child] без изменений.
///
/// Использование — в каждом top-level экране (AuthScreen, MainScreen):
///   return AppWindowShell(child: Scaffold(...));
class AppWindowShell extends StatelessWidget {
  const AppWindowShell({super.key, required this.child});
  final Widget child;

  static const double cornerRadius = 10;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return child;

    final elyon = context.elyon;

    // Прозрачный фон самого native-окна (см. WindowOptions в
    // windows_services.dart: backgroundColor: Colors.transparent,
    // titleBarStyle: TitleBarStyle.hidden) + скруглённый контейнер
    // с реальным фоном приложения внутри даёт эффект округлённых углов.
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: Container(
          decoration: BoxDecoration(
            color: elyon.scaffoldBg,
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(color: elyon.borderColor, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const CustomTitleBar(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
