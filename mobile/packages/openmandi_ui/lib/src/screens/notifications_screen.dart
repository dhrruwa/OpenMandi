import 'package:flutter/material.dart';

import '../store/app_store.dart';
import '../models/trade.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/empty_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
        actions: [
          TextButton(
            onPressed: store.markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(color: AppColors.onPrimary, fontSize: 13)),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'All caught up',
              body: 'Offers, order updates, payouts and price alerts will show here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Insets.s2),
            itemCount: store.notifications.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, color: AppColors.line),
            itemBuilder: (context, i) => _tile(store.notifications[i]),
          );
        },
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final (icon, fg, bg) = switch (n.kind) {
      NotifKind.offer => (Icons.local_offer_outlined, AppColors.accentPress, AppColors.accentTint),
      NotifKind.order => (Icons.receipt_long_outlined, AppColors.primaryPress, AppColors.primaryTint),
      NotifKind.payout => (Icons.account_balance_wallet_outlined, AppColors.ok, AppColors.okTint),
      NotifKind.message => (Icons.chat_bubble_outline, AppColors.primaryPress, AppColors.primaryTint),
      NotifKind.price => (Icons.trending_up, AppColors.ok, AppColors.okTint),
      NotifKind.system => (Icons.verified_user, AppColors.primaryPress, AppColors.primaryTint),
    };
    return Container(
      color: n.read ? AppColors.bg : AppColors.primaryTint.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: Insets.s4, vertical: Insets.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(n.body,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: Insets.s2),
          Text(n.when,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
