import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/elyon_logo.dart';

/// Анимация запуска приложения — вдохновлена `.logo-orbit` из index.html:
///   - логотип в центре
///   - вращающееся кольцо-орбита с точкой
///   - заголовок "Elyon" появляется снизу
///
/// Показывается ~1.6s, затем вызывает [onFinished] для перехода
/// на AuthScreen / MainScreen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbitCtrl;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Минимальная длительность сплэша — даём анимациям отыграть
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Orbit ring + logo ──
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Вращающееся кольцо с точкой (как .orbit-ring/.orbit-dot)
                  AnimatedBuilder(
                    animation: _orbitCtrl,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _orbitCtrl.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(140, 140),
                          painter: _OrbitPainter(),
                        ),
                      );
                    },
                  ),
                  // Логотип в центре
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: ElyonLogo(size: 72),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 50.ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.easeOutCubic,
                ),

            const SizedBox(height: 36),

            // ── "Elyon" title ──
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'Elyon',
                  style: AppTextStyles.heroTitle(fontSize: 32)
                      .copyWith(color: AppColors.white),
                ),
              ]),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 250.ms)
                .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 250.ms,
                    curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}

/// Рисует тонкое кольцо-орбиту с одной точкой сверху —
/// зеркалит `.orbit-ring { border: 1px solid rgba(232,221,208,0.18) }`
/// и `.orbit-dot` из index.html.
class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Кольцо
    final ringPaint = Paint()
      ..color = AppColors.beige.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 0.5, ringPaint);

    // Точка на верхней точке кольца
    final dotPaint = Paint()
      ..color = AppColors.beige
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - radius), 3, dotPaint);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => false;
}
