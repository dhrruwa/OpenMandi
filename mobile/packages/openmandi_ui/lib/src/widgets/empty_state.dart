import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'reveal.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Reveal(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.s8, Insets.s10, Insets.s8, Insets.s10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Medallion(icon: icon),
              const SizedBox(height: Insets.s5),
              Text(title, textAlign: TextAlign.center, style: AppText.section),
              const SizedBox(height: 6),
              Text(body, textAlign: TextAlign.center, style: AppText.bodyMuted),
              if (action != null) ...[
                const SizedBox(height: Insets.s5),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A composed "medallion": a soft-shadowed tinted disc with a faint concentric
/// ring and a small floating accent dot — friendlier than a flat icon circle.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // faint outer ring
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTint.withValues(alpha: 0.45),
            ),
          ),
          // main disc
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTint,
              boxShadow: Shadows.sm,
            ),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          // floating accent dot
          Positioned(
            top: 8,
            right: 10,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentTint,
                boxShadow: Shadows.sm,
              ),
              child: const Icon(Icons.add, size: 12, color: AppColors.accentPress),
            ),
          ),
        ],
      ),
    );
  }
}
