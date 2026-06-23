import 'package:flutter/widgets.dart';

import '../backend/backend.dart';
import '../backend/config.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../models/trade.dart';

/// In-memory backend shared by both apps. Each app instantiates one with its
/// [role]; [seed] loads a believable starting state, and the action methods
/// drive the full trade lifecycle, notifying listeners so the UI reacts.
class AppStore extends ChangeNotifier {
  AppStore({required this.role});

  final Role role;
  bool get isFarmer => role == Role.farmer;

  // ── session ───────────────────────────────
  bool onboarded = false;
  String userName = '';
  String phone = '';
  KycStatus kyc = KycStatus.none;
  String language = 'English';
  bool largeIcons = false;

  // ── data ──────────────────────────────────
  final List<Listing> myListings = [];
  final List<Listing> market = [];
  final List<Offer> offers = [];
  final List<Order> orders = [];
  final List<Thread> threads = [];
  final List<AppNotification> notifications = [];
  final List<BuyRequirement> requirements = [];
  final List<WalletTxn> txns = [];

  int wallet = 0;
  int escrow = 0;
  int _seq = 0;
  String _id(String p) => '$p${_seq++}';

  int get unreadNotifs => notifications.where((n) => !n.read).length;
  int get unreadChats =>
      threads.fold(0, (sum, t) => sum + (t.unread > 0 ? 1 : 0));
  List<Order> get activeOrders => orders.where((o) => o.active).toList();

  // crops/prices the UI reads (mock defaults; replaced in live bootstrap)
  final List<Crop> crops = List.of(Mock.crops);
  final List<MarketPrice> prices = List.of(Mock.prices);
  final Map<String, String> cropIds = {}; // crop name → DB id (live only)
  String? lastError;
  double? myLat;
  double? myLng;

  bool get live => AppConfig.isLive;

  /// Device coordinates (best-effort; null if unavailable). Mock → null.
  Future<(double?, double?)> currentLatLng() =>
      live ? Backend.I.currentLatLng() : Future.value((null, null));

  // ── bootstrap ─────────────────────────────
  /// Entry point used by main(): live → load from Supabase; else seed mock.
  Future<void> bootstrap() async {
    if (!live) {
      seed();
      return;
    }
    if (Backend.I.signedIn) {
      await reloadAll();
      _subscribeRealtime();
    } else {
      notifyListeners(); // AuthGate shows onboarding
    }
  }

  bool _reloading = false;
  bool _reloadAgain = false;

  Future<void> reloadAll() async {
    // coalesce bursts of realtime events into at most one in-flight reload
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    final b = Backend.I;
    try {
      final row = await b.myUserRow();
      if (row != null) {
        userName = (row['full_name'] ?? userName) as String;
        onboarded = true;
        kyc = switch (row['kyc_status'] as String?) {
          'verified' => KycStatus.verified,
          'rejected' => KycStatus.rejected,
          'none' => KycStatus.none,
          _ => KycStatus.pending,
        };
      }
      final cropRows = await b.loadCropRows();
      final livePrices = await b.loadPrices();
      final priceByName = {for (final p in livePrices) p.crop: p.price};
      crops
        ..clear()
        ..addAll([
          for (final r in cropRows)
            Crop(r['name'] as String, (r['emoji'] ?? '🌱') as String,
                priceByName[r['name']] ?? 0)
        ]);
      cropIds
        ..clear()
        ..addEntries(
            [for (final r in cropRows) MapEntry(r['name'] as String, r['id'] as String)]);
      prices
        ..clear()
        ..addAll(livePrices);
      if (isFarmer) {
        final mine = await b.loadMyListings();
        myListings
          ..clear()
          ..addAll(mine);
      } else {
        final m = await b.loadMarketListings();
        final (mlat, mlng) = await b.currentLatLng();
        myLat = mlat;
        myLng = mlng;
        final withDist = [
          for (final l in m)
            () {
              final d = b.distanceKmBetween(mlat, mlng, l.lat, l.lng);
              return d == null ? l : l.withDistanceKm(d.round());
            }()
        ];
        market
          ..clear()
          ..addAll(withDist);
      }
      final ords = await b.loadOrders();
      orders
        ..clear()
        ..addAll(ords);
      if (isFarmer) {
        final inc = await b.loadIncomingOffers();
        offers
          ..clear()
          ..addAll(inc);
      }
      final th = await b.loadThreads();
      threads
        ..clear()
        ..addAll(th);
      final notifs = await b.loadNotifications();
      notifications
        ..clear()
        ..addAll(notifs);

      // fill each order's mandi reference + derive real wallet/escrow
      for (final o in orders) {
        o.marketPrice = priceByName[o.crop] ?? o.marketPrice;
      }
      escrow = orders
          .where((o) => o.paidToEscrow && o.active)
          .fold(0, (s, o) => s + o.total);
      wallet = isFarmer
          ? orders.where((o) => o.done).fold(0, (s, o) => s + o.total)
          : 0; // dealers fund per-order via escrow; no standing balance
      lastError = null;
    } catch (e) {
      lastError = '$e';
    } finally {
      _reloading = false;
    }
    notifyListeners();
    if (_reloadAgain) {
      _reloadAgain = false;
      await reloadAll();
    }
  }

