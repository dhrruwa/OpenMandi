import 'package:flutter/material.dart';
import '../backend/config.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../store/app_store.dart';
import 'app_card.dart';
import 'chips.dart';
import 'money.dart';
import 'produce_image.dart';

/// Listing card used by both apps. [showSeller] swaps the farmer-side meta
/// (views / harvest / location) for dealer-side meta (seller, rating, distance).
class ListingCard extends StatelessWidget {
  const ListingCard(
    this.listing, {
    super.key,
    this.onTap,
    this.showSeller = false,
    this.trailing,
  });

  final Listing listing;
  final VoidCallback? onTap;
  final bool showSeller;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = listing;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      clip: true,
      semanticLabel:
          '${l.crop}, ${l.qty} ${l.unit.label}, grade ${l.grade.label}, ${inr(l.price)} per quintal',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 104,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ProduceImage(l.crop,
                        imageUrl: l.photoUrl,
                        width: 104,
                        height: double.infinity,
                        radius: 0,
                        organic: l.organic),
                  ),
                  Positioned(
                    top: Insets.s2,
                    left: Insets.s2,
                    child: trailing ?? StatusPill(listing),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.s3, Insets.s3, Insets.s3, Insets.s3),
                child: _body(context),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: Insets.s2),
              child: Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l = listing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(l.crop,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.section),
            ),
            const SizedBox(width: Insets.s2),
            GradeChip(l.grade),
          ],
        ),
        const SizedBox(height: 2),
        Text('${_qty(l.qty)} ${l.unit.label}', style: AppText.label),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(inr(l.price), style: AppText.price.copyWith(fontSize: 19)),
            const SizedBox(width: 3),
            const Text('/qtl', style: AppText.label),
            const SizedBox(width: Insets.s2),
            Flexible(child: _vsMandiPill()),
          ],
        ),
        const SizedBox(height: Insets.s2),
        showSeller ? _sellerMeta(context) : _ownMeta(),
      ],
    );
  }

  Widget _vsMandiPill() {
    final l = listing;
    final up = l.overMarket;
    final fg = up ? AppColors.ok : AppColors.accentPress;
    final bg = up ? AppColors.okTint : AppColors.accentTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: fg),
          const SizedBox(width: 2),
          Flexible(
            child: Text('${inr(l.vsMarket)} vs mandi',
                overflow: TextOverflow.ellipsis,
                style: AppText.labelStrong.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }

  Widget _ownMeta() {
    final l = listing;
    return Row(
      children: [
        if (l.readyNow)
          const Pill(
              label: 'Ready now',
              fg: AppColors.primaryPress,
              bg: AppColors.primaryTint)
        else
          _meta(Icons.schedule, '${l.harvestInDays}d to harvest'),
        const SizedBox(width: Insets.s3),
        _meta(Icons.visibility_outlined, '${l.views}'),
        if (l.location.trim().isNotEmpty) ...[
          const SizedBox(width: Insets.s3),
          Flexible(child: _meta(Icons.place_outlined, l.location)),
        ],
      ],
    );
  }

  Widget _sellerMeta(BuildContext context) {
    final s = listing.seller;
    return Row(
      children: [
        if (s.verified) ...[
          const Icon(Icons.verified, size: 14, color: AppColors.ok),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            s.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ),
        const SizedBox(width: Insets.s2),
        if (s.deals > 0) ...[
          const Icon(Icons.star_rounded, size: 14, color: AppColors.warn),
          Text(' ${s.rating}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ] else
          const Text('New',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        if (AppConfig.locationEnabled) ...[
          const SizedBox(width: Insets.s3),
          _meta(Icons.near_me_outlined,
              '${listing.distanceKm} km ${context.store.getTranslated('distance_away')}'),
        ],
      ],
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 3),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
      ],
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}
