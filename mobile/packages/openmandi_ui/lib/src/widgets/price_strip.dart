import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'money.dart';
import 'produce_image.dart';

/// Horizontally scrolling live mandi prices (eNAM / Agmarknet). Each card
/// shows a real crop photo, name, price and the day's change.
class PriceStrip extends StatelessWidget {
  const PriceStrip({super.key, this.prices = Mock.prices});
  final List<MarketPrice> prices;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
        physics: const BouncingScrollPhysics(),
        itemCount: prices.length,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.s3),
        itemBuilder: (context, i) => _PriceCard(prices[i]),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard(this.m);
  final MarketPrice m;

  @override
  Widget build(BuildContext context) {
    final up = m.up;
    final chgColor = up ? AppColors.ok : AppColors.danger;
    return Container(
      width: 144,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProduceImage(m.crop, width: 144, height: 84, radius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.s3, Insets.s2, Insets.s3, Insets.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.crop,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: inr(m.price),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const TextSpan(
                      text: '/qtl',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ]),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 13, color: chgColor),
                    Text('${m.changePct.abs()}%',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: chgColor)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