  bool _subscribed = false;
  void _subscribeRealtime() {
    if (_subscribed) return;
    _subscribed = true;
    for (final table in ['orders', 'notifications', 'messages', 'offers', 'listings']) {
      Backend.I.subscribe(table, reloadAll);
    }
  }

  @override
  void dispose() {
    if (live) Backend.I.disposeChannels();
    super.dispose();
  }

  /// Run a live write, then refresh from server truth. Errors captured.
  void _live(Future<void> Function() op) {
    op().then((_) => reloadAll()).catchError((Object e) {
      lastError = '$e';
      notifyListeners();
    });
  }

  // ── seed ──────────────────────────────────
  void seed() {
    if (isFarmer) {
      userName = Mock.farmerName;
      wallet = Mock.wallet;
      escrow = Mock.escrow;
      myListings.addAll(Mock.myListings);

      offers.addAll([
        Offer(
          id: _id('of'),
          listingId: 'l1',
          crop: 'Tomato',
          emoji: '🍅',
          party: 'Surya Exports',
          partyRole: 'Exporter',
          price: 2550,
          qty: 1.2,
          unit: Unit.ton,
          marketPrice: 2400,
          when: '12 min ago',
        ),
        Offer(
          id: _id('of'),
          listingId: 'l1',
          crop: 'Tomato',
          emoji: '🍅',
          party: 'Anand Traders',
          partyRole: 'Local dealer',
          price: 2500,
          qty: 1,
          unit: Unit.ton,
          marketPrice: 2400,
          when: '1 hr ago',
        ),
      ]);

      orders.add(Order(
        id: _id('or'),
        crop: 'Onion',
        emoji: '🧅',
        counterparty: 'GreenLeaf Wholesale',
        counterpartyRole: 'Local dealer',
        price: 1850,
        qty: 2.5,
        unit: Unit.ton,
        marketPrice: 1850,
        placedWhen: 'Yesterday',
        stage: OrderStage.completed,
        paidToEscrow: true,
        buyerRated: true,
        sellerRated: true,
      ));

      threads.add(Thread(
        id: _id('th'),
        name: 'Surya Exports',
        role: 'Exporter',
        crop: 'Tomato',
        emoji: '🍅',
        unread: 1,
        messages: [
          Message(id: _id('m'), mine: false, time: '12 min', text: 'Namaste, your Grade A tomatoes look great. Can you do 1.2 ton?'),
          Message(
            id: _id('m'),
            mine: false,
            time: '12 min',
            offer: Offer(
              id: _id('of'),
              listingId: 'l1',
              crop: 'Tomato',
              emoji: '🍅',
              party: 'Surya Exports',
              partyRole: 'Exporter',
              price: 2550,
              qty: 1.2,
              unit: Unit.ton,
              marketPrice: 2400,
              when: '12 min',
            ),
          ),
        ],
      ));

      _seedWallet();
      _seedNotifs(isFarmer: true);
    } else {
      userName = Mock.dealerName;
      wallet = 220000;
      escrow = 0;
      market.addAll(Mock.marketListings);
      requirements.addAll(Mock.requirements);
      _seedWallet(dealer: true);
      _seedNotifs(isFarmer: false);
    }
  }

  void _seedWallet({bool dealer = false}) {
    if (dealer) {
      txns.addAll([
        WalletTxn(id: _id('tx'), label: 'Wallet top-up', sub: 'UPI · HDFC', amount: 200000, when: '2 days ago', credit: true),
        WalletTxn(id: _id('tx'), label: 'Onion order · Meena Bai', sub: 'Escrow funded', amount: 46250, when: '5 days ago', credit: false),
      ]);
    } else {
      txns.addAll([
        WalletTxn(id: _id('tx'), label: 'Onion order · GreenLeaf', sub: 'Escrow released', amount: 12400, when: 'Yesterday', credit: true),
        WalletTxn(id: _id('tx'), label: 'Withdrawal to bank', sub: 'A/C ••4521', amount: 30000, when: '4 days ago', credit: false),
        WalletTxn(id: _id('tx'), label: 'Brinjal order · FreshCo', sub: 'Escrow released', amount: 38000, when: '1 week ago', credit: true),
      ]);
    }
  }

