import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'chips.dart';
import 'money.dart';
import 'produce_image.dart';
import 'tappable.dart';

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
    final vsColor = l.overMarket ? AppColors.ok : AppColors.accentPress;

    return Tappable(
      onTap: onTap,
      semanticLabel:
          '${l.crop}, ${l.qty} ${l.unit.label}, grade ${l.grade.label}, ${inr(l.price)} per quintal',
      child: Container(
        padding: const EdgeInsets.all(Insets.s3),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProduceImage(l.crop, imageUrl: l.photoUrl, size: 74, organic: l.organic),
            const SizedBox(width: Insets.s3),
            Expanded(child: _body(vsColor)),
            const SizedBox(width: Insets.s2),
            _trailing(),
          ],
        ),
      ),
    );
  }

  Widget _body(Color vsColor) {
    final l = listing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                l.crop,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: Insets.s2),
            Text('${_qty(l.qty)} ${l.unit.label}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(width: Insets.s2),
            GradeChip(l.grade),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(inr(l.price),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
            const SizedBox(width: 3),
            const Text('/qtl',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(width: Insets.s2),
            Flexible(
              child: Text(
                '${l.overMarket ? '▲' : '▼'} ${inr(l.vsMarket)} vs mandi',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: vsColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        showSeller ? _sellerMeta() : _ownMeta(),
      ],
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
        const SizedBox(width: Insets.s3),
        Flexible(child: _meta(Icons.place_outlined, l.location)),
      ],
    );
  }

  Widget _sellerMeta() {
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
        const Icon(Icons.star_rounded, size: 14, color: AppColors.warn),
        Text(' ${s.rating}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(width: Insets.s3),
        _meta(Icons.near_me_outlined, '${listing.distanceKm} km'),
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

  Widget _trailing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        trailing ?? StatusPill(listing),
        const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
      ],
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}
