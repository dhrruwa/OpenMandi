import '../models/models.dart';

/// Demo fixtures shared by both apps. In production these come from the
/// single OpenMandi backend (discover → negotiate → order → pay → deliver → rate).
abstract final class Mock {
  static const farmerName = 'Lakshmi';
  static const farmerVillage = 'Kolar, Karnataka';
  static const wallet = 48250;
  static const escrow = 12400;

  static const dealerName = 'Surya Exports';
  static const dealerType = 'Exporter';
  static const dealerCity = 'Bengaluru';

  static const crops = <Crop>[
    Crop('Tomato', '🍅', 2400),
    Crop('Onion', '🧅', 1850),
    Crop('Potato', '🥔', 1320),
    Crop('Brinjal', '🍆', 2100),
    Crop('Chilli', '🌶️', 9800),
    Crop('Carrot', '🥕', 1700),
    Crop('Cabbage', '🥬', 980),
    Crop('Okra', '🫛', 3200),
  ];

  static const prices = <MarketPrice>[
    MarketPrice('Tomato', '🍅', 2400, 8.2),
    MarketPrice('Onion', '🧅', 1850, -3.1),
    MarketPrice('Potato', '🥔', 1320, 1.4),
    MarketPrice('Brinjal', '🍆', 2100, 5.6),
    MarketPrice('Chilli', '🌶️', 9800, -1.2),
    MarketPrice('Carrot', '🥕', 1700, 2.9),
  ];

  static const _lakshmi = Seller(
    name: 'Lakshmi', village: 'Kolar', rating: 4.8, deals: 34);
  static const _ravi = Seller(
    name: 'Ravi Kumar', village: 'Chintamani', rating: 4.6, deals: 21);
  static const _meena = Seller(
    name: 'Meena Bai', village: 'Malur', rating: 4.9, deals: 52);
  static const _arjun = Seller(
    name: 'Arjun Reddy', village: 'Srinivaspur', rating: 4.3, deals: 12);

  /// The farmer's own listings (farmer app).
  static const myListings = <Listing>[
    Listing(
      id: 'l1', crop: 'Tomato', emoji: '🍅', qty: 1.2, unit: Unit.ton,
      grade: Grade.a, organic: false, price: 2600, marketPrice: 2400,
      harvestInDays: 0, location: 'Kolar', distanceKm: 0,
      status: ListingStatus.offers, offers: 3, views: 41, seller: _lakshmi,
    ),
    Listing(
      id: 'l2', crop: 'Brinjal', emoji: '🍆', qty: 600, unit: Unit.kg,
      grade: Grade.a, organic: true, price: 2300, marketPrice: 2100,
      harvestInDays: 4, location: 'Kolar', distanceKm: 0,
      status: ListingStatus.live, offers: 0, views: 12, seller: _lakshmi,
    ),
    Listing(
      id: 'l3', crop: 'Onion', emoji: '🧅', qty: 2.5, unit: Unit.ton,
      grade: Grade.b, organic: false, price: 1800, marketPrice: 1850,
      harvestInDays: 0, location: 'Kolar', distanceKm: 0,
      status: ListingStatus.sold, offers: 0, views: 88, seller: _lakshmi,
    ),
  ];

  /// The wider marketplace (dealer app — listings from many farmers).
  static const marketListings = <Listing>[
    Listing(
      id: 'm1', crop: 'Tomato', emoji: '🍅', qty: 1.2, unit: Unit.ton,
      grade: Grade.a, organic: false, price: 2600, marketPrice: 2400,
      harvestInDays: 0, location: 'Kolar', distanceKm: 18,
      status: ListingStatus.live, offers: 3, views: 41, seller: _lakshmi,
    ),
    Listing(
      id: 'm2', crop: 'Chilli', emoji: '🌶️', qty: 800, unit: Unit.kg,
      grade: Grade.a, organic: true, price: 9600, marketPrice: 9800,
      harvestInDays: 0, location: 'Malur', distanceKm: 26,
      status: ListingStatus.live, offers: 5, views: 120, seller: _meena,
    ),
    Listing(
      id: 'm3', crop: 'Onion', emoji: '🧅', qty: 3, unit: Unit.ton,
      grade: Grade.b, organic: false, price: 1820, marketPrice: 1850,
      harvestInDays: 2, location: 'Chintamani', distanceKm: 34,
      status: ListingStatus.live, offers: 1, views: 47, seller: _ravi,
    ),
    Listing(
      id: 'm4', crop: 'Carrot', emoji: '🥕', qty: 500, unit: Unit.kg,
      grade: Grade.a, organic: false, price: 1750, marketPrice: 1700,
      harvestInDays: 0, location: 'Srinivaspur', distanceKm: 41,
      status: ListingStatus.live, offers: 0, views: 9, seller: _arjun,
    ),
    Listing(
      id: 'm5', crop: 'Potato', emoji: '🥔', qty: 4, unit: Unit.ton,
      grade: Grade.b, organic: false, price: 1300, marketPrice: 1320,
      harvestInDays: 6, location: 'Kolar', distanceKm: 18,
      status: ListingStatus.live, offers: 2, views: 33, seller: _lakshmi,
    ),
    Listing(
      id: 'm6', crop: 'Brinjal', emoji: '🍆', qty: 600, unit: Unit.kg,
      grade: Grade.a, organic: true, price: 2300, marketPrice: 2100,
      harvestInDays: 4, location: 'Malur', distanceKm: 26,
      status: ListingStatus.live, offers: 0, views: 15, seller: _meena,
    ),
  ];

  /// Farmer-app activity feed.
  static const activity = <Activity>[
    Activity(
      id: 'a1', kind: ActivityKind.offer, who: 'Surya Exports',
      whoType: 'Exporter', crop: 'Tomato', amount: 2550, qty: 1.2,
      unit: Unit.ton, when: '12 min ago', unread: true,
    ),
    Activity(
      id: 'a2', kind: ActivityKind.offer, who: 'Anand Traders',
      whoType: 'Local dealer', crop: 'Tomato', amount: 2500, qty: 1,
      unit: Unit.ton, when: '1 hr ago', unread: true,
    ),
    Activity(
      id: 'a3', kind: ActivityKind.payout, who: 'OpenMandi',
      whoType: 'OpenMandi', crop: 'Onion', amount: 12400, when: 'Yesterday',
    ),
    Activity(
      id: 'a4', kind: ActivityKind.message, who: 'FreshCo Foods',
      whoType: 'Company', crop: 'Brinjal', when: 'Yesterday',
    ),
  ];

  /// Dealer-app open buy requirements (reverse marketplace).
  static const requirements = <BuyRequirement>[
    BuyRequirement(
      id: 'r1', crop: 'Tomato', emoji: '🍅', qty: 5, unit: Unit.ton,
      priceMin: 2300, priceMax: 2600, neededInDays: 7, location: 'within 50 km',
      responses: 4,
    ),
    BuyRequirement(
      id: 'r2', crop: 'Chilli', emoji: '🌶️', qty: 1, unit: Unit.ton,
      priceMin: 9000, priceMax: 9800, neededInDays: 14, location: 'within 80 km',
      responses: 2,
    ),
  ];
}
