import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

/// Earnings + escrow at a glance, tappable through to the wallet. Trust is
/// visible: escrow state is surfaced, not buried (Design Principle 1).
class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Reveal(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.s4, Insets.s4, Insets.s4, 0),
        child: Tappable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.s5, vertical: Insets.s4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryPress],
              ),
              borderRadius: BorderRadius.circular(Radii.md),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1A1C2117), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 14, color: AppColors.onPrimary),
                          SizedBox(width: 5),
                          Text('Wallet balance',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xCCFBFCF9))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inr(store.wallet),
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppColors.onPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: inr(store.escrow),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const TextSpan(
                              text: ' in escrow · releases on delivery'),
                        ]),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xE6FBFCF9)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.s2),
                const Icon(Icons.chevron_right, color: Color(0xCCFBFCF9)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
