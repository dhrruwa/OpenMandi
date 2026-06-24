import 'package:flutter/material.dart';

import '../backend/config.dart';
import '../store/app_store.dart';
import '../models/trade.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/rating_stars.dart';
import 'wallet_screen.dart';
import 'preferred_locations_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.primary,
              surfaceTintColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              expandedHeight: 168,
              flexibleSpace: FlexibleSpaceBar(
                background: _header(store),
              ),
            ),
            SliverToBoxAdapter(child: _body(context, store)),
          ],
        ),
      ),
    );
  }

  Widget _header(AppStore store) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(Insets.s4, Insets.s10, Insets.s4, Insets.s4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0x29FBFCF9), shape: BoxShape.circle),
                child: Text(store.userName.isEmpty ? '?' : store.userName[0],
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary)),
              ),
              const SizedBox(width: Insets.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.userName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary)),
                    Text(
                        store.isFarmer
                            ? 'Farmer · Kolar, Karnataka'
                            : 'Exporter · Bengaluru',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xCCFBFCF9))),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        RatingStars(4.8, size: 14),
                        SizedBox(width: 6),
                        Text('4.8 · 34 deals',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xE6FBFCF9))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppStore store) {
    final verified = store.kyc == KycStatus.verified;
    return Padding(
      padding: const EdgeInsets.all(Insets.s4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(Insets.s4),
            decoration: BoxDecoration(
              color: verified ? AppColors.okTint : AppColors.warnTint,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Icon(verified ? Icons.verified : Icons.pending,
                    color: verified ? AppColors.ok : AppColors.warnInk),
                const SizedBox(width: Insets.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(verified
                          ? '${store.isFarmer ? 'PAN' : 'GST'} verified'
                          : 'Verification pending',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(verified
                          ? 'Your account is fully verified.'
                          : 'Finish KYC to unlock all features.',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.s4),
          _group([
            _row(context, Icons.account_balance_wallet_outlined,
                store.isFarmer ? 'Wallet & payouts' : 'Wallet & payments',
                () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const WalletScreen()))),
            if (store.isFarmer)
              _row(context, Icons.account_balance, 'Bank / UPI for payouts',
                  () => _soon(context)),
            if (!store.isFarmer && AppConfig.locationEnabled)
              _row(context, Icons.location_on_outlined, 'Preferred Locations',
                  () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PreferredLocationsScreen()))),
            if (!store.isFarmer)
              _row(context, Icons.bookmark_border, 'Saved searches & alerts',
                  () => _soon(context)),
            _row(context, Icons.workspace_premium_outlined, 'KYC documents',
                () => _soon(context)),
          ]),
          const SizedBox(height: Insets.s4),
          _group([
            _switchRow(Icons.translate, store.getTranslated('language_settings'), store.language, [
              'English',
              'Kannada',
              'Hindi',
              'Telugu',
              'Tamil',
              'Malayalam',
              'Marathi',
              'Gujarati',
              'Bengali',
              'Punjabi',
              'Odia',
              'Assamese',
              'Urdu'
            ], (v) => store.setLanguage(v)),
            _toggleRow(Icons.accessibility_new, 'Large-icon mode',
                'Bigger touch targets & simpler layout', store.largeIcons,
                store.setLargeIcons),
            _row(context, Icons.mic_none, 'Voice assistance', () => _soon(context)),
          ]),
          const SizedBox(height: Insets.s4),
          _group([
            _row(context, Icons.help_outline, 'Help & grievances',
                () => _soon(context)),
            _row(context, Icons.logout, 'Sign out', () => _signOut(context, store),
                danger: true),
          ]),
          const SizedBox(height: Insets.s10),
        ],
      ),
    );
  }

  Widget _group(List<Widget> rows) {
    // Material (not a coloured DecoratedBox) so ListTile ink/splash has a
    // surface to paint on — avoids the "background may be invisible" assert.
    return Material(
      color: AppColors.bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 1, indent: 52, color: AppColors.line),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? AppColors.danger : AppColors.primary, size: 22),
      title: Text(label,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      trailing: danger
          ? null
          : const Icon(Icons.chevron_right, color: AppColors.muted),
    );
  }

   Widget _switchRow(IconData icon, String label, String value,
      List<String> options, ValueChanged<String> onChanged) {
    const nativeNames = {
      'English': 'English',
      'Kannada': 'ಕನ್ನಡ',
      'Hindi': 'हिन्दी',
      'Telugu': 'తెలుగు',
      'Tamil': 'தமிழ்',
      'Malayalam': 'മലയാളം',
      'Marathi': 'मराठी',
      'Gujarati': 'ગુજરાતી',
      'Bengali': 'বাংলা',
      'Punjabi': 'ਪੰਜਾਬੀ',
      'Odia': 'ଓଡ଼િଆ',
      'Assamese': 'অসমীয়া',
      'Urdu': 'اردو',
    };
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(nativeNames[o] ?? o)),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }

  Widget _toggleRow(IconData icon, String label, String sub, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary,
      secondary: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Coming soon'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _signOut(BuildContext context, AppStore store) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        title: const Text('Sign out?'),
        content: const Text('You can sign back in any time with your number.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              store.signOut();
              Navigator.of(context).pop();
            },
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
