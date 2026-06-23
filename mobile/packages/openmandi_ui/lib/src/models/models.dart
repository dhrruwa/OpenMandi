import 'package:flutter/foundation.dart';

enum Grade {
  a('A', 'Premium · uniform, fresh, export-ready'),
  b('B', 'Good · minor blemishes, local market'),
  c('C', 'Fair · processing, bulk use');

  const Grade(this.label, this.desc);
  final String label;
  final String desc;
}

enum ListingStatus { live, offers, sold }

enum Unit { kg, quintal, ton }

@immutable
class Crop {
  const Crop(this.name, this.emoji, this.marketPrice);
  final String name;
  final String emoji;
  final int marketPrice; // ₹ per quintal, today's mandi rate
}

@immutable
class MarketPrice {
  const MarketPrice(this.crop, this.emoji, this.price, this.changePct);
  final String crop;
  final String emoji;
  final int price; // ₹ per quintal
  final double changePct; // vs yesterday
  bool get up => changePct >= 0;
}

@immutable
class Seller {
  const Seller({
    required this.name,
    required this.village,
    required this.rating,
    required this.deals,
    this.verified = true,
  });
  final String name;
  final String village;
  final double rating;
  final int deals;
  final bool verified;
}

@immutable
class Listing {
  const Listing({
    required this.id,
    required this.crop,
    required this.emoji,
    required this.qty,
    required this.unit,
    required this.grade,
    required this.organic,
    required this.price,
    required this.marketPrice,
    required this.harvestInDays,
    required this.location,
    required this.distanceKm,
    required this.status,
    required this.offers,
    required this.views,
    required this.seller,
  });

  final String id;
  final String crop;
  final String emoji;
  final double qty;
  final Unit unit;
  final Grade grade;
  final bool organic;
  final int price; // farmer's ask, ₹/quintal
  final int marketPrice; // today's mandi, ₹/quintal
  final int harvestInDays; // 0 = ready now
  final String location;
  final int distanceKm;
  final ListingStatus status;
  final int offers;
  final int views;
  final Seller seller;

  bool get readyNow => harvestInDays == 0;
  bool get overMarket => price >= marketPrice;
  int get vsMarket => (price - marketPrice).abs();
}

enum ActivityKind { offer, order, message, payout }

@immutable
class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.who,
    required this.whoType,
    required this.crop,
    required this.when,
    this.amount,
    this.qty,
    this.unit,
    this.unread = false,
  });

  final String id;
  final ActivityKind kind;
  final String who;
  final String whoType;
  final String crop;
  final String when;
  final int? amount;
  final double? qty;
  final Unit? unit;
  final bool unread;
}

enum OrderStage { offer, accepted, confirmed, inTransit, delivered, completed }

@immutable
class BuyRequirement {
  const BuyRequirement({
    required this.id,
    required this.crop,
    required this.emoji,
    required this.qty,
    required this.unit,
    required this.priceMin,
    required this.priceMax,
    required this.neededInDays,
    required this.location,
    required this.responses,
  });
  final String id;
  final String crop;
  final String emoji;
  final double qty;
  final Unit unit;
  final int priceMin;
  final int priceMax;
  final int neededInDays;
  final String location;
  final int responses;
}

extension UnitLabel on Unit {
  String get label => switch (this) {
        Unit.kg => 'kg',
        Unit.quintal => 'quintal',
        Unit.ton => 'ton',
      };
}
