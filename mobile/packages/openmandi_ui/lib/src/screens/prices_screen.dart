import 'package:flutter/material.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/money.dart';
import '../widgets/skeleton.dart';

/// Full mandi price board with a simple sparkline trend per crop.
class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Mandi prices',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(
            padding: EdgeInsets.only(bottom: Insets.s3, left: Insets.s4, right: Insets.s4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Live · eNAM / Agmarknet',
                  style: TextStyle(fontSize: 12, color: Color(0xCCFBFCF9))),
            ),
          ),
        ),
      ),
      body: context.store.loading && context.store.prices.isEmpty
          ? SkeletonList(count: 8, itemBuilder: (_) => const PriceCardSkeleton())
          : ListView.separated(
              padding: const EdgeInsets.all(Insets.s4),
              itemCount: context.store.prices.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.s3),
              itemBuilder: (context, i) => _PriceRow(context.store.prices[i]),
            ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.m);
  final MarketPrice m;

  @override
  Widget build(BuildContext context) {
    final up = m.up;
    final color = up ? AppColors.ok : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.all(Insets.s4),
      child: Row(
        children: [
          Text(m.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.crop,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('per quintal',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            height: 32,
            child: CustomPaint(painter: _Spark(m.changePct, color)),
          ),
          const SizedBox(width: Insets.s4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(inr(m.price),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()])),
              Row(
                children: [
                  Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 13, color: color),
                  Text('${m.changePct.abs()}%',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Spark extends CustomPainter {
  _Spark(this.change, this.color);
  final double change;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic pseudo-trend derived from the change %, ending up/down.
    final pts = <Offset>[];
    final n = 7;
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      final wobble = ((i * 37) % 11) / 11 - 0.5;
      final base = change >= 0 ? t : 1 - t;
      final y = size.height * (0.8 - base * 0.6 + wobble * 0.18).clamp(0.05, 0.95);
      pts.add(Offset(t * size.width, y));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Spark old) => old.change != change || old.color != color;
}
