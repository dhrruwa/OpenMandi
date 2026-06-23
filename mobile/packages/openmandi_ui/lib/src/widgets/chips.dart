import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Generic status pill: always icon + label + colour (never colour alone — a11y).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
  });

  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 9 : 7, 3, 9, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.listing, {super.key});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return switch (listing.status) {
      ListingStatus.sold => const Pill(
          label: 'Sold',
          icon: Icons.check_circle_outline,
          fg: AppColors.muted,
          bg: AppColors.surface2),
      ListingStatus.offers => Pill(
          label: '${listing.offers} offers',
          icon: Icons.local_offer_outlined,
          fg: AppColors.accentPress,
          bg: AppColors.accentTint),
      ListingStatus.live => const Pill(
          label: 'Live',
          icon: Icons.circle,
          fg: AppColors.ok,
          bg: AppColors.okTint),
    };
  }
}

class GradeChip extends StatelessWidget {
  const GradeChip(this.grade, {super.key});
  final Grade grade;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (grade) {
      Grade.a => (AppColors.ok, AppColors.okTint),
      Grade.b => (AppColors.warnInk, AppColors.warnTint),
      Grade.c => (AppColors.muted, AppColors.surface2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        'Grade ${grade.label}',
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
