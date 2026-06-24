import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import 'category_screens.dart';
import 'my_listing_screen.dart';

// Home category buttons → each opens a dedicated page.
enum _Cat { all, live, offers, sold }

extension on _Cat {
  String label(AppStore store) => switch (this) {
        _Cat.all => store.getTranslated('cat_all'),
        _Cat.live => store.getTranslated('cat_live'),
        _Cat.offers => store.getTranslated('cat_offers'),
        _Cat.sold => store.getTranslated('cat_sold'),
      };
  IconData get icon => switch (this) {
        _Cat.all => Icons.grid_view_rounded,
        _Cat.live => Icons.sell_outlined,
        _Cat.offers => Icons.local_offer_outlined,
        _Cat.sold => Icons.check_circle_outline,
      };
  FarmerView get view => switch (this) {
        _Cat.all => FarmerView.all,
        _Cat.live => FarmerView.live,
        _Cat.offers => FarmerView.offers,
        _Cat.sold => FarmerView.sold,
      };
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _query = '';

  void _openCategory(BuildContext context, _Cat cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => farmerCategoryPage(cat.view)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final listings = store.myListings
              .where((l) =>
                  _query.isEmpty ||
                  l.crop.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          return Column(
            children: [
              MarketHeader(
                title:
                    '${store.getTranslated('farmer_label')}: ${store.userName.isEmpty ? 'farmer' : store.userName}',
                subtitle: store.getTranslated('live_mandi_subtitle'),
                searchHint: store.getTranslated('search_produce'),
                onSearchChanged: (v) => setState(() => _query = v),
                selected: -1, // chips act as navigation, not a filter
                onCategory: (i) => _openCategory(context, _Cat.values[i]),
                categories: [
                  for (final c in _Cat.values) MarketCategory(c.icon, c.label(store)),
                ],
                trailing: [
                  IconButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NotificationsScreen())),
                    icon: const Icon(Icons.notifications_none,
                        color: AppColors.onPrimary),
                    tooltip: 'Notifications',
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: store.reloadAll,
                  child: ListView(
                    padding: EdgeInsets.only(
                        bottom: 96 + MediaQuery.of(context).padding.bottom),
                    children: [
                      const SizedBox(height: Insets.s2),
                      SectionHeader(
                        title: store.getTranslated('todays_mandi_price'),
                        subtitle: store.getTranslated('mandi_price_subtitle'),
                        actionLabel: store.getTranslated('cat_all'),
                        onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PricesScreen())),
                      ),
                      PriceStrip(prices: store.prices),
                      const SizedBox(height: Insets.s1),
                      const _Divider(),
                      SectionHeader(
                        title: store.getTranslated('your_listings'),
                        subtitle: store.getTranslated('active_count').replaceAll(
                            '{count}',
                            store.myListings
                                .where((l) => l.status != ListingStatus.sold)
                                .length
                                .toString()),
                        actionLabel: 'See all',
                        onAction: () => _openCategory(context, _Cat.all),
                      ),
                      if (listings.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Insets.s4, vertical: Insets.s4),
                          child: Text(store.getTranslated('empty_listings_hint'),
                              style: const TextStyle(color: AppColors.muted)),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
                          child: Column(
                            children: [
                              for (var i = 0; i < listings.length && i < 4; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                      bottom: i == listings.length - 1 ? 0 : Insets.s3),
                                  child: Reveal(
                                    delay: Duration(milliseconds: i * 50),
                                    child: ListingCard(
                                      listings[i],
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => MyListingScreen(listings[i]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const _Divider(),
                      SectionHeader(title: store.getTranslated('activity_title')),
                      _Activity(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final items = store.notifications.take(4).toList();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.s4, vertical: Insets.s3),
        child: Text(store.getTranslated('no_activity'),
            style: const TextStyle(color: AppColors.muted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _row(context, items[i], last: i == items.length - 1),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppNotification n, {required bool last}) {
    final (icon, fg, bg) = switch (n.kind) {
      NotifKind.offer => (Icons.local_offer_outlined, AppColors.accentPress, AppColors.accentTint),
      NotifKind.payout => (Icons.account_balance_wallet_outlined, AppColors.ok, AppColors.okTint),
      NotifKind.price => (Icons.trending_up, AppColors.ok, AppColors.okTint),
      _ => (Icons.receipt_long_outlined, AppColors.primaryPress, AppColors.primaryTint),
    };
    return Tappable(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.s3, horizontal: 2),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(n.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: Insets.s2),
            Text(n.when, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      margin: const EdgeInsets.only(top: Insets.s5),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(
          top: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}
