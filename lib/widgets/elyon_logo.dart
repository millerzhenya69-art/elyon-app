import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Универсальный виджет логотипа Elyon.
///
/// Показывает `assets/images/elyon_logo.png` без фона.
/// На светлой теме автоматически применяет ColorFilter чтобы
/// белый логотип был виден на светлом фоне (фикс 2).
/// Если файл не найден — fallback с «E» в круглом контейнере (фикс 2).
class ElyonLogo extends StatelessWidget {
  const ElyonLogo({
    super.key,
    this.size = 28,
    this.spin = false,
    this.controller,
  });

  final double size;
  final bool spin;
  final AnimationController? controller;

  @override
  Widget build(BuildContext context) {
    // Фикс 2: на светлой теме логотип белый — делаем его тёмным
    final isLight = Theme.of(context).brightness == Brightness.light;

    Widget logo = Image.asset(
      'assets/images/elyon_logo.png',
      width:  size,
      height: size,
      fit:    BoxFit.contain,
      errorBuilder: (_, __, ___) => _FallbackE(size: size),
    );

    // Для светлой темы накладываем ColorFilter — инвертируем цвет
    if (isLight) {
      logo = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0,  0, 255,
           0, -1,  0,  0, 255,
           0,  0, -1,  0, 255,
           0,  0,  0,  1,   0,
        ]),
        child: logo,
      );
    }

    if (spin && controller != null) {
      return RotationTransition(turns: controller!, child: logo);
    }
    return logo;
  }
}

// ── Fallback когда PNG не найден ──────────────────────────────────
// Фикс 2: круглый контейнер вместо квадратного

class _FallbackE extends StatelessWidget {
  const _FallbackE({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color:  AppColors.beige.withOpacity(0.10),
        shape:  BoxShape.circle,   // круг, не квадрат
        border: Border.all(color: AppColors.beige.withOpacity(0.18)),
      ),
      child: Center(
        child: Text(
          'E',
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize:   size * 0.57,
            color:      AppColors.beige,
          ),
        ),
      ),
    );
  }
}
