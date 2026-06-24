import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography tokens — mirrors the web's --serif / --sans font stack
abstract class AppTextStyles {
  // ── Serif (headings, logo, welcome title) ──────────────────────
  static const String _serif = 'InstrumentSerif';
  static const String _sans  = 'DMSans';

  // Welcome / hero heading: "Hello, I am Elyon"
  static TextStyle heroTitle({
    double fontSize = 40,
    Color color = AppColors.white,
  }) =>
      TextStyle(
        fontFamily: _serif,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1.15,
        color: color,
      );

  // Italic highlight inside hero title
  static TextStyle heroTitleItalic({
    double fontSize = 40,
    Color color = AppColors.beige,
  }) =>
      TextStyle(
        fontFamily: _serif,
        fontSize: fontSize,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        height: 1.15,
        color: color,
      );

  // Panel / screen title ("Settings", "Pricing", etc.)
  static TextStyle panelTitle({Color color = AppColors.white}) =>
      TextStyle(
        fontFamily: _serif,
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Pricing card name
  static TextStyle pricingName({Color color = AppColors.white}) =>
      TextStyle(
        fontFamily: _serif,
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Nav brand logo text
  static const TextStyle brandLogo = TextStyle(
    fontFamily: _serif,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.white,
  );

  // ── Sans — body / UI ────────────────────────────────────────────

  // Chat message body
  static TextStyle messageBody({
    double fontSize = 14,
    Color color = AppColors.white,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: _sans,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.75,
        color: color,
      );

  // Input textarea
  static const TextStyle inputText = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.white,
  );

  // Muted label / timestamp
  static TextStyle muted({double fontSize = 13}) => TextStyle(
        fontFamily: _sans,
        fontSize: fontSize,
        fontWeight: FontWeight.w300,
        color: AppColors.muted,
      );

  // Section label (UPPERCASE, letter-spaced)
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: _sans,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
    color: AppColors.muted,
  );

  // Chip / button label
  static const TextStyle chipLabel = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  // Model selector
  static const TextStyle modelSelect = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.beige2,
  );

  // Settings row
  static const TextStyle settingsRow = TextStyle(
    fontFamily: _sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.white,
  );

  // Pricing price large
  static const TextStyle pricingPrice = TextStyle(
    fontFamily: _sans,
    fontSize: 28,
    fontWeight: FontWeight.w300,
    color: AppColors.white,
  );
}
