import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import '../widgets/offer_sheet.dart';

class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen(this.listing, {super.key});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final vsColor = l.overMarket ? AppColors.warnInk : AppColors.ok;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.bg,
                  surfaceTintColor: AppColors.bg,
                  foregroundColor: AppColors.ink,
                  elevation: 0,
                  scrolledUnderElevation: 0.5,
                  shadowColor: AppColors.line,
                  title: Text(l.crop,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.bookmark_border),
                      tooltip: 'Save',
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: _hero(l)),
                SliverToBoxAdapter(child: _body(context, l, vsColor)),
              ],
            ),
          ),
          _ActionBar(listing: l),
        ],
      ),
    );
  }

  Widget _hero(Listing l) {
    return Container(
      height: 200,
      width: double.infinity,
      color: AppColors.surface2,
      child: Stack(
        children: [
          Positioned.fill(
            child: ProduceImage(l.crop, width: double.infinity, height: 200, radius: 0),
          ),
          Positioned(
            left: Insets.s4,
            bottom: Insets.s4,
            child: Row(
              children: [
                GradeChip(l.grade),
                if (l.organic) ...[
                  const SizedBox(width: Insets.s2),
                  const Pill(
                    label: 'Organic',
                    icon: Icons.eco,
                    fg: AppColors.bg,
                    bg: AppColors.ok,
                  ),
                ],
                if (l.readyNow) ...[
                  const SizedBox(width: Insets.s2),
                  const Pill(
                    label: 'Ready now',
                    fg: AppColors.primaryPress,
                    bg: AppColors.primaryTint,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, Listing l, Color vsColor) {
    return Padding(
      padding: const EdgeInsets.all(Insets.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(inr(l.price),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 4),
              const Text('/quintal',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(l.overMarket ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 15, color: vsColor),
              const SizedBox(width: 3),
              Text(
                '${inr(l.vsMarket)} ${l.overMarket ? 'above' : 'below'} mandi (${inr(l.marketPrice)})',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: vsColor),
              ),
            ],
          ),
          const SizedBox(height: Insets.s5),
          _specs(l),
          const SizedBox(height: Insets.s5),
          _sellerCard(l.seller),
          const SizedBox(height: Insets.s5),
          _mandiContext(l),
          const SizedBox(height: Insets.s4),
          _trust(),
        ],
      ),
    );
  }

  Widget _specs(Listing l) {
    final items = [
      (Icons.scale_outlined, 'Quantity', '${_qty(l.qty)} ${l.unit.label}'),
      (Icons.workspace_premium_outlined, 'Grade', 'Grade ${l.grade.label}'),
      (
        Icons.schedule,
        'Availability',
        l.readyNow ? 'Ready now' : '${l.harvestInDays} days'
      ),
      (Icons.near_me_outlined, 'Distance', '${l.distanceKm} km · ${l.location}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.2,
      mainAxisSpacing: Insets.s3,
      crossAxisSpacing: Insets.s3,
      children: [
        for (final (icon, k, v) in items)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.s3, vertical: Insets.s2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: Insets.s2),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      Text(v,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sellerCard(Seller s) {
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.primaryTint, shape: BoxShape.circle),
            child: Text(s.name[0],
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryPress)),
          ),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(s.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    if (s.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: AppColors.ok),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 15, color: AppColors.warn),
                    Text(' ${s.rating}  ·  ${s.deals} deals  ·  ${s.village}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _mandiContext(Listing l) {
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, size: 22, color: AppColors.primary),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: "Today's mandi rate is "),
                TextSpan(
                    text: '${inr(l.marketPrice)}/qtl',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(
                    text: ' (eNAM · Kolar APMC). Negotiate with the live number in hand.'),
              ]),
              style: const TextStyle(fontSize: 13, color: AppColors.primaryPress),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trust() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user, size: 18, color: AppColors.ok),
        SizedBox(width: Insets.s2),
        Expanded(
          child: Text(
            'Your payment is held in escrow and released to the farmer only after '
            'you confirm delivery. Disputes are mediated by OpenMandi.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
        ),
      ],
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.s4,
        Insets.s3,
        Insets.s4,
        Insets.s3 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          AppButton.ghost('Chat', icon: Icons.chat_bubble_outline,
              onPressed: () {}),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: AppButton.accent(
              'Make offer',
              icon: Icons.local_offer_outlined,
              onPressed: () => OfferSheet.show(context, listing),
            ),
          ),
        ],
      ),
    );
  }
}
