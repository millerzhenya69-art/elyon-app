import 'package:flutter/material.dart';
import 'app_colors.dart';

/// App theme variants matching the web UI themes:
/// dark (default), amoled, light
enum AppThemeMode { dark, amoled, light }

abstract class AppTheme {
  static const double radius    = 14.0;
  static const double navHeight = 52.0;

  // ── Dark theme (default) ─────────────────────────────────────
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scaffoldBg:    AppColors.black,
        surfaceBg:     AppColors.off,
        cardBg:        AppColors.card,
        card2Bg:       AppColors.card2,
        borderColor:   AppColors.border,
        border2Color:  AppColors.border2,
        primaryText:   AppColors.white,
        mutedText:     AppColors.muted,
        accentColor:   AppColors.beige,
        accent2Color:  AppColors.beige2,
      );

  // ── AMOLED theme ─────────────────────────────────────────────
  static ThemeData amoled() => _build(
        brightness: Brightness.dark,
        scaffoldBg:    AppColors.amoledBlack,
        surfaceBg:     AppColors.amoledOff,
        cardBg:        AppColors.amoledCard,
        card2Bg:       AppColors.amoledCard2,
        borderColor:   AppColors.border,
        border2Color:  AppColors.border2,
        primaryText:   AppColors.white,
        mutedText:     AppColors.muted,
        accentColor:   AppColors.beige,
        accent2Color:  AppColors.beige2,
      );

  // ── Light theme ──────────────────────────────────────────────
  static ThemeData light() => _build(
        brightness: Brightness.light,
        scaffoldBg:    AppColors.lightBg,
        surfaceBg:     AppColors.lightSurface,
        cardBg:        AppColors.lightCard,
        card2Bg:       AppColors.lightCard2,
        borderColor:   AppColors.lightBorder,
        border2Color:  AppColors.lightBorder,
        primaryText:   AppColors.lightText,
        mutedText:     AppColors.lightMuted,
        accentColor:   AppColors.beige2,
        accent2Color:  AppColors.beige2,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffoldBg,
    required Color surfaceBg,
    required Color cardBg,
    required Color card2Bg,
    required Color borderColor,
    required Color border2Color,
    required Color primaryText,
    required Color mutedText,
    required Color accentColor,
    required Color accent2Color,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary:          accentColor,
        onPrimary:        AppColors.black,
        secondary:        accent2Color,
        onSecondary:      AppColors.black,
        error:            AppColors.danger,
        onError:          AppColors.white,
        surface:          surfaceBg,
        onSurface:        primaryText,
      ),
      // Remove default splash effects — we add our own
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      // Card
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor),
        ),
      ),
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border2Color),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border2Color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accentColor.withOpacity(0.28)),
        ),
        hintStyle: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          color: primaryText.withOpacity(0.28),
        ),
      ),
      // Divider
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 0,
      ),
      // Scroll
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(4),
        radius: Radius.circular(2),
      ),

      // Store extra colors in extensions so widgets can access them
      extensions: [
        ElyonColors(
          scaffoldBg:   scaffoldBg,
          surfaceBg:    surfaceBg,
          cardBg:       cardBg,
          card2Bg:      card2Bg,
          borderColor:  borderColor,
          border2Color: border2Color,
          primaryText:  primaryText,
          mutedText:    mutedText,
          accentColor:  accentColor,
          accent2Color: accent2Color,
        ),
      ],
    );
  }
}

/// Custom ThemeExtension so any widget can do:
///   context.elyon.accentColor  etc.
@immutable
class ElyonColors extends ThemeExtension<ElyonColors> {
  const ElyonColors({
    required this.scaffoldBg,
    required this.surfaceBg,
    required this.cardBg,
    required this.card2Bg,
    required this.borderColor,
    required this.border2Color,
    required this.primaryText,
    required this.mutedText,
    required this.accentColor,
    required this.accent2Color,
  });

  final Color scaffoldBg;
  final Color surfaceBg;
  final Color cardBg;
  final Color card2Bg;
  final Color borderColor;
  final Color border2Color;
  final Color primaryText;
  final Color mutedText;
  final Color accentColor;
  final Color accent2Color;

  @override
  ElyonColors copyWith({
    Color? scaffoldBg, Color? surfaceBg, Color? cardBg, Color? card2Bg,
    Color? borderColor, Color? border2Color, Color? primaryText,
    Color? mutedText, Color? accentColor, Color? accent2Color,
  }) =>
      ElyonColors(
        scaffoldBg:   scaffoldBg   ?? this.scaffoldBg,
        surfaceBg:    surfaceBg    ?? this.surfaceBg,
        cardBg:       cardBg       ?? this.cardBg,
        card2Bg:      card2Bg      ?? this.card2Bg,
        borderColor:  borderColor  ?? this.borderColor,
        border2Color: border2Color ?? this.border2Color,
        primaryText:  primaryText  ?? this.primaryText,
        mutedText:    mutedText    ?? this.mutedText,
        accentColor:  accentColor  ?? this.accentColor,
        accent2Color: accent2Color ?? this.accent2Color,
      );

  @override
  ElyonColors lerp(ElyonColors? other, double t) {
    if (other is! ElyonColors) return this;
    return ElyonColors(
      scaffoldBg:   Color.lerp(scaffoldBg,   other.scaffoldBg,   t)!,
      surfaceBg:    Color.lerp(surfaceBg,     other.surfaceBg,    t)!,
      cardBg:       Color.lerp(cardBg,        other.cardBg,       t)!,
      card2Bg:      Color.lerp(card2Bg,       other.card2Bg,      t)!,
      borderColor:  Color.lerp(borderColor,   other.borderColor,  t)!,
      border2Color: Color.lerp(border2Color,  other.border2Color, t)!,
      primaryText:  Color.lerp(primaryText,   other.primaryText,  t)!,
      mutedText:    Color.lerp(mutedText,      other.mutedText,    t)!,
      accentColor:  Color.lerp(accentColor,   other.accentColor,  t)!,
      accent2Color: Color.lerp(accent2Color,  other.accent2Color, t)!,
    );
  }
}

/// Convenient extension on BuildContext
extension ElyonThemeX on BuildContext {
  ElyonColors get elyon =>
      Theme.of(this).extension<ElyonColors>()!;
}
