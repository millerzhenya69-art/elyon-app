import 'package:flutter/material.dart';

/// Elyon AI Design Tokens
/// Directly mirrors the CSS variables in app.html:
///   --black, --off, --card, --card2, --border, --beige, --white, --muted
abstract class AppColors {
  // ── Core palette (Dark / default) ──────────────────────────────
  static const Color black   = Color(0xFF0E0E0E);
  static const Color off     = Color(0xFF181818);
  static const Color card    = Color(0xFF202020);
  static const Color card2   = Color(0xFF252525);

  static const Color beige   = Color(0xFFE8DDD0);
  static const Color beige2  = Color(0xFFC9BFB3);
  static const Color white   = Color(0xFFF8F5F0);

  // Semi-transparent values
  static const Color border  = Color(0x12FFFFFF);   // rgba(255,255,255,0.07)
  static const Color border2 = Color(0x1FFFFFFF);   // rgba(255,255,255,0.12)
  static const Color muted   = Color(0x66F8F5F0);   // rgba(248,245,240,0.4)

  // AI avatar background
  static const Color aiAvatarBg     = Color(0x14E8DDD0); // rgba(232,221,208,0.08)
  static const Color aiAvatarBorder = Color(0x1FE8DDD0); // rgba(232,221,208,0.12)

  // ── AMOLED palette ─────────────────────────────────────────────
  static const Color amoledBlack  = Color(0xFF000000);
  static const Color amoledOff    = Color(0xFF0A0A0A);
  static const Color amoledCard   = Color(0xFF111111);
  static const Color amoledCard2  = Color(0xFF161616);

  // ── Light palette ───────────────────────────────────────────────
  static const Color lightBg      = Color(0xFFF5F2EE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard    = Color(0xFFF0EDE8);
  static const Color lightCard2   = Color(0xFFE8E4DF);
  static const Color lightText    = Color(0xFF1A1714);
  static const Color lightMuted   = Color(0xFF8C8581);
  static const Color lightBorder  = Color(0xFFDDD8D2);

  // ── Accent ──────────────────────────────────────────────────────
  static const Color danger = Color(0xFFE07070);

  // ── Gradients ───────────────────────────────────────────────────
  static const LinearGradient beigeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [beige2, beige],
  );

  static const LinearGradient topLineGradient = LinearGradient(
    colors: [beige2, beige],
  );
}
