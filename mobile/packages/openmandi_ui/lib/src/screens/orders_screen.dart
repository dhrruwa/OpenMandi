import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/trade.dart';
import '../store/app_store.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/chips.dart';
import '../widgets/crop_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/money.dart';
import '../widgets/order_stepper.dart';
import '../widgets/reveal.dart';
import '../widgets/tappable.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final active = store.orders.where((o) => o.active).toList();
          final past = store.orders.where((o) => o.done).toList();
          return CustomScrollView(
            slivers: [
              _bar(store),
              if (store.orders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    body: store.isFarmer
                        ? 'When you accept an offer, the deal shows up here as an order.'
                        : 'Make an offer on a listing to start your first order.',
                  ),
                )
              else ...[
                if (active.isNotEmpty) _section('Active'),
                for (var i = 0; i < active.length; i++)
                  _tile(context, active[i], i),
                if (past.isNotEmpty) _section('Completed'),
                for (var i = 0; i < past.length; i++)
                  _tile(context, past[i], i),
                const SliverToBoxAdapter(child: SizedBox(height: Insets.s8)),
              ],
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _bar(AppStore store) => SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Orders',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
      );

  Widget _section(String label) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4, Insets.s5, Insets.s4, Insets.s2),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ),
      );

  Widget _tile(BuildContext context, Order o, int i) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.s4, 0, Insets.s4, Insets.s3),
        child: Reveal(
          delay: Duration(milliseconds: i * 45),
          child: OrderTile(o),
        ),
      ),
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile(this.order, {super.key});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Tappable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(o)),
      ),
      child: Container(
        padding: const EdgeInsets.all(Insets.s3),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CropAvatar(o.emoji, size: 48, organic: false),
                const SizedBox(width: Insets.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(o.crop,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(width: Insets.s2),
                          Text('${_qty(o.qty)} ${o.unit.label}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                      Text(o.counterparty,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(inr(o.total),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    _stagePill(o.stage),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Insets.s3),
            OrderProgressBar(o.stage),
          ],
        ),
      ),
    );
  }

  Widget _stagePill(OrderStage s) {
    if (s == OrderStage.completed) {
      return const Pill(
          label: 'Completed', icon: Icons.check, fg: AppColors.ok, bg: AppColors.okTint);
    }
    return Pill(
        label: s.label,
        fg: AppColors.primaryPress,
        bg: AppColors.primaryTint);
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}
