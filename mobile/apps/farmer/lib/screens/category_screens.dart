import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import 'my_listing_screen.dart';

/// Which dedicated page to show from the home category buttons.
enum FarmerView { all, live, offers, sold }

/// Routes a category button to its dedicated page.
Widget farmerCategoryPage(FarmerView view) => switch (view) {
      FarmerView.offers => const FarmerOffersScreen(),
      FarmerView.all => const _ListingsPage(
          title: 'All products', filter: _ListFilter.all),
      FarmerView.live => const _ListingsPage(
          title: 'Live products', filter: _ListFilter.live),
      FarmerView.sold => const _ListingsPage(
          title: 'Sold products', filter: _ListFilter.sold),
    };

enum _ListFilter { all, live, sold }

class _ListingsPage extends StatelessWidget {
  const _ListingsPage({required this.title, required this.filter});
  final String title;
  final _ListFilter filter;

  bool _test(Listing l) => switch (filter) {
        _ListFilter.all => true,
        _ListFilter.live =>
          l.status == ListingStatus.live || l.status == ListingStatus.offers,
        _ListFilter.sold => l.status == ListingStatus.sold,
      };

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.myListings.where(_test).toList();
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Nothing here yet',
              body: filter == _ListFilter.sold
                  ? 'Products you sell will show up here.'
                  : 'Tap “List produce” on the home screen to add a crop.',
            );
          }
          return RefreshIndicator(
            onRefresh: store.reloadAll,
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.s4),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.s3),
              itemBuilder: (context, i) => ListingCard(
                items[i],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MyListingScreen(items[i]))),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// All offers the farmer has received across their listings, with full data
/// (dealer, price vs mandi, total) and an Accept action.
class FarmerOffersScreen extends StatelessWidget {
  const FarmerOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Offers',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final offers =
              store.offers.where((o) => o.status == OfferStatus.pending).toList();
          if (offers.isEmpty) {
            return const EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No offers yet',
              body: 'When a dealer makes an offer on your produce, it appears here.',
            );
          }
          return RefreshIndicator(
            onRefresh: store.reloadAll,
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.s4),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.s3),
              itemBuilder: (context, i) => _OfferCard(offers[i]),
            ),
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard(this.offer);
  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final over = o.price >= o.marketPrice;
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProduceImage(o.crop, size: 48, radius: Radii.sm),
              const SizedBox(width: Insets.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.crop,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('${o.party} · ${o.partyRole}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${inr(o.price)}/qtl',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  if (o.marketPrice > 0)
                    Text(
                        '${over ? '▲' : '▼'} ${inr((o.price - o.marketPrice).abs())} vs mandi',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: over ? AppColors.ok : AppColors.accentPress)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.s3),
          Row(
            children: [
              Text('${_qty(o.qty)} ${o.unit.label} · total ${inr(o.total)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              SizedBox(
                width: 140,
                child: AppButton.accent('Accept', onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await context.store.acceptOffer(o);
                    messenger.showSnackBar(SnackBar(
                      content: Text('Accepted ${o.party}\'s offer — order created'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primary,
                    ));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(
                      content: Text('Could not accept: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.danger,
                    ));
                  }
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

/// Open buy requirements posted by dealers — what buyers are looking for.
class FarmerBuyRequestsScreen extends StatelessWidget {
  const FarmerBuyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Buyers looking for produce',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final reqs = store.openRequirements;
          if (reqs.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No buyer requirements yet',
              body: 'When dealers post what they want to buy, it shows here so '
                  'you can supply it directly.',
            );
          }
          return RefreshIndicator(
            onRefresh: store.reloadAll,
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.s4),
              itemCount: reqs.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.s3),
              itemBuilder: (context, i) => _ReqCard(reqs[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ReqCard extends StatefulWidget {
  const _ReqCard(this.r);
  final BuyRequirement r;

  @override
  State<_ReqCard> createState() => _ReqCardState();
}

class _ReqCardState extends State<_ReqCard> {
  bool _busy = false;

  BuyRequirement get r => widget.r;

  Future<void> _respond() async {
    final store = context.store;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final tid = await store.respondToRequirement(r);
      if (tid == null) throw Exception('could not start chat');
      nav.push(MaterialPageRoute(builder: (_) => ChatThreadScreen(tid)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not respond: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProduceImage(r.crop, size: 48, radius: Radii.sm),
              const SizedBox(width: Insets.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wants ${r.crop}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('${_qty(r.qty)} ${r.unit.label} · ${r.location}',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              Pill(
                label: '${r.responses} responses',
                icon: Icons.people_alt_outlined,
                fg: AppColors.primaryPress,
                bg: AppColors.primaryTint,
              ),
            ],
          ),
          const Divider(height: Insets.s5),
          Row(
            children: [
              _stat('Pays', '${inr(r.priceMin)}–${inr(r.priceMax)}/qtl'),
              const SizedBox(width: Insets.s5),
              _stat('Needed in', '${r.neededInDays} days'),
            ],
          ),
          const SizedBox(height: Insets.s4),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              _busy ? 'Opening chat…' : 'I can supply this',
              icon: Icons.handshake_outlined,
              onPressed: _busy ? null : _respond,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          Text(v,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      );

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}
