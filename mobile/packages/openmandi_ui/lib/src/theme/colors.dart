import 'package:flutter/widgets.dart';

/// OpenMandi palette. Authored in OKLCH (see DESIGN.md) and converted to sRGB.
/// Grounded farm-market daylight: deep olive primary, terracotta accent.
abstract final class AppColors {
  // surfaces
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF6F8F3);
  static const surface2 = Color(0xFFEFF1EB);
  static const line = Color(0xFFDFE0DB);
  static const lineStrong = Color(0xFFCDCFC8);

  // text
  static const ink = Color(0xFF1C2117);
  static const muted = Color(0xFF60655B);

  // brand: olive
  static const primary = Color(0xFF516009);
  static const primaryPress = Color(0xFF414F00);
  static const primaryTint = Color(0xFFEEF3E2);
  static const onPrimary = Color(0xFFFBFCF9);

  // accent: terracotta (money / offers)
  static const accent = Color(0xFFC56211);
  static const accentPress = Color(0xFFB15300);
  static const accentTint = Color(0xFFFFEBDF);
  static const onAccent = Color(0xFFFFFBF8);

  // status (always paired with icon + label)
  static const ok = Color(0xFF287C42);
  static const okTint = Color(0xFFE3F6E6);
  static const warn = Color(0xFFA97416);
  static const warnInk = Color(0xFF8A5700);
  static const warnTint = Color(0xFFFEF0D4);
  static const danger = Color(0xFFBE3029);
  static const dangerTint = Color(0xFFFFEBE7);
}
