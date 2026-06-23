import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/trade.dart';
import '../store/app_store.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/buttons.dart';
import '../widgets/crop_avatar.dart';
import '../widgets/money.dart';
import '../widgets/order_stepper.dart';
import '../widgets/rating_stars.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen(this.order, {super.key});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        title: Text('${order.crop} order',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final o = order;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Insets.s4),
                  children: [
                    _summary(o),
                    const SizedBox(height: Insets.s5),
                    _escrowCard(store, o),
                    const SizedBox(height: Insets.s5),
                    const Text('Progress',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: Insets.s4),
                    OrderStepper(o.stage),
                    if (o.done) ...[
                      const SizedBox(height: Insets.s5),
                      _ratingBlock(context, store, o),
                    ],
                  ],
                ),
              ),
              _ActionBar(order: o),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(Order o) {
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CropAvatar(o.emoji, size: 56),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${o.crop} · ${_qty(o.qty)} ${o.unit.label}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('${o.counterpartyRole} · ${o.counterparty}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${inr(o.price)}/qtl',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                      text: '  ·  total ${inr(o.total)}',
                      style: const TextStyle(color: AppColors.muted)),
                ]), style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _escrowCard(AppStore store, Order o) {
    final funded = o.paidToEscrow;
    final released = o.done;
    final (icon, title, body, bg, fg) = released
        ? (
            Icons.verified,
            'Escrow released',
            store.isFarmer
                ? '${inr(o.total)} has been paid into your wallet.'
                : 'Payment released to ${o.counterparty} on delivery.',
            AppColors.okTint,
            AppColors.ok,
          )
        : funded
            ? (
                Icons.lock,
                'Payment secured in escrow',
                store.isFarmer
                    ? 'Buyer has paid ${inr(o.total)}. Released to you on delivery.'
                    : 'Your ${inr(o.total)} is held safely until you confirm delivery.',
                AppColors.primaryTint,
                AppColors.primaryPress,
              )
            : (
                Icons.shield_outlined,
                'Escrow protects this deal',
                store.isFarmer
                    ? 'Waiting for the buyer to fund escrow.'
                    : 'Pay into escrow to confirm. Money is only released on delivery.',
                AppColors.surface,
                AppColors.muted,
              );
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
        border: bg == AppColors.surface ? Border.all(color: AppColors.line) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.ink, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBlock(BuildContext context, AppStore store, Order o) {
    final rated = store.isFarmer ? o.sellerRated : o.buyerRated;
    if (rated) {
      return Container(
        padding: const EdgeInsets.all(Insets.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.ok, size: 20),
            const SizedBox(width: Insets.s2),
            Text('You rated ${o.counterparty}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            const RatingStars(5),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: AppColors.warnTint,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Rate your deal with ${o.counterparty}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          AppButton.ghost('Rate', onPressed: () => _rate(context, store, o)),
        ],
      ),
    );
  }

  void _rate(BuildContext context, AppStore store, Order o) {
    int stars = 5;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Insets.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rate ${o.counterparty}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Reviews are only allowed after a completed order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: Insets.s4),
                StarPicker(value: stars, onChanged: (v) => setSheet(() => stars = v)),
                const SizedBox(height: Insets.s5),
                AppButton.primary('Submit rating', onPressed: () {
                  store.rateOrder(o, stars);
                  Navigator.of(context).pop();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

/// Role + stage drive the single primary action that moves the deal forward.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final o = order;
    final (label, onTap, accent) = _action(context, store, o);

    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(Insets.s4, Insets.s3, Insets.s4,
          Insets.s3 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: accent
          ? AppButton.accent(label, onPressed: onTap)
          : AppButton.primary(label, onPressed: onTap),
    );
  }

  (String?, VoidCallback?, bool) _action(
      BuildContext context, AppStore store, Order o) {
    void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(m),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary),
        );

    if (store.isFarmer) {
      return switch (o.stage) {
        OrderStage.accepted when !o.paidToEscrow => (
            'Buyer funds escrow (demo)',
            () => store.buyerFundedEscrow(o),
            false
          ),
        OrderStage.confirmed => (
            'Mark dispatched',
            () {
              store.advance(o);
              snack('Marked as dispatched');
            },
            false
          ),
        OrderStage.inTransit => (
            'Mark delivered',
            () => store.advance(o),
            false
          ),
        OrderStage.delivered => (
            'Buyer confirms receipt (demo)',
            () => store.confirmDelivery(o),
            true
          ),
        _ => (null, null, false),
      };
    } else {
      return switch (o.stage) {
        OrderStage.accepted when !o.paidToEscrow => (
            'Pay ${inr(o.total)} into escrow',
            () {
              store.payIntoEscrow(o);
              snack('Payment held in escrow');
            },
            true
          ),
        OrderStage.confirmed => (
            'Farmer dispatched (demo)',
            () => store.advance(o),
            false
          ),
        OrderStage.inTransit => (
            'Mark delivered',
            () => store.advance(o),
            false
          ),
        OrderStage.delivered => (
            'Confirm delivery & release',
            () {
              store.confirmDelivery(o);
              snack('Delivery confirmed · payment released');
            },
            true
          ),
        _ => (null, null, false),
      };
    }
  }
}
