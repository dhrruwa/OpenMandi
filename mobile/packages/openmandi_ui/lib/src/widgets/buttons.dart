import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'tappable.dart';

enum _Kind { primary, accent, ghost }

/// The three OpenMandi button roles. 52px tall, ≥44px tap target, press-scale.
class AppButton extends StatelessWidget {
  const AppButton.primary(this.label,
      {super.key, this.onPressed, this.icon, this.expand = true})
      : _kind = _Kind.primary;
  const AppButton.accent(this.label,
      {super.key, this.onPressed, this.icon, this.expand = true})
      : _kind = _Kind.accent;
  const AppButton.ghost(this.label,
      {super.key, this.onPressed, this.icon, this.expand = false})
      : _kind = _Kind.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final (bg, fg, border) = switch (_kind) {
      _Kind.primary => (AppColors.primary, AppColors.onPrimary, null),
      _Kind.accent => (AppColors.accent, AppColors.onAccent, null),
      _Kind.ghost => (AppColors.surface, AppColors.ink, AppColors.line),
    };

    final child = Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: expand ? 0 : Insets.s5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: Insets.s2),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final opacity = Opacity(opacity: disabled ? 0.45 : 1, child: child);
    final tappable = Tappable(
      onTap: disabled ? null : onPressed,
      semanticLabel: label,
      child: opacity,
    );
    return expand ? SizedBox(width: double.infinity, child: tappable) : tappable;
  }
}