  void _seedNotifs({required bool isFarmer}) {
    if (isFarmer) {
      notifications.addAll([
        AppNotification(id: _id('n'), kind: NotifKind.offer, title: 'New offer on your Tomato', body: 'Surya Exports offered ₹2,550/qtl', when: '12 min ago'),
        AppNotification(id: _id('n'), kind: NotifKind.price, title: 'Tomato price up 8.2%', body: 'Kolar APMC now ₹2,400/qtl', when: '3 hr ago'),
        AppNotification(id: _id('n'), kind: NotifKind.payout, title: 'Escrow released', body: '₹12,400 credited for your Onion order', when: 'Yesterday', read: true),
      ]);
    } else {
      notifications.addAll([
        AppNotification(id: _id('n'), kind: NotifKind.price, title: 'Chilli dropped 1.2%', body: 'Good time to source — Malur ₹9,800/qtl', when: '2 hr ago'),
        AppNotification(id: _id('n'), kind: NotifKind.system, title: 'GST verification complete', body: 'Your dealer account is now verified', when: 'Yesterday', read: true),
      ]);
    }
  }

  // ── onboarding ────────────────────────────
  void completeOnboarding({required String name, required String phone}) {
    userName = name.trim().isEmpty ? userName : name.trim();
    this.phone = phone;
    onboarded = true;
    kyc = KycStatus.pending;
    notifyListeners();
  }

  void submitKyc() {
    kyc = KycStatus.verified;
    notifications.insert(
        0,
        AppNotification(
          id: _id('n'),
          kind: NotifKind.system,
          title: 'Verification complete',
          body: isFarmer ? 'PAN verified — you can now get paid' : 'GST verified — you can now order',
          when: 'Just now',
        ));
    notifyListeners();
  }

  void signOut() {
    onboarded = false;
    notifyListeners();
  }

  void setLanguage(String l) {
    language = l;
    notifyListeners();
  }

  void setLargeIcons(bool v) {
    largeIcons = v;
    notifyListeners();
  }

  // ── farmer: create listing ────────────────
  void addListing({
    required Crop crop,
    required double qty,
    required Unit unit,
    required Grade grade,
    required bool organic,
    required int price,
    required int harvestInDays,
    List<String> photos = const [],
    double? lat,
    double? lng,
  }) {
    if (live) {
      final cropId = cropIds[crop.name];
      if (cropId != null) {
        _live(() => Backend.I.createListing(
              cropId: cropId,
              qty: qty,
              unit: unit,
              grade: grade,
              organic: organic,
              price: price,
              marketPrice: crop.marketPrice,
              harvestInDays: harvestInDays,
              photos: photos,
              lat: lat,
              lng: lng,
            ));
      }
      return;
    }
    myListings.insert(
      0,
      Listing(
        id: _id('l'),
        crop: crop.name,
        emoji: crop.emoji,
        qty: qty,
        unit: unit,
        grade: grade,
        organic: organic,
        price: price,
        marketPrice: crop.marketPrice,
        harvestInDays: harvestInDays,
        location: 'Kolar',
        distanceKm: 0,
        status: ListingStatus.live,
        offers: 0,
        views: 0,
        seller: const Seller(name: 'Lakshmi', village: 'Kolar', rating: 4.8, deals: 34),
        photos: photos,
      ),
    );
    notifyListeners();
  }

  List<Offer> offersFor(String listingId) =>
      offers.where((o) => o.listingId == listingId && o.status == OfferStatus.pending).toList();

  // ── farmer: accept an incoming offer → order ──
  void acceptOffer(Offer offer) {
    if (live) {
      _live(() => Backend.I.acceptOffer(offer.id));
      return;
    }
    offer.status = OfferStatus.accepted;
    for (final o in offers) {
      if (o.listingId == offer.listingId && o != offer) {
        o.status = OfferStatus.declined;
      }
    }
    final l = myListings.firstWhere((x) => x.id == offer.listingId,
        orElse: () => Mock.myListings.first);
    final idx = myListings.indexWhere((x) => x.id == offer.listingId);
    if (idx >= 0) {
      myListings[idx] = _withStatus(l, ListingStatus.sold);
    }
    final order = Order(
      id: _id('or'),
      crop: offer.crop,
      emoji: offer.emoji,
      counterparty: offer.party,
      counterpartyRole: offer.partyRole,
      price: offer.price,
      qty: offer.qty,
      unit: offer.unit,
      marketPrice: offer.marketPrice,
      placedWhen: 'Just now',
      stage: OrderStage.accepted,
    );
    orders.insert(0, order);
    notifications.insert(
        0,
        AppNotification(
          id: _id('n'),
          kind: NotifKind.order,
          title: 'Deal agreed with ${offer.party}',
          body: 'Awaiting payment into escrow',
          when: 'Just now',
        ));
    notifyListeners();
  }

