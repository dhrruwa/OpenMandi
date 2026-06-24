import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

/// Farmer's own listing: stats + incoming offers with accept (creates an order).
class MyListingScreen extends StatelessWidget {
  const MyListingScreen(this.listing, {super.key});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        title: Text(listing.crop,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final offers = store.offersFor(listing.id);
          return ListView(
            padding: const EdgeInsets.all(Insets.s4),
            children: [
              _hero(),
              const SizedBox(height: Insets.s5),
              Row(
                children: [
                  _stat(Icons.visibility_outlined, '${listing.views}', 'Views'),
                  _stat(Icons.local_offer_outlined, '${offers.length}', 'Open offers'),
                  _stat(Icons.insights, inr(listing.marketPrice), 'Mandi/qtl'),
                ],
              ),
              const SizedBox(height: Insets.s5),
              Text(offers.isEmpty ? 'Offers' : 'Offers (${offers.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: Insets.s3),
              if (listing.status == ListingStatus.sold)
                _soldNote()
              else if (offers.isEmpty)
                _noOffers()
              else
                for (final o in offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.s3),
                    child: _OfferCard(
                      offer: o,
                      onAccept: () => _accept(context, store, o),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _accept(BuildContext context, AppStore store, Offer o) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await store.acceptOffer(o);
      messenger.showSnackBar(SnackBar(
        content: Text('Accepted ${o.party}\'s offer · order created'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not accept: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Widget _hero() {
    return Row(
      children: [
        ProduceImage(listing.crop, imageUrl: listing.photoUrl, size: 64, organic: listing.organic),
        const SizedBox(width: Insets.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${_qty(listing.qty)} ${listing.unit.label}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(width: Insets.s2),
                  GradeChip(listing.grade),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  StatusPill(listing),
                  const SizedBox(width: Insets.s2),
                  Text('${inr(listing.price)}/qtl asking',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: Insets.s3),
        padding: const EdgeInsets.symmetric(vertical: Insets.s3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()])),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _noOffers() => Container(
        padding: const EdgeInsets.all(Insets.s5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: AppColors.muted),
            SizedBox(width: Insets.s3),
            Expanded(
              child: Text('No offers yet. Buyers nearby can see this listing.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ),
          ],
        ),
      );

  Widget _soldNote() => Container(
        padding: const EdgeInsets.all(Insets.s4),
        decoration: BoxDecoration(
          color: AppColors.okTint,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.ok),
            SizedBox(width: Insets.s3),
            Expanded(
              child: Text('Sold — see the deal in your Orders tab.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onAccept});
  final Offer offer;
  final VoidCallback onAccept;

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
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.accentTint, shape: BoxShape.circle),
                child: Text(o.party.isNotEmpty ? o.party[0].toUpperCase() : 'D',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentPress)),
              ),
              const SizedBox(width: Insets.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.party,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('${o.partyRole} · ${o.when}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${inr(o.price)}/qtl',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  Text('${over ? '▲' : '▼'} ${inr((o.price - o.marketPrice).abs())} vs mandi',
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
              Text('Total ${inr(o.total)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              SizedBox(
                width: 150,
                child: AppButton.accent('Accept', onPressed: onAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
