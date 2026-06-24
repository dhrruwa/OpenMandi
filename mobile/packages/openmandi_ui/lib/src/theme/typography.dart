import 'package:flutter/widgets.dart';
import 'colors.dart';

/// Centralised text styles so font sizes / weights / letter-spacing /
/// tabular-figures aren't repeated inline. Mirrors the AppColors/Insets/Radii
/// ergonomics — use `AppText.section`, `.price`, etc. Composes over the
/// Hanken Grotesk text theme set in AppTheme.
abstract final class AppText {
  static const display = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.05);
  static const title = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.1);
  static const section = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3);
  static const body = TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink);
  static const bodyMuted =
      TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted);
  static const label = TextStyle(fontSize: 12, color: AppColors.muted);
  static const labelStrong =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2);

  // numerics (tabular figures so prices/quantities don't jitter)
  static const price = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()]);
  static const priceLg = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      fontFeatures: [FontFeature.tabularFigures()]);
}
