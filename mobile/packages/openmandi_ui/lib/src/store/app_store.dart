import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
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
  AppStore({required this.role}) {
    detectDeviceLanguage();
  }

  final Role role;
  bool get isFarmer => role == Role.farmer;

  // ── session ───────────────────────────────
  bool onboarded = false;
  String userName = '';
  String phone = '';
  KycStatus kyc = KycStatus.none;
  String language = 'English';
  final List<DealerPreferredLocation> preferredLocations = [];
  bool largeIcons = false;

  // ── data ──────────────────────────────────
  final List<Listing> myListings = [];
  final List<Listing> market = [];
  final List<Offer> offers = [];
  final List<Order> orders = [];
  final List<Thread> threads = [];
  final List<AppNotification> notifications = [];
  final List<BuyRequirement> requirements = []; // dealer's own posted
  final List<BuyRequirement> openRequirements = []; // all open (farmer browses)
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
  double avgRating = 0; // real rating of the signed-in user
  int ratingCount = 0;

  bool get live => AppConfig.isLive;

  /// A short, unique, app-generated ID derived from the auto-created account
  /// (the Supabase user id). Shown to the user; no manual signup needed.
  String get publicUserId {
    if (live) {
      final id = Backend.I.uid;
      if (id != null) {
        return 'OM-${id.replaceAll('-', '').substring(0, 6).toUpperCase()}';
      }
    }
    return 'OM-DEMO01';
  }

  /// Device coordinates (best-effort; null if unavailable). Returns null when
  /// location is disabled (no GPS prompt) or in mock mode.
  Future<(double?, double?)> currentLatLng() =>
      (live && AppConfig.locationEnabled)
          ? Backend.I.currentLatLng()
          : Future.value((null, null));

  // ── bootstrap ─────────────────────────────
  /// Entry point used by main(): live → load from Supabase; else seed mock.
  // Temporary no-login mode: demo credentials per role.
  String get _demoEmail =>
      isFarmer ? 'demo_farmer@example.com' : 'demo_dealer@example.com';
  static const _demoPassword = 'Password123!';

  Future<void> bootstrap() async {
    if (!live) {
      seed();
      return;
    }
    // Auth paused → silently sign in a demo account so data + sharing work
    // without any login screen.
    if (!AppConfig.requireLogin && !Backend.I.signedIn) {
      try {
        await Backend.I.signIn(_demoEmail, _demoPassword);
      } catch (e) {
        lastError = 'Auto sign-in failed: $e';
      }
    }
    if (Backend.I.signedIn) {
      await reloadAll();
      _subscribeRealtime();
    } else {
      notifyListeners(); // AuthGate shows onboarding (only if requireLogin)
    }
  }

  bool _reloading = false;
  bool _reloadAgain = false;
  bool _hasLoadedOnce = false;

  /// True only during the very first load, so screens can show skeletons
  /// without flashing them on every pull-to-refresh.
  bool get loading => _reloading && !_hasLoadedOnce;

  Future<void> reloadAll() async {
    // coalesce bursts of realtime events into at most one in-flight reload
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    final b = Backend.I;
    try {
      // Kick off every independent load at once, then await together — much
      // faster than the old one-after-another sequence.
      final useLoc = !isFarmer && AppConfig.locationEnabled;
      final userF = b.myUserRow();
      final cropsF = b.loadCropRows();
      final pricesF = b.loadPrices();
      final listingsF = isFarmer ? b.loadMyListings() : b.loadMarketListings();
      final ordersF = b.loadOrders();
      final Future<List<Offer>> offersF =
          isFarmer ? b.loadIncomingOffers() : Future.value(<Offer>[]);
      final Future<List<BuyRequirement>> reqsF =
          isFarmer ? Future.value(<BuyRequirement>[]) : b.loadRequirements();
      final Future<List<BuyRequirement>> openReqF =
          isFarmer ? b.loadOpenRequirements() : Future.value(<BuyRequirement>[]);
      final threadsF = b.loadThreads();
      final notifsF = b.loadNotifications();
      final Future<List<DealerPreferredLocation>> prefLocF =
          useLoc ? b.loadPreferredLocations() : Future.value(<DealerPreferredLocation>[]);
      final Future<(double?, double?)> myLatLngF =
          useLoc ? b.currentLatLng() : Future.value((null, null));

      await Future.wait<dynamic>([
        userF, cropsF, pricesF, listingsF, ordersF, offersF, reqsF,
        openReqF, threadsF, notifsF, prefLocF, myLatLngF,
      ]);

      final row = await userF;
      if (row != null) {
        userName = (row['full_name'] ?? userName) as String;
        avgRating = ((row['avg_rating'] ?? 0) as num).toDouble();
        ratingCount = (row['rating_count'] ?? 0) as int;
        onboarded = true;
        kyc = switch (row['kyc_status'] as String?) {
          'verified' => KycStatus.verified,
          'rejected' => KycStatus.rejected,
          'none' => KycStatus.none,
          _ => KycStatus.pending,
        };
        final dbLang = row['preferred_language'] as String?;
        if (dbLang != null) {
          language = switch (dbLang) {
            'kn' => 'Kannada',
            'hi' => 'Hindi',
            'te' => 'Telugu',
            'ta' => 'Tamil',
            'ml' => 'Malayalam',
            'mr' => 'Marathi',
            'gu' => 'Gujarati',
            'bn' => 'Bengali',
            'pa' => 'Punjabi',
            'or' => 'Odia',
            'as' => 'Assamese',
            'ur' => 'Urdu',
            _ => 'English',
          };
        }
      }
      final cropRows = await cropsF;
      final livePrices = await pricesF;
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
        myListings
          ..clear()
          ..addAll(await listingsF);
      } else {
        final m = await listingsF;
        if (useLoc) {
          final (mlat, mlng) = await myLatLngF;
          myLat = mlat;
          myLng = mlng;
          preferredLocations
            ..clear()
            ..addAll(await prefLocF);

          // distance computed locally (haversine) — free + instant, no API call
          final withDist = <Listing>[];
          for (final l in m) {
            int? bestDist;
            if (l.lat != null && l.lng != null) {
              double? minD;
              if (preferredLocations.isNotEmpty) {
                for (final pl in preferredLocations) {
                  final d = _haversineKm(pl.lat, pl.lng, l.lat!, l.lng!);
                  if (minD == null || d < minD) minD = d;
                }
              } else if (mlat != null && mlng != null) {
                minD = _haversineKm(mlat, mlng, l.lat!, l.lng!);
              }
              if (minD != null) bestDist = minD.round();
            }
            withDist.add(bestDist == null ? l : l.withDistanceKm(bestDist));
          }
          market
            ..clear()
            ..addAll(withDist);
        } else {
          market
            ..clear()
            ..addAll(m);
        }
      }
      orders
        ..clear()
        ..addAll(await ordersF);
      if (isFarmer) {
        offers
          ..clear()
          ..addAll(await offersF);
        openRequirements
          ..clear()
          ..addAll(await openReqF);
      } else {
        requirements
          ..clear()
          ..addAll(await reqsF);
      }
      threads
        ..clear()
        ..addAll(await threadsF);
      notifications
        ..clear()
        ..addAll(await notifsF);

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
      _hasLoadedOnce = true;
    }
    notifyListeners();
    if (_reloadAgain) {
      _reloadAgain = false;
      await reloadAll();
    }
  }

  /// Lightweight refresh of just the chat threads (used to poll an open chat so
  /// new messages from the other side arrive even if a realtime event is missed).
  Future<void> refreshThreads() async {
    if (!live) return;
    try {
      final th = await Backend.I.loadThreads();
      threads
        ..clear()
        ..addAll(th);
      notifyListeners();
    } catch (_) {
      // ignore transient errors during polling
    }
  }

  // Debounce realtime events: a burst across tables coalesces into one reload,
  // keeping the UI smooth instead of firing many full reloads back-to-back.
  Timer? _reloadDebounce;
  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 700), reloadAll);
  }

  bool _subscribed = false;
  void _subscribeRealtime() {
    if (_subscribed) return;
    _subscribed = true;
    for (final table in [
      'orders',
      'notifications',
      'messages',
      'offers',
      'listings',
      'threads',
    ]) {
      Backend.I.subscribe(table, _scheduleReload);
    }
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
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

  void detectDeviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    language = switch (code) {
      'kn' => 'Kannada',
      'hi' => 'Hindi',
      'te' => 'Telugu',
      'ta' => 'Tamil',
      'ml' => 'Malayalam',
      'mr' => 'Marathi',
      'gu' => 'Gujarati',
      'bn' => 'Bengali',
      'pa' => 'Punjabi',
      'or' => 'Odia',
      'as' => 'Assamese',
      'ur' => 'Urdu',
      _ => 'English',
    };
  }

  void setLanguage(String l) {
    language = l;
    notifyListeners();
    if (live) {
      _live(() => Backend.I.updatePreferredLanguage(_langCode(l)));
    }
  }

  void setLargeIcons(bool v) {
    largeIcons = v;
    notifyListeners();
  }

  void addPreferredLocation({required String label, required double lat, required double lng, required int radiusKm}) {
    if (live) {
      _live(() async {
        await Backend.I.addPreferredLocation(label, lat, lng, radiusKm);
      });
      return;
    }
    preferredLocations.add(DealerPreferredLocation(
      id: _id('dpl'),
      dealerId: 'mock_dealer',
      label: label,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    ));
    notifyListeners();
  }

  void deletePreferredLocation(String id) {
    if (live) {
      _live(() async {
        await Backend.I.deletePreferredLocation(id);
      });
      return;
    }
    preferredLocations.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  // ── farmer: create listing ────────────────
  Future<void> addListing({
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
    String? pincode,
    String? village,
    String? taluk,
    String? district,
    String? state,
    String? country,
    String? locationLabel,
  }) async {
    if (live) {
      final cropId = cropIds[crop.name];
      if (cropId == null) {
        throw Exception('Crop list not loaded yet — pull down to refresh, then retry.');
      }
      // awaited so failures (e.g. not verified, network) surface to the UI
      await Backend.I.createListing(
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
        pincode: pincode,
        village: village,
        taluk: taluk,
        district: district,
        state: state,
        country: country,
        locationLabel: locationLabel,
      );
      await reloadAll();
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
        location: locationLabel ?? village ?? 'Kolar',
        distanceKm: 0,
        lat: lat,
        lng: lng,
        pincode: pincode,
        village: village,
        taluk: taluk,
        district: district,
        state: state,
        country: country,
        status: ListingStatus.live,
        offers: 0,
        views: 0,
        seller: Seller(name: userName.isNotEmpty ? userName : 'Lakshmi', village: village ?? 'Kolar', rating: 4.8, deals: 34),
        photos: photos,
      ),
    );
    if (isFarmer) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        notifications.insert(
          0,
          AppNotification(
            id: _id('n'),
            kind: NotifKind.system,
            title: getTranslated('dealer_match_title'),
            body: getTranslated('dealer_match_body').replaceAll('{count}', '3'),
            when: 'Just now',
          ),
        );
        notifyListeners();
      });
    }
    notifyListeners();
  }

  List<Offer> offersFor(String listingId) =>
      offers.where((o) => o.listingId == listingId && o.status == OfferStatus.pending).toList();

  // ── farmer: accept an incoming offer → order ──
  Future<void> acceptOffer(Offer offer) async {
    if (live) {
      // awaited so failures (already accepted, network) surface to the UI
      await Backend.I.acceptOffer(offer.id);
      await reloadAll();
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

  /// Make or counter an offer inside an existing chat thread (either party).
  Future<void> counterOffer(Thread t, int price, double qty) async {
    if (live) {
      await Backend.I.counterOffer(t.id, price, qty);
      await refreshThreads();
      return;
    }
    // mock: append an offer message to the local thread
    t.messages.add(Message(
      id: _id('m'),
      mine: true,
      time: 'Just now',
      offer: Offer(
        id: _id('of'),
        listingId: '',
        crop: t.crop,
        emoji: t.emoji,
        party: t.name,
        partyRole: t.role,
        price: price,
        qty: qty,
        unit: Unit.quintal,
        marketPrice: 0,
        when: 'Just now',
        fromMe: true,
      ),
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
      // optimistic: reflect instantly, then sync in the background
      o.paidToEscrow = true;
      o.stage = OrderStage.confirmed;
      escrow += o.total;
      notifyListeners();
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
      // optimistic: bump stage instantly, then sync
      if (o.stage.index < OrderStage.delivered.index) {
        o.stage = OrderStage.values[o.stage.index + 1];
        notifyListeners();
      }
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
      // optimistic: mark completed + move escrow instantly, then sync
      o.stage = OrderStage.completed;
      escrow = (escrow - o.total).clamp(0, 1 << 31);
      if (isFarmer) wallet += o.total;
      notifyListeners();
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

  // ── payment methods (local; no live gateway in this build) ──────────
  final List<PaymentMethod> paymentMethods = [];

  void addPaymentMethod(String kind, String label, String detail) {
    paymentMethods.add(PaymentMethod(
        id: _id('pm'),
        kind: kind,
        label: label,
        detail: kind == 'bank' && detail.length > 4
            ? 'A/C ••${detail.substring(detail.length - 4)}'
            : detail));
    notifyListeners();
  }

  void removePaymentMethod(PaymentMethod m) {
    paymentMethods.removeWhere((x) => x.id == m.id);
    notifyListeners();
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

  /// Null-safe lookup — returns null if the thread no longer exists (e.g. it
  /// was replaced by a realtime refresh) instead of throwing.
  Thread? threadById(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Dealer opens (or starts) a chat with a listing's farmer. Returns the
  /// thread id to navigate to, or null on failure.
  Future<String?> startChat(Listing l) async {
    if (live) {
      try {
        final tid =
            await Backend.I.startThread(l.id, l.farmerId, l.crop, l.emoji);
        await reloadAll();
        return tid;
      } catch (e) {
        lastError = '$e';
        notifyListeners();
        return null;
      }
    }
    // mock: ensure a local thread and return its id
    _ensureThread(l.seller.name, 'Farmer', l.crop, l.emoji, mine: true);
    return threads
        .firstWhere((t) => t.name == l.seller.name && t.crop == l.crop)
        .id;
  }

  void sendMessage(Thread t, String text, {String? audioUrl, String? transcript, String? translatedText}) {
    t.messages.add(Message(
      id: _id('m'),
      mine: true,
      time: 'now',
      text: audioUrl != null ? null : text,
      audioUrl: audioUrl,
      transcript: transcript,
      translatedText: translatedText,
    ));
    notifyListeners();
    if (live) {
      _live(() => Backend.I.sendMessage(
            t.id,
            text,
            audioUrl: audioUrl,
            transcript: transcript,
            translatedText: translatedText,
          ));
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
  Future<void> postRequirement({
    required Crop crop,
    required double qty,
    required Unit unit,
    required int priceMin,
    required int priceMax,
    required int neededInDays,
  }) async {
    if (live) {
      final cropId = cropIds[crop.name];
      if (cropId == null) {
        throw Exception('Crop list not loaded yet — pull to refresh and retry.');
      }
      await Backend.I.postRequirement(
        cropId: cropId,
        qty: qty,
        unit: unit,
        priceMin: priceMin,
        priceMax: priceMax,
        neededInDays: neededInDays,
      );
      await reloadAll();
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

  Future<void> deleteListing(Listing l) async {
    if (live) {
      await Backend.I.deleteListing(l.id);
      await reloadAll();
      return;
    }
    myListings.removeWhere((x) => x.id == l.id);
    notifyListeners();
  }

  Future<void> deleteRequirement(BuyRequirement r) async {
    if (live) {
      await Backend.I.deleteRequirement(r.id);
      await reloadAll();
      return;
    }
    requirements.removeWhere((x) => x.id == r.id);
    notifyListeners();
  }

  /// Farmer responds to a dealer's requirement; returns the chat thread id.
  Future<String?> respondToRequirement(BuyRequirement r) async {
    if (live) {
      final tid = await Backend.I.respondToRequirement(r.id);
      await refreshThreads();
      return tid;
    }
    // mock: fabricate a local thread so the chat opens
    final tid = _id('th');
    threads.insert(
      0,
      Thread(
        id: tid,
        name: 'Buyer',
        role: 'Dealer',
        crop: r.crop,
        emoji: r.emoji,
        messages: [
          Message(
            id: _id('m'),
            mine: true,
            time: 'Just now',
            text: 'Hi, I can supply your ${r.crop} requirement.',
          ),
        ],
      ),
    );
    notifyListeners();
    return tid;
  }

  // ── helpers ───────────────────────────────
  /// Great-circle distance in km — free, local, instant (no Distance Matrix API).
  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

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

  String getTranslated(String key) {
    final code = _langCode(language);
    final dict = _i18n[code] ?? _i18n['en']!;
    return dict[key] ?? _i18n['en']![key] ?? key;
  }

  static String _langCode(String l) {
    return switch (l.toLowerCase()) {
      'kannada' => 'kn',
      'hindi' => 'hi',
      'telugu' => 'te',
      'tamil' => 'ta',
      'malayalam' => 'ml',
      'marathi' => 'mr',
      'gujarati' => 'gu',
      'bengali' => 'bn',
      'punjabi' => 'pa',
      'odia' => 'or',
      'assamese' => 'as',
      'urdu' => 'ur',
      _ => 'en',
    };
  }

  static const Map<String, Map<String, String>> _i18n = {
    'en': {
      'search_crops': 'Search crops...',
      'pincode_label': 'PIN Code',
      'use_gps': 'Use GPS Location',
      'village': 'Village',
      'taluk': 'Taluk/Tehsil',
      'district': 'District',
      'state': 'State',
      'country': 'Country',
      'publish_listing': 'Publish Listing',
      'voice_hold_to_record': 'Hold mic button to record',
      'voice_cancel_drag': 'Release to send, slide left to delete',
      'delete_voice': 'Delete',
      'transcription': 'Original transcript',
      'translation': 'Translation',
      'distance_away': 'away',
      'language_settings': 'Language Settings',
      'preferred_locations': 'Preferred Buying Locations',
      'radius': 'Radius',
      'add_location': 'Add Location',
      'save': 'Save',
      'delete': 'Delete',
      'farmer_label': 'Farmer',
      'dealer_label': 'Dealer',
      'kyc_verified': 'KYC Verified',
      'my_listings': 'My Listings',
      'all_listings': 'Marketplace',
      'create_new_listing': 'Create Listing',
      'expected_price': 'Expected Price',
      'quantity': 'Quantity',
      'dealer_match_title': 'Dealer Match',
      'dealer_match_body': '{count} dealers are interested in your listing.',
      'cat_all': 'All',
      'cat_live': 'Live',
      'cat_offers': 'Offers',
      'cat_sold': 'Sold',
      'search_produce': 'Search your produce...',
      'live_mandi_subtitle': 'Live mandi prices',
      'todays_mandi_price': "Today's mandi price",
      'mandi_price_subtitle': 'Live · eNAM / Agmarknet',
      'your_listings': 'Your listings',
      'active_count': '{count} active',
      'empty_listings_hint': 'Nothing here — tap “List produce” to add a crop.',
      'activity_title': 'Activity',
      'no_activity': 'No activity yet.',
    },
    'kn': {
      'search_crops': 'ಬೆಳೆಗಳನ್ನು ಹುಡುಕಿ...',
      'pincode_label': 'ಪಿನ್ ಕೋಡ್',
      'use_gps': 'ಜಿಪಿಎಸ್ ಸ್ಥಳ ಬಳಸಿ',
      'village': 'ಗ್ರಾಮ',
      'taluk': 'ತಾಲೂಕು',
      'district': 'ಜಿಲ್ಲೆ',
      'state': 'ರಾಜ್ಯ',
      'country': 'ದೇಶ',
      'publish_listing': 'ಪಟ್ಟಿ ಪ್ರಕಟಿಸಿ',
      'voice_hold_to_record': 'ರೆಕಾರ್ಡ್ ಮಾಡಲು ಒತ್ತಿ ಹಿಡಿಯಿರಿ',
      'voice_cancel_drag': 'ರದ್ದುಗೊಳಿಸಲು ಎಳೆಯಿರಿ',
      'delete_voice': 'ಕಳುಹಿಸುವ ಮುನ್ನ ಅಳಿಸಿ',
      'transcription': 'ಪ್ರತಿಲಿಪಿ',
      'translation': 'ಅನುವಾದ',
      'distance_away': 'ದೂರ',
      'language_settings': 'ಭಾಷಾ ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
      'preferred_locations': 'ಆದ್ಯತೆಯ ಖರೀදි ಸ್ಥಳಗಳು',
      'radius': 'ತ್ರಿಜ್ಯ',
      'add_location': 'ಸ್ಥಳ ಸೇರಿಸಿ',
      'save': 'ಉಳಿಸಿ',
      'delete': 'ಅಳಿಸಿ',
      'farmer_label': 'ರೈತ',
      'dealer_label': 'ವ್ಯಾಪಾರಿ',
      'kyc_verified': 'ಕೆವೈಸಿ ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
      'my_listings': 'ನನ್ನ ಪಟ್ಟಿಗಳು',
      'all_listings': 'ಮಾರುಕಟ್ಟೆ',
      'create_new_listing': 'ಹೊಸ ಪಟ್ಟಿ ರಚಿಸಿ',
      'expected_price': 'ನಿರೀಕ್ಷಿತ ಬೆಲೆ',
      'quantity': 'ಪ್ರಮಾಣ',
      'dealer_match_title': 'ಖರೀදಿದಾರರ ಆಸಕ್ತಿ',
      'dealer_match_body': '{count} ಖರೀದಿದಾರರು ನಿಮ್ಮ ಬೆಳೆಗೆ ಆಸಕ್ತಿ ಹೊಂದಿದ್ದಾರೆ.',
      'cat_all': 'ಎಲ್ಲಾ',
      'cat_live': 'ಲೈವ್',
      'cat_offers': 'ಕೊಡುಗೆಗಳು',
      'cat_sold': 'ಮಾರಾಟವಾಗಿದೆ',
      'search_produce': 'ನಿಮ್ಮ ಬೆಳೆಯನ್ನು ಹುಡುಕಿ...',
      'live_mandi_subtitle': 'ಕೋಲಾರ, ಕರ್ನಾಟಕ · ಲೈವ್ ಮಾರುಕಟ್ಟೆ',
      'todays_mandi_price': 'ಇಂದಿನ ಮಾರುಕಟ್ಟೆ ಬೆಲೆ',
      'mandi_price_subtitle': 'ಲೈವ್ · eNAM · ಕೋಲಾರ ಎಪಿಎಂಸಿ',
      'your_listings': 'ನಿಮ್ಮ ಪಟ್ಟಿಗಳು',
      'active_count': '{count} ಸಕ್ರಿಯ',
      'empty_listings_hint': 'ಇಲ್ಲಿ ಏನೂ ಇಲ್ಲ — ಬೆಳೆಯನ್ನು ಸೇರಿಸಲು “ಬೆಳೆ ಪಟ್ಟಿ ಮಾಡಿ” ಟ್ಯಾಪ್ ಮಾಡಿ.',
      'activity_title': 'ಚಟುವಟಿಕೆ',
      'no_activity': 'ಇನ್ನೂ ಯಾವುದೇ ಚಟುವಟಿಕೆ ಇಲ್ಲ.',
    },
    'hi': {
      'search_crops': 'फसलें खोजें...',
      'pincode_label': 'पिन कोड',
      'use_gps': 'जीपीएस स्थान का उपयोग करें',
      'village': 'गांव',
      'taluk': 'तहसील/तालुका',
      'district': 'जिला',
      'state': 'राज्य',
      'country': 'देश',
      'publish_listing': 'सूची प्रकाशित करें',
      'voice_hold_to_record': 'रिकॉर्ड करने के लिए दबाकर रखें',
      'voice_cancel_drag': 'रद्द करने के लिए खींचें',
      'delete_voice': 'भेजने से पहले हटाएं',
      'transcription': 'ट्रांसक्रिप्शन',
      'translation': 'अनुवाद',
      'distance_away': 'दूर',
      'language_settings': 'भाषा सेटिंग्स',
      'preferred_locations': 'पसंदीदा खरीद स्थान',
      'radius': 'त्रिज्या',
      'add_location': 'स्थान जोड़ें',
      'save': 'सहेजें',
      'delete': 'हटाएं',
      'farmer_label': 'किसान',
      'dealer_label': 'व्यापारी',
      'kyc_verified': 'केवाईसी सत्यापित',
      'my_listings': 'मेरी सूचियां',
      'all_listings': 'बाज़ार',
      'create_new_listing': 'सूची बनाएं',
      'expected_price': 'अपेक्षित मूल्य',
      'quantity': 'मात्रा',
      'dealer_match_title': 'व्यापारी रुचि',
      'dealer_match_body': '{count} व्यापारी आपकी फसल में रुचि रखते हैं।',
      'cat_all': 'सभी',
      'cat_live': 'लाइव',
      'cat_offers': 'ऑफ़र',
      'cat_sold': 'बेचा गया',
      'search_produce': 'अपनी उपज खोजें...',
      'live_mandi_subtitle': 'कोलार, कर्नाटक · लाइव मंडी',
      'todays_mandi_price': 'आज का मंडी भाव',
      'mandi_price_subtitle': 'लाइव · eNAM · कोलार एपीएमसी',
      'your_listings': 'आपकी सूचियाँ',
      'active_count': '{count} सक्रिय',
      'empty_listings_hint': 'यहाँ कुछ नहीं है — फसल जोड़ने के लिए "उपज सूचीबद्ध करें" पर टैप करें।',
      'activity_title': 'गतिविधि',
      'no_activity': 'अभी तक कोई गतिविधि नहीं।',
    },
    'te': {
      'search_crops': 'పంటలను వెతకండి...',
      'pincode_label': 'పిన్ కోడ్',
      'use_gps': 'జీపీఎస్ స్థానాన్ని ఉపయోగించండి',
      'village': 'గ్రామం',
      'taluk': 'తాలూకా',
      'district': 'జిల్లా',
      'state': 'రాష్ట్రం',
      'country': 'దేశం',
      'publish_listing': 'జాబితాను ప్రచురించు',
      'voice_hold_to_record': 'రికార్డ్ చేయడానికి నొక్కి పట్టుకోండి',
      'voice_cancel_drag': 'రద్దు చేయడానికి లాగండి',
      'delete_voice': 'పంపే ముందు తొలగించండి',
      'transcription': 'ట్రాన్స్క్రిప్షన్',
      'translation': 'అనువాదం',
      'distance_away': 'దూరంలో',
      'language_settings': 'భాష సెట్టింగ్స్',
      'preferred_locations': 'ప్రాధాన్యత కొనుగోలు స్థలాలు',
      'radius': 'వ్యాసార్థం',
      'add_location': 'స్థానాన్ని జోడించు',
      'save': 'సేవ్ చేయి',
      'delete': 'తొలగించు',
      'farmer_label': 'రైతు',
      'dealer_label': 'డీలర్',
      'kyc_verified': 'KYC ధృవీకరించబడింది',
      'my_listings': 'నా జాబితాలు',
      'all_listings': 'మార్కెట్ ప్లేస్',
      'create_new_listing': 'జాబితాను సృష్టించు',
      'expected_price': 'ఆశించిన ధర',
      'quantity': 'పరిమాణం',
      'dealer_match_title': 'డీలర్ ఆసక్తి',
      'dealer_match_body': '{count} డీలర్లు మీ పంటపై ఆసక్తి చూపుతున్నారు.',
      'cat_all': 'అన్నీ',
      'cat_live': 'లైవ్',
      'cat_offers': 'ఆఫర్లు',
      'cat_sold': 'అమ్ముడైనవి',
      'search_produce': 'మీ పంటను వెతకండి...',
      'live_mandi_subtitle': 'కోలਾਰ, కర్ణాటక · లైవ్ మండి',
      'todays_mandi_price': 'నేటి మండి ధర',
      'mandi_price_subtitle': 'లైవ్ · eNAM · కోలార్ APMC',
      'your_listings': 'మీ జాబితాలు',
      'active_count': '{count} యాక్టివ్',
      'empty_listings_hint': 'ఇక్కడ ఏమీ లేదు — పంటను జోడించడానికి "పంటను నమోదు చేయి" నొక్కండి.',
      'activity_title': 'కార్యకలాపాలు',
      'no_activity': 'ఇంకా ఎటువంటి కార్యకలాపాలు లేవు.',
    },
    'ta': {
      'search_crops': 'பயிர்களைத் தேடுங்கள்...',
      'pincode_label': 'அஞ்சல் குறியீடு',
      'use_gps': 'தற்போதைய ஜிபிஎஸ் இருப்பிடத்தைப் பயன்படுத்து',
      'village': 'கிராமம்',
      'taluk': 'வட்டம்/தாலுகா',
      'district': 'மாவட்டம்',
      'state': 'மாநிலம்',
      'country': 'நாடு',
      'publish_listing': 'பட்டியலை வெளியிடு',
      'voice_hold_to_record': 'பதிவு செய்ய அழுத்திப் பிடிக்கவும்',
      'voice_cancel_drag': 'ரத்து செய்ய இழுக்கவும்',
      'delete_voice': 'அனுப்பும் முன் நீக்குக',
      'transcription': 'உரைபெயர்ப்பு',
      'translation': 'மொழிபெயர்ப்பு',
      'distance_away': 'தொலைவில்',
      'language_settings': 'மொழி அமைப்புகள்',
      'preferred_locations': 'விருப்பமான கொள்முதல் இருப்பிடங்கள்',
      'radius': 'சுற்றளவு',
      'add_location': 'இருப்பிடத்தைச் சேர்',
      'save': 'சேமி',
      'delete': 'நீக்கு',
      'farmer_label': 'விவசாயி',
      'dealer_label': 'வியாபாரி',
      'kyc_verified': 'KYC சரிபார்க்கப்பட்டது',
      'my_listings': 'எனது பட்டியல்கள்',
      'all_listings': 'சந்தை',
      'create_new_listing': 'பட்டியலை உருவாக்கு',
      'expected_price': 'எதிர்பார்க்கும் விலை',
      'quantity': 'அளவு',
      'dealer_match_title': 'வியாபாரி ஆர்வம்',
      'dealer_match_body': '{count} வியாபாரிகள் உங்கள் பயிரில் ஆர்வம் காட்டுகின்றனர்.',
    },
    'ml': {
      'search_crops': 'വിളകൾ തിരയുക...',
      'pincode_label': 'പിൻ കോഡ്',
      'use_gps': 'നിലവിലെ ജിപിഎസ് ലൊക്കേഷൻ ഉപയോഗിക്കുക',
      'village': 'ഗ്രാമം',
      'taluk': 'താലൂക്ക്',
      'district': 'ജില്ല',
      'state': 'സംസ്ഥാനം',
      'country': 'രാജ്യം',
      'publish_listing': 'লিষ্টিং പ്രസിദ്ധീകരിക്കുക',
      'voice_hold_to_record': 'റെക്കോർഡ് ചെയ്യാൻ അമർത്തിപ്പിടിക്കുക',
      'voice_cancel_drag': 'രദ്ദാക്കാൻ വലിക്കുക',
      'delete_voice': 'ഇല്ലാതാക്കുക',
      'transcription': 'ട്രാൻസ്ക്രിപ്ഷൻ',
      'translation': 'വിവർത്തനം',
      'distance_away': 'അകലെ',
      'language_settings': 'ഭാഷാ ക്രമീകരണങ്ങൾ',
      'preferred_locations': 'ആദ്യത്തെ വാങ്ങൽ സ്ഥലങ്ങൾ',
      'radius': 'വ്യാപ്തി',
      'add_location': 'സ്ഥലം ചേർക്കുക',
      'save': 'സൂക്ഷിക്കുക',
      'delete': 'ഇല്ലാതാക്കുക',
      'farmer_label': 'കർഷകൻ',
      'dealer_label': 'വ്യാപാരി',
      'kyc_verified': 'KYC വെരിഫൈഡ്',
      'my_listings': 'എന്റെ ലിസ്റ്റിംഗുകൾ',
      'all_listings': 'മാർക്കറ്റ്',
      'create_new_listing': 'ലിസ്റ്റിംഗ് ഉണ്ടാക്കുക',
      'expected_price': 'പ്രതീക്ഷിക്കുന്ന വില',
      'quantity': 'അളവ്',
      'dealer_match_title': 'വ്യാപാരി താല്പര്യം',
      'dealer_match_body': '{count} വ്യാപാരികൾ നിങ്ങളുടെ വിളയിൽ താല്പര്യം കാണിക്കുന്നു.',
      'cat_all': 'എല്ലാം',
      'cat_live': 'ലൈവ്',
      'cat_offers': 'ഓഫറുകൾ',
      'cat_sold': 'വിറ്റുപോയത്',
      'search_produce': 'നിങ്ങളുടെ വിള തിരയുക...',
      'live_mandi_subtitle': 'കോലാർ, കർണാടക · ലൈവ് മണ്ടി',
      'todays_mandi_price': 'ഇന്നത്തെ മണ്ടി വില',
      'mandi_price_subtitle': 'ലൈവ് · eNAM · കോലാർ APMC',
      'your_listings': 'നിങ്ങളുടെ ലിസ്റ്റിംഗുകൾ',
      'active_count': '{count} സജീവം',
      'empty_listings_hint': 'ഇവിടെ ഒന്നുമില്ല — ഒരു വിള ചേർക്കാൻ "ലിസ്റ്റിംഗ് ഉണ്ടാക്കുക" ടാപ്പ് ചെയ്യുക.',
      'activity_title': 'പ്രവർത്തനം',
      'no_activity': 'പ്രവർത്തനങ്ങളൊന്നുമില്ല.',
    },
    'mr': {
      'search_crops': 'पके शोधा...',
      'pincode_label': 'पिन कोड',
      'use_gps': 'सध्याचे जीपीएस स्थान वापरा',
      'village': 'गाव',
      'taluk': 'तालुका',
      'district': 'जिल्हा',
      'state': 'राज्य',
      'country': 'देश',
      'publish_listing': 'यादी प्रकाशित करा',
      'voice_hold_to_record': 'रेकॉर्ड करण्यासाठी धरून ठेवा',
      'voice_cancel_drag': 'रद्द करण्यासाठी ड्रॅग करा',
      'delete_voice': 'पाठवण्यापूर्वी हटवा',
      'transcription': 'ट्रान्सक्रिप्शन',
      'translation': 'अनुवाद',
      'distance_away': 'अंतरावर',
      'language_settings': 'भाषा सेटिंग्ज',
      'preferred_locations': 'खरेदीची आवडती ठिकाणे',
      'radius': 'त्रिज्या',
      'add_location': 'ठिकाण जोडा',
      'save': 'जतन करा',
      'delete': 'हटवा',
      'farmer_label': 'शेतकरी',
      'dealer_label': 'व्यापारी',
      'kyc_verified': 'केवायसी सत्यापित',
      'my_listings': 'माझ्या याद्या',
      'all_listings': 'बाजारपेठ',
      'create_new_listing': 'नवीन यादी तयार करा',
      'expected_price': 'अपेक्षित किंमत',
      'quantity': 'प्रमाण',
      'dealer_match_title': 'व्यापारी आवड',
      'dealer_match_body': '{count} व्यापारी आपल्या पिकात रस दाखवत आहेत.',
      'cat_all': 'सर्व',
      'cat_live': 'लाइव्ह',
      'cat_offers': 'ऑफर्स',
      'cat_sold': 'विकले गेले',
      'search_produce': 'तुमचे पीक शोधा...',
      'live_mandi_subtitle': 'कोलार, कर्नाटक · लाईव्ह मंडी',
      'todays_mandi_price': 'आजचा मंडी भाव',
      'mandi_price_subtitle': 'लाइव्ह · eNAM · कोलार एपीएमसी',
      'your_listings': 'तुमच्या याद्या',
      'active_count': '{count} सक्रिय',
      'empty_listings_hint': 'इथे काहीही नाही — पीक जोडण्यासाठी "नवीन यादी तयार करा" वर टॅप करा.',
      'activity_title': 'हालचाली',
      'no_activity': 'अद्याप कोणतीही हालचाल नाही.',
    },
    'gu': {
      'search_crops': 'પાક શોધો...',
      'pincode_label': 'પિન કોડ',
      'use_gps': 'વર્તમાન જીપીએસ સ્થાન વાપરો',
      'village': 'ગામ',
      'taluk': 'તાલુકો',
      'district': 'જીલ્લો',
      'state': 'રાજ્ય',
      'country': 'દેશ',
      'publish_listing': 'યાદી પ્રકાશિત કરો',
      'voice_hold_to_record': 'રેકોર્ડ કરવા માટે દબાવી રાખો',
      'voice_cancel_drag': 'રદ કરવા માટે ખેંચો',
      'delete_voice': 'મોકલતા પહેલા કાઢી નાખો',
      'transcription': 'ટ્રાન્સક્રિપ્શન',
      'translation': 'અનુવાદ',
      'distance_away': 'દૂર',
      'language_settings': 'ભાષા સેટિંગ્સ',
      'preferred_locations': 'મનપસંદ સ્થાનો',
      'radius': 'ત્રિજ્યા',
      'add_location': 'સ્થાન ઉમેરો',
      'save': 'સાચવો',
      'delete': 'કાઢી નાખો',
      'farmer_label': 'ખેડૂત',
      'dealer_label': 'વેપારી',
      'kyc_verified': 'KYC ચકાસાયેલ',
      'my_listings': 'મારી યાદીઓ',
      'all_listings': 'બજાર',
      'create_new_listing': 'નવી યાદી બનાવો',
      'expected_price': 'અપેક્ષિત કિંમત',
      'quantity': 'જથ્થો',
      'dealer_match_title': 'વેપારી રસ',
      'dealer_match_body': '{count} વેપારીઓ તમારા પાકમાં રસ દર્શાવી રહ્યા છે.',
      'cat_all': 'બધા',
      'cat_live': 'લાઈવ',
      'cat_offers': 'ઑફર્સ',
      'cat_sold': 'વેચાયેલ',
      'search_produce': 'તમારા પાકની શોધ કરો...',
      'live_mandi_subtitle': 'કોલાર, કર્ણાટક · લાઈવ મંડી',
      'todays_mandi_price': 'આજનો મંડી ભાવ',
      'mandi_price_subtitle': 'લાઈવ · eNAM · કોલાર એપીએમસી',
      'your_listings': 'તમારી યાદીઓ',
      'active_count': '{count} સક્રિય',
      'empty_listings_hint': 'અહીં કંઈ નથી — નવો પાક ઉમેરવા "નવી યાદી બનાવો" પર ટેપ કરો.',
      'activity_title': 'પ્રવૃત્તિ',
      'no_activity': 'હજી સુધી કોઈ પ્રવૃત્તિ નથી.',
    },
    'bn': {
      'search_crops': 'ফসল খুঁজুন...',
      'pincode_label': 'পিন কোড',
      'use_gps': 'বর্তমান জিপিএস অবস্থান ব্যবহার করুন',
      'village': 'গ্রাম',
      'taluk': 'থানা/উপজেলা',
      'district': 'জেলা',
      'state': 'রাজ্য',
      'country': 'দেশ',
      'publish_listing': 'তালিকা প্রকাশ করুন',
      'voice_hold_to_record': 'রেকর্ড করতে চেপে রাখুন',
      'voice_cancel_drag': 'বাতিল করতে টানুন',
      'delete_voice': 'পাঠানোর আগে মুছুন',
      'transcription': 'অনুলিপি',
      'translation': 'অনুবাদ',
      'distance_away': 'দূরে',
      'language_settings': 'ভাষা সেটিংস',
      'preferred_locations': 'পছন্দের কেনার জায়গা',
      'radius': 'ব্যাসার্ধ',
      'add_location': 'জায়ગા যোগ করুন',
      'save': 'সংরক্ষণ করুন',
      'delete': 'মুছে ফেলুন',
      'farmer_label': 'কৃষক',
      'dealer_label': 'ব্যবসায়ী',
      'kyc_verified': 'KYC যাচাইকৃত',
      'my_listings': 'আমার তালিকা',
      'all_listings': 'বাজার',
      'create_new_listing': 'তালিকা তৈরি করুন',
      'expected_price': 'প্রত্যাশিত মূল্য',
      'quantity': 'পরিমাণ',
      'dealer_match_title': 'ব্যবসায়ী আগ্রহ',
      'dealer_match_body': '{count} জন ব্যবসায়ী আপনার ফসলে আগ্রহী।',
      'cat_all': 'সব',
      'cat_live': 'লাইভ',
      'cat_offers': 'অফার',
      'cat_sold': 'বিক্রিত',
      'search_produce': 'আপনার ফসল খুঁজুন...',
      'live_mandi_subtitle': 'কোলার, কর্ণাটক · লাইভ মান্ডি',
      'todays_mandi_price': 'আজকের মান্ডি দর',
      'mandi_price_subtitle': 'লাইভ · eNAM · কোলার এপিএমসি',
      'your_listings': 'আপনার তালিকা',
      'active_count': '{count} টি সক্রিয়',
      'empty_listings_hint': 'এখানে কিছু নেই — ফসল যোগ করতে "তালিকা তৈরি করুন" এ আলতো চাপুন।',
      'activity_title': 'কার্যক্রম',
      'no_activity': 'এখনও কোনো কার্যক্রম নেই।',
    },
    'pa': {
      'search_crops': 'ਫ਼ਸਲਾਂ ਦੀ ਖੋਜ ਕਰੋ...',
      'pincode_label': 'ਪਿੰਨ ਕੋਡ',
      'use_gps': 'ਮੌਜੂਦਾ ਜੀਪੀਐਸ ਸਥਾਨ ਵਰਤੋਂ',
      'village': 'ਪਿੰਡ',
      'taluk': 'ਤਹਿਸੀਲ',
      'district': 'ਜ਼ਿਲ੍ਹਾ',
      'state': 'ਰਾਜ',
      'country': 'ਦੇਸ਼',
      'publish_listing': 'ਸੂਚੀ ਪ੍ਰਕਾਸ਼ਿਤ ਕਰੋ',
      'voice_hold_to_record': 'ਰਿਕਾਰਡ ਕਰਨ ਲਈ ਦਬਾ ਕੇ ਰੱਖੋ',
      'voice_cancel_drag': 'ਰੱਦ ਕਰਨ ਲਈ ਖਿੱਚੋ',
      'delete_voice': 'ਭੇਜਣ ਤੋਂ ਪਹਿਲਾਂ ਮਿਟਾਓ',
      'transcription': 'ਟ੍ਰਾਂਸਕ੍ਰਿਪਸ਼ਨ',
      'translation': 'ਅਨੁਵਾਦ',
      'distance_away': 'ਦੂਰ',
      'language_settings': 'ਭਾਸ਼ਾ ਸੈਟਿੰਗਜ਼',
      'preferred_locations': 'ਪਸੰਦੀਦਾ ਖਰੀਦ ਸਥਾਨ',
      'radius': 'ਘੇਰਾ',
      'add_location': 'ਸਥਾਨ ਜੋੜੋ',
      'save': 'ਸੁਰੱਖਿਅਤ ਕਰੋ',
      'delete': 'ਮਿਟਾਓ',
      'farmer_label': 'ਕਿਸਾਨ',
      'dealer_label': 'ਵਪਾਰੀ',
      'kyc_verified': 'KYC ਵੈਰੀਫਾਈਡ',
      'my_listings': 'ਮੇਰੀਆਂ ਸੂਚੀਆਂ',
      'all_listings': 'ਮਾਰਕੀਟ',
      'create_new_listing': 'ਸੂਚੀ ਬਣਾਓ',
      'expected_price': 'ਉਮੀਦ ਕੀਤੀ ਕੀਮਤ',
      'quantity': 'ਮਾਤਰਾ',
      'dealer_match_title': 'ਡੀਲਰ ਦੀ ਦਿਲਚਸਪੀ',
      'dealer_match_body': '{count} ਡੀਲਰ ਤੁਹਾਡੀ ਫਸਲ ਵਿੱਚ ਦਿਲਚਸਪੀ ਰੱਖਦੇ ਹਨ।',
      'cat_all': 'ਸਭ',
      'cat_live': 'ਲਾਈਵ',
      'cat_offers': 'ਆਫਰ',
      'cat_sold': 'ਵੇਚਿਆ ਗਿਆ',
      'search_produce': 'ਆਪਣੀ ਫਸਲ ਲੱਭੋ...',
      'live_mandi_subtitle': 'ਕੋਲਾਰ, ਕਰਨਾਟਕ · ਲਾਈਵ ਮੰਡੀ',
      'todays_mandi_price': 'ਅੱਜ ਦਾ ਮੰਡੀ ਭਾਅ',
      'mandi_price_subtitle': 'ਲਾਈਵ · eNAM · ਕੋਲਾਰ ਏ.ਪੀ.ਐਮ.ਸੀ.',
      'your_listings': 'ਤੁਹਾਡੀਆਂ ਸੂਚੀਆਂ',
      'active_count': '{count} ਸਰਗਰਮ',
      'empty_listings_hint': 'ਇੱਥੇ ਕੁਝ ਨਹੀਂ ਹੈ — ਫਸਲ ਜੋੜਨ ਲਈ "ਸੂਚੀ ਬਣਾਓ" ਤੇ ਟੈਪ ਕਰੋ।',
      'activity_title': 'ਗਤੀਵਿਧੀ',
      'no_activity': 'ਅਜੇ ਕੋਈ ਗਤੀਵਿਧੀ ਨਹੀਂ ਹੈ।',
    },
    'or': {
      'search_crops': 'ଫସଲ ଖୋଜନ୍ତୁ...',
      'pincode_label': 'ପିନ୍ କୋଡ୍',
      'use_gps': 'ଜିପିଏସ୍ ସ୍ଥାନ ବ୍ୟਵହାର କରନ୍ତು',
      'village': 'ଗ୍ରାମ',
      'taluk': 'ତହସିଲ୍',
      'district': 'ଜିଲ୍ଲା',
      'state': 'ରାଜ୍ୟ',
      'country': 'ଦେଶ',
      'publish_listing': 'ତାଲିକା ପ୍ରକାଶ କରନ୍ତୁ',
      'voice_hold_to_record': 'ਰੇକର୍ଡ କରିବାକୁ ଦବାଇ ରଖନ୍ତು',
      'voice_cancel_drag': 'ବାତିଲ୍ କରିବାକୁ ଟାଣନ୍ତು',
      'delete_voice': 'ପଠାଇବା ପୂର୍ବରୁ ବିଲୋପ କରନ୍ତು',
      'transcription': 'ଲିପ୍ୟନ୍ତରଣ',
      'translation': 'ଅନୁବାଦ',
      'distance_away': 'ଦୂର',
      'language_settings': 'ଭାଷା ସେଟିଙ୍ଗ୍ସ',
      'preferred_locations': 'ਪସନ୍ଦର କ୍ରୟ ସ୍ଥାନ',
      'radius': 'ବ୍ୟାସାର୍ଦ୍ଧ',
      'add_location': 'ସ୍ଥାନ ଯୋଡନ୍ତୁ',
      'save': 'ସଂରକ୍ଷଣ କରନ୍ତು',
      'delete': 'ବିଲୋପ କരନ୍ତು',
      'farmer_label': 'କୃଷକ',
      'dealer_label': 'ବ୍ୟବସାୟୀ',
      'kyc_verified': 'KYC ଯାଞ୍ચ ହୋଇଛି',
      'my_listings': 'ମୋର ତାଲିକା',
      'all_listings': 'ବଜାର',
      'create_new_listing': 'ତାଲିକା ପ୍ରସ୍ତուତ କରନ୍ତು',
      'expected_price': 'ଆଶାୟୀ ମୂଲ୍ୟ',
      'quantity': 'ପରିମାଣ',
      'dealer_match_title': 'ବ୍ୟବସାୟୀଙ୍କ ଆଗ୍ରহ',
      'dealer_match_body': '{count} ବ୍ୟବସାୟୀ ଆପଣଙ୍କ ଫସଲରେ ଆଗ୍ରହୀ ଅଛନ୍ତି।',
    },
    'as': {
      'search_crops': 'শস্য অনুসন্ধান কৰক...',
      'pincode_label': 'পিন ক’ড',
      'use_gps': 'বৰ্তমানৰ জিপিএছ স্থান ব্যৱহাৰ কৰক',
      'village': 'গাঁও',
      'taluk': 'মহকুমা/তহচিল',
      'district': 'জিলা',
      'state': 'ৰাজ্য',
      'country': 'দেশ',
      'publish_listing': 'তালিকা প্ৰকাশ কৰক',
      'voice_hold_to_record': 'ৰেকৰ্ড কৰিবলৈ টিপি ধৰক',
      'voice_cancel_drag': 'বাতিল কৰিবলৈ টানক',
      'delete_voice': 'পঠোৱাৰ আগতে মচক',
      'transcription': 'প্ৰতিলিপি',
      'translation': 'অনুবাদ',
      'distance_away': 'দূৰত',
      'language_settings': 'ভাষা সংহতি',
      'preferred_locations': 'পছন্দৰ ক্ৰয় স্থানসমূহ',
      'radius': 'ব্যাসাৰ্ধ',
      'add_location': 'স্থান যোগ কৰক',
      'save': 'সংৰক্ষণ কৰক',
      'delete': 'মচি পেলাওক',
      'farmer_label': 'কৃষক',
      'dealer_label': 'ব্যৱসায়ী',
      'kyc_verified': 'KYC পৰীক্ষিত',
      'my_listings': 'মোৰ তালিকাসমূহ',
      'all_listings': 'বজাৰ',
      'create_new_listing': 'তালিকা সৃষ্টি কৰক',
      'expected_price': 'প্ৰত্যাশিত মূল্য',
      'quantity': 'পৰিমাণ',
      'dealer_match_title': 'ব্যৱসায়ীৰ আগ্ৰহ',
      'dealer_match_body': '{count} গৰাকী ব্যৱসায়ী আপোনাৰ শস্যৰ প্ৰতি আগ্ৰহী।',
    },
    'ur': {
      'search_crops': 'فصلیں تلاش کریں...',
      'pincode_label': 'پن کوڈ',
      'use_gps': 'موجودہ جی پی ایس مقام استعمال کریں',
      'village': 'گاؤں',
      'taluk': 'تحصیل',
      'district': 'ضلع',
      'state': 'ریاست',
      'country': 'ملک',
      'publish_listing': 'فهرست شائع کریں',
      'voice_hold_to_record': 'ریکارڈ کرنے کے لیے دبائے رکھیں',
      'voice_cancel_drag': 'منسوخ کرنے کے لیے گھسیٹیں',
      'delete_voice': 'بھیجنے سے پہلے حذف کریں',
      'transcription': 'تحریر',
      'translation': 'ترجمہ',
      'distance_away': 'دور',
      'language_settings': 'زبان کی ترتیبات',
      'preferred_locations': 'پسندیدہ خریداری کے مقامات',
      'radius': 'نصف قطر',
      'add_location': 'مقام शामिल کریں',
      'save': 'محفوظ کریں',
      'delete': 'حذف کریں',
      'farmer_label': 'کسان',
      'dealer_label': 'ڈیلر',
      'kyc_verified': 'KYC تصدیق شدہ',
      'my_listings': 'मेरी فہرستیں',
      'all_listings': 'مارکیٹ',
      'create_new_listing': 'فهرست بنائیں',
      'expected_price': 'متوقع قیمت',
      'quantity': 'مقدار',
      'dealer_match_title': 'ڈیلر کی دلچسپی',
      'dealer_match_body': '{count} ڈیلر آپ کی فصل میں دلچسپی رکھتے ہیں۔',
    }
  };
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
