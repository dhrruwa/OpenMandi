import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

double _toQuintals(double qty, Unit unit) => switch (unit) {
      Unit.kg => qty / 100,
      Unit.quintal => qty,
      Unit.ton => qty * 10,
    };

class OfferSheet extends StatefulWidget {
  const OfferSheet._(this.listing);
  final Listing listing;

  static Future<void> show(BuildContext context, Listing listing) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x731C2117),
      builder: (_) => OfferSheet._(listing),
    );
  }

  @override
  State<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<OfferSheet> {
  late final _price =
      TextEditingController(text: '${widget.listing.price}');
  late final _qty = TextEditingController(text: _fmtQty(widget.listing.qty));

  @override
  void initState() {
    super.initState();
    _price.addListener(() => setState(() {}));
    _qty.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  int get _priceNum => int.tryParse(_price.text) ?? 0;
  double get _qtyNum => double.tryParse(_qty.text) ?? 0;
  int get _total => (_priceNum * _toQuintals(_qtyNum, widget.listing.unit)).round();
  bool get _valid => _priceNum > 0 && _qtyNum > 0;

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Insets.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.s4),
                Row(
                  children: [
                    CropAvatar(l.emoji, size: 44, organic: l.organic),
                    const SizedBox(width: Insets.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Offer for ${l.crop}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(
                              'Asking ${inr(l.price)}/qtl · mandi ${inr(l.marketPrice)}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.s5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Your price (₹/qtl)',
                        controller: _price,
                        digitsOnly: true,
                      ),
                    ),
                    const SizedBox(width: Insets.s3),
                    Expanded(
                      child: _Field(
                        label: 'Quantity (${l.unit.label})',
                        controller: _qty,
                        digitsOnly: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.s4),
                Container(
                  padding: const EdgeInsets.all(Insets.s4),
                  decoration: BoxDecoration(
                    color: AppColors.accentTint,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(
                    children: [
                      const Text('Estimated total',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.accentPress)),
                      const Spacer(),
                      Text(
                        _valid ? inr(_total) : '—',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentPress,
                            fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.s3),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user, size: 16, color: AppColors.ok),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'On acceptance, your payment is held in escrow until you confirm delivery.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.s4),
                AppButton.accent(
                  'Send offer',
                  icon: Icons.send,
                  onPressed: _valid ? () => _send(context) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _send(BuildContext context) {
    final store = context.store;
    final order = store.makeOffer(widget.listing, price: _priceNum, qty: _qtyNum);
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order)),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        content: Text('${widget.listing.seller.name} accepted — pay into escrow to confirm'),
      ),
    );
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.digitsOnly,
  });
  final String label;
  final TextEditingController controller;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: Insets.s2),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !digitsOnly),
          inputFormatters: [
            digitsOnly
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: tnum,
        ),
      ],
    );
  }
}
