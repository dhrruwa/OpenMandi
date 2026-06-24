import 'package:flutter/widgets.dart';

/// Soft, low-alpha, ink-hued elevation. Pure black looks dirty on the cream UI,
/// so shadows use the ink colour (#1C2117) at low opacity. Two layers each —
/// a tight contact shadow + a wider ambient one — for a modern, non-blobby look.
abstract final class Shadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F1C2117), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A1C2117), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x121C2117), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0F1C2117), blurRadius: 16, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x141C2117), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x141C2117), blurRadius: 32, offset: Offset(0, 16)),
  ];

  /// Upward shadow for surfaces that float above content (bottom nav).
  static const List<BoxShadow> up = [
    BoxShadow(color: Color(0x141C2117), blurRadius: 16, offset: Offset(0, -4)),
  ];

  /// Warm coloured glow for brand/accent surfaces (FAB, balance card).
  static const List<BoxShadow> accent = [
    BoxShadow(color: Color(0x33B15300), blurRadius: 20, offset: Offset(0, 6)),
  ];
}
