import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/spacing.dart';
import 'tappable.dart';

/// The standard elevated surface. Replaces the repeated
/// `Container(decoration: border + radius)` pattern across the app so every
/// card gets consistent depth + a hairline border for definition.
///
/// - Elevated (`Shadows.sm`) by default; pass `flat: true` for nested/quiet
///   contexts (never stack two elevated cards).
/// - `onTap` adds the shared press-scale feedback via [Tappable].
/// - `clip: true` clips children to the rounded corners (for edge-to-edge images).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Insets.s3),
    this.radius = Radii.md,
    this.color = AppColors.bg,
    this.shadow,
    this.flat = false,
    this.border = true,
    this.clip = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final List<BoxShadow>? shadow;
  final bool flat;
  final bool border;
  final bool clip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: AppColors.line) : null,
        boxShadow: flat ? null : (shadow ?? Shadows.sm),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Tappable(onTap: onTap, semanticLabel: semanticLabel, child: card);
  }
}
