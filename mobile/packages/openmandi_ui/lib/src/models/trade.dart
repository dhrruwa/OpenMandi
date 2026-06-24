import 'models.dart';

enum Role { farmer, dealer }

enum KycStatus { none, pending, verified, rejected }

enum OfferStatus { pending, countered, accepted, declined }

/// An offer made on a listing. From the farmer's view, [fromMe] is false
/// (a dealer offered); from the dealer's view, [fromMe] is true.
class Offer {
  Offer({
    required this.id,
    required this.listingId,
    required this.crop,
    required this.emoji,
    required this.party,
    required this.partyRole,
    required this.price,
    required this.qty,
    required this.unit,
    required this.marketPrice,
    required this.when,
    this.fromMe = false,
    this.status = OfferStatus.pending,
  });

  final String id;
  final String listingId;
  final String crop;
  final String emoji;
  final String party; // counterparty name
  final String partyRole;
  int price; // ₹/quintal
  final double qty;
  final Unit unit;
  final int marketPrice;
  final String when;
  final bool fromMe;
  OfferStatus status;

  double get quintals => switch (unit) {
        Unit.kg => qty / 100,
        Unit.quintal => qty,
        Unit.ton => qty * 10,
      };
  int get total => (price * quintals).round();
}

/// Recorded deal — the lightweight digital contract. Drives the lifecycle:
/// offer → accepted → confirmed → inTransit → delivered → completed.
class Order {
  Order({
    required this.id,
    required this.crop,
    required this.emoji,
    required this.counterparty,
    required this.counterpartyRole,
    required this.price,
    required this.qty,
    required this.unit,
    required this.marketPrice,
    required this.placedWhen,
    this.stage = OrderStage.accepted,
    this.paidToEscrow = false,
    this.buyerRated = false,
    this.sellerRated = false,
    this.counterpartyId = '',
  });

  final String id;
  final String crop;
  final String emoji;
  final String counterparty;
  final String counterpartyRole;
  final String counterpartyId; // the other party's user id (for reviews, live)
  final int price;
  final double qty;
  final Unit unit;
  int marketPrice; // filled from live prices after load
  final String placedWhen;
  OrderStage stage;
  bool paidToEscrow;
  bool buyerRated; // dealer rated the farmer
  bool sellerRated; // farmer rated the dealer

  double get quintals => switch (unit) {
        Unit.kg => qty / 100,
        Unit.quintal => qty,
        Unit.ton => qty * 10,
      };
  int get total => (price * quintals).round();
  bool get done => stage == OrderStage.completed;
  bool get active => !done;
}

extension OrderStageX on OrderStage {
  String get label => switch (this) {
        OrderStage.offer => 'Offer',
        OrderStage.accepted => 'Accepted',
        OrderStage.confirmed => 'Payment in escrow',
        OrderStage.inTransit => 'In transit',
        OrderStage.delivered => 'Delivered',
        OrderStage.completed => 'Completed',
      };
  int get index => OrderStage.values.indexOf(this);
}

class Message {
  Message({
    required this.id,
    required this.mine,
    required this.time,
    this.text,
    this.offer,
    this.system = false,
    this.audioUrl,
    this.transcript,
    this.translatedText,
  });
  final String id;
  final bool mine;
  final String time;
  final String? text;
  final Offer? offer;
  final bool system;
  final String? audioUrl;
  final String? transcript;
  final String? translatedText;

  bool get isAudio => audioUrl != null;
}

class Thread {
  Thread({
    required this.id,
    required this.name,
    required this.role,
    required this.crop,
    required this.emoji,
    required this.messages,
    this.unread = 0,
  });
  final String id;
  final String name;
  final String role;
  final String crop;
  final String emoji;
  final List<Message> messages;
  int unread;

  String get preview {
    final last = messages.lastWhere((m) => !m.system, orElse: () => messages.last);
    if (last.offer != null) return 'Offer · ₹${last.offer!.price}/qtl';
    return last.text ?? '';
  }

  String get lastTime => messages.isEmpty ? '' : messages.last.time;
}

enum NotifKind { offer, order, payout, message, price, system }

class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.when,
    this.read = false,
  });
  final String id;
  final NotifKind kind;
  final String title;
  final String body;
  final String when;
  bool read;
}

class WalletTxn {
  WalletTxn({
    required this.id,
    required this.label,
    required this.sub,
    required this.amount,
    required this.when,
    required this.credit,
  });
  final String id;
  final String label;
  final String sub;
  final int amount;
  final String when;
  final bool credit;
}

/// A saved payout/payment method (UI-only; no live gateway in this build).
class PaymentMethod {
  PaymentMethod({
    required this.id,
    required this.kind, // 'upi' | 'bank'
    required this.label,
    required this.detail,
  });
  final String id;
  final String kind;
  final String label;
  final String detail;
}
