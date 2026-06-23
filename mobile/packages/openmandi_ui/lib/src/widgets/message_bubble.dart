import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/trade.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'money.dart';

/// Chat bubble. Plain text, an embedded offer card, or a centred system note.
class MessageBubble extends StatelessWidget {
  const MessageBubble(this.message, {super.key, this.onAcceptOffer});
  final Message message;
  final VoidCallback? onAcceptOffer;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.s2),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.s3, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(m.text ?? '',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ),
      );
    }

    final align = m.mine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = m.mine ? AppColors.primary : AppColors.surface;
    final fg = m.mine ? AppColors.onPrimary : AppColors.ink;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: m.offer != null
            ? _offerCard(context, m.offer!, m.mine)
            : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.s3, vertical: Insets.s2),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(Radii.md),
                    topRight: const Radius.circular(Radii.md),
                    bottomLeft: Radius.circular(m.mine ? Radii.md : 4),
                    bottomRight: Radius.circular(m.mine ? 4 : Radii.md),
                  ),
                ),
                child: Text(m.text ?? '',
                    style: TextStyle(fontSize: 15, color: fg, height: 1.3)),
              ),
      ),
    );
  }

  Widget _offerCard(BuildContext context, Offer o, bool mine) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(Insets.s3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, size: 15, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(mine ? 'Your offer' : 'Offer received',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentPress)),
            ],
          ),
          const SizedBox(height: Insets.s2),
          Text('${inr(o.price)}/qtl',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
          Text('${_qty(o.qty)} ${o.unit.label} · total ${inr(o.total)}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          if (!mine && onAcceptOffer != null && o.status == OfferStatus.pending) ...[
            const SizedBox(height: Insets.s3),
            GestureDetector(
              onTap: onAcceptOffer,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: const Text('Accept offer',
                    style: TextStyle(
                        color: AppColors.onAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
            ),
          ],
          if (o.status == OfferStatus.accepted)
            Padding(
              padding: const EdgeInsets.only(top: Insets.s2),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, size: 14, color: AppColors.ok),
                  SizedBox(width: 4),
                  Text('Accepted',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ok)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}
