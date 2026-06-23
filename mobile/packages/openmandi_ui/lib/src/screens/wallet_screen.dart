import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store/app_store.dart';
import '../models/trade.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/buttons.dart';
import '../widgets/money.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text(store.isFarmer ? 'Wallet & payouts' : 'Wallet & payments',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(Insets.s4),
          children: [
            _balanceCard(context, store),
            const SizedBox(height: Insets.s5),
            const Text('Transactions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: Insets.s2),
            for (final tx in store.txns) _txTile(tx),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, AppStore store) {
    return Container(
      padding: const EdgeInsets.all(Insets.s5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryPress],
        ),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available balance',
              style: TextStyle(fontSize: 13, color: Color(0xCCFBFCF9))),
          Text(inr(store.wallet),
              style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.onPrimary,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: Insets.s2),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.s3, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x29FBFCF9),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 13, color: AppColors.onPrimary),
                const SizedBox(width: 5),
                Text('${inr(store.escrow)} held in escrow',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: Insets.s4),
          Row(
            children: [
              Expanded(
                child: _miniBtn(
                  store.isFarmer ? 'Withdraw' : 'Add money',
                  store.isFarmer ? Icons.account_balance : Icons.add,
                  () => _amountSheet(context, store, withdraw: store.isFarmer),
                ),
              ),
              const SizedBox(width: Insets.s3),
              Expanded(
                child: _miniBtn('Statement', Icons.description_outlined, () {}),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.onPrimary,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: AppColors.primaryPress),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.primaryPress,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _txTile(WalletTxn tx) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s3),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: tx.credit ? AppColors.okTint : AppColors.surface2,
                shape: BoxShape.circle),
            child: Icon(
                tx.credit ? Icons.south_west : Icons.north_east,
                size: 18,
                color: tx.credit ? AppColors.ok : AppColors.muted),
          ),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text('${tx.sub} · ${tx.when}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          Text('${tx.credit ? '+' : '−'}${inr(tx.amount)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tx.credit ? AppColors.ok : AppColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  void _amountSheet(BuildContext context, AppStore store, {required bool withdraw}) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Insets.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(withdraw ? 'Withdraw to bank' : 'Add money to wallet',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: Insets.s4),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: tnum,
                  decoration: const InputDecoration(
                      prefixText: '₹ ', hintText: '0'),
                ),
                const SizedBox(height: Insets.s5),
                AppButton.primary(withdraw ? 'Withdraw' : 'Add money',
                    onPressed: () {
                  final amt = int.tryParse(ctrl.text) ?? 0;
                  if (withdraw) {
                    store.withdraw(amt);
                  } else {
                    store.topUp(amt);
                  }
                  Navigator.of(context).pop();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