  // ── dealer: make an offer ─────────────────
  /// Mock-only optimistic offer→order. In live mode the dealer UI calls
  /// Backend.makeOffer directly (creates offer+thread; farmer accepts later).
  Order makeOffer(Listing l, {required int price, required double qty}) {
    final offer = Offer(
      id: _id('of'),
      listingId: l.id,
      crop: l.crop,
      emoji: l.emoji,
      party: l.seller.name,
      partyRole: 'Farmer',
      price: price,
      qty: qty,
      unit: l.unit,
      marketPrice: l.marketPrice,
      when: 'Just now',
      fromMe: true,
    );
    offers.insert(0, offer);

    // demo: the farmer accepts, producing a live order to drive forward.
    final order = Order(
      id: _id('or'),
      crop: l.crop,
      emoji: l.emoji,
      counterparty: l.seller.name,
      counterpartyRole: 'Farmer',
      price: price,
      qty: qty,
      unit: l.unit,
      marketPrice: l.marketPrice,
      placedWhen: 'Just now',
      stage: OrderStage.accepted,
    );
    orders.insert(0, order);

    _ensureThread(l.seller.name, 'Farmer', l.crop, l.emoji, offer: offer, mine: true);
    notifications.insert(
        0,
        AppNotification(
          id: _id('n'),
          kind: NotifKind.order,
          title: '${l.seller.name} accepted your offer',
          body: 'Pay ${_money(order.total)} into escrow to confirm',
          when: 'Just now',
        ));
    notifyListeners();
    return order;
  }

  // ── order lifecycle ───────────────────────

  /// Farmer side: the buyer has funded escrow. Money is held *for* the farmer
  /// (escrow incoming), wallet unchanged until delivery is confirmed.
  void buyerFundedEscrow(Order o) {
    if (live) {
      _live(() => Backend.I.advanceOrder(o.id));
      return;
    }
    if (o.paidToEscrow) return;
    o.paidToEscrow = true;
    o.stage = OrderStage.confirmed;
    escrow += o.total;
    notifyListeners();
  }

  /// Dealer side: buyer pays now; debit wallet, hold in escrow.
  void payIntoEscrow(Order o) {
    if (live) {
      _live(() => Backend.I.advanceOrder(o.id));
      return;
    }
    if (o.paidToEscrow) return;
    o.paidToEscrow = true;
    o.stage = OrderStage.confirmed;
    wallet -= o.total;
    escrow += o.total;
    txns.insert(
        0,
        WalletTxn(
          id: _id('tx'),
          label: '${o.crop} order · ${o.counterparty}',
          sub: 'Escrow funded',
          amount: o.total,
          when: 'Just now',
          credit: false,
        ));
    notifyListeners();
  }

  void advance(Order o) {
    if (live) {
      _live(() => Backend.I.advanceOrder(o.id));
      return;
    }
    if (o.stage.index < OrderStage.delivered.index) {
      o.stage = OrderStage.values[o.stage.index + 1];
      notifyListeners();
    }
  }

  /// Buyer confirms delivery → escrow releases to the farmer, order completes.
  void confirmDelivery(Order o) {
    if (live) {
      _live(() => Backend.I.completeOrder(o.id));
      return;
    }
    o.stage = OrderStage.completed;
    if (isFarmer) {
      wallet += o.total;
      escrow = (escrow - o.total).clamp(0, 1 << 31);
      txns.insert(
          0,
          WalletTxn(
            id: _id('tx'),
            label: '${o.crop} order · ${o.counterparty}',
            sub: 'Escrow released',
            amount: o.total,
            when: 'Just now',
            credit: true,
          ));
    } else {
      escrow = (escrow - o.total).clamp(0, 1 << 31);
      txns.insert(
          0,
          WalletTxn(
            id: _id('tx'),
            label: '${o.crop} order · ${o.counterparty}',
            sub: 'Released to farmer on delivery',
            amount: o.total,
            when: 'Just now',
            credit: false,
          ));
    }
    notifications.insert(
        0,
        AppNotification(
          id: _id('n'),
          kind: NotifKind.payout,
          title: 'Order completed',
          body: isFarmer
              ? '${_money(o.total)} released to your wallet'
              : 'Payment released to ${o.counterparty}',
          when: 'Just now',
        ));
    notifyListeners();
  }

  void rateOrder(Order o, int stars) {
    if (isFarmer) {
      o.sellerRated = true;
    } else {
      o.buyerRated = true;
    }
    notifyListeners();
    if (live && o.counterpartyId.isNotEmpty) {
      _live(() => Backend.I.submitReview(o.id, o.counterpartyId, stars));
    }
  }

  void withdraw(int amount) {
    if (amount <= 0 || amount > wallet) return;
    wallet -= amount;
    txns.insert(
        0,
        WalletTxn(
          id: _id('tx'),
          label: 'Withdrawal to bank',
          sub: 'A/C ••4521',
          amount: amount,
          when: 'Just now',
          credit: false,
        ));
    notifyListeners();
  }

  void topUp(int amount) {
    if (amount <= 0) return;
    wallet += amount;
    txns.insert(
        0,
        WalletTxn(
          id: _id('tx'),
          label: 'Wallet top-up',
          sub: 'UPI · HDFC',
          amount: amount,
          when: 'Just now',
          credit: true,
        ));
    notifyListeners();
  }

  // ── chat ──────────────────────────────────
  void _ensureThread(String name, String role, String crop, String emoji,
      {Offer? offer, required bool mine}) {
    var t = threads.where((x) => x.name == name && x.crop == crop).firstOrNull;
    t ??= () {
      final nt = Thread(
          id: _id('th'),
          name: name,
          role: role,
          crop: crop,
          emoji: emoji,
          messages: []);
      threads.insert(0, nt);
      return nt;
    }();
    if (offer != null) {
      t.messages.add(Message(id: _id('m'), mine: mine, time: 'now', offer: offer));
    }
  }

  Thread threadById(String id) => threads.firstWhere((t) => t.id == id);

  void sendMessage(Thread t, String text) {
    t.messages.add(Message(id: _id('m'), mine: true, time: 'now', text: text));
    notifyListeners();
    if (live) {
      _live(() => Backend.I.sendMessage(t.id, text));
      return;
    }
    // demo: a canned reply so the thread feels alive.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      t.messages.add(Message(
          id: _id('m'),
          mine: false,
          time: 'now',
          text: 'Thik hai — let me check and confirm shortly.'));
      notifyListeners();
    });
  }

  void readThread(Thread t) {
    if (t.unread > 0) {
      t.unread = 0;
      notifyListeners();
    }
  }

  // ── notifications ─────────────────────────
  void markAllRead() {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  // ── requirements ──────────────────────────
  void postRequirement({
    required Crop crop,
    required double qty,
    required Unit unit,
    required int priceMin,
    required int priceMax,
    required int neededInDays,
  }) {
    if (live) {
      final cropId = cropIds[crop.name];
      if (cropId != null) {
        _live(() => Backend.I.postRequirement(
              cropId: cropId,
              qty: qty,
              unit: unit,
              priceMin: priceMin,
              priceMax: priceMax,
              neededInDays: neededInDays,
            ));
      }
      return;
    }
    requirements.insert(
      0,
      BuyRequirement(
        id: _id('rq'),
        crop: crop.name,
        emoji: crop.emoji,
        qty: qty,
        unit: unit,
        priceMin: priceMin,
        priceMax: priceMax,
        neededInDays: neededInDays,
        location: 'within 50 km',
        responses: 0,
      ),
    );
    notifyListeners();
  }

  // ── helpers ───────────────────────────────
  static Listing _withStatus(Listing l, ListingStatus s) => Listing(
        id: l.id,
        crop: l.crop,
        emoji: l.emoji,
        qty: l.qty,
        unit: l.unit,
        grade: l.grade,
        organic: l.organic,
        price: l.price,
        marketPrice: l.marketPrice,
        harvestInDays: l.harvestInDays,
        location: l.location,
        distanceKm: l.distanceKm,
        status: s,
        offers: l.offers,
        views: l.views,
        seller: l.seller,
      );

  static String _money(int n) => '₹${n.toString()}';
}

/// Exposes the [AppStore] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.notifier!;
  }
}

extension StoreContext on BuildContext {
  AppStore get store => AppScope.of(this);
}
