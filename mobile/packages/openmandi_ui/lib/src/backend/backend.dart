import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../models/trade.dart';
import 'config.dart';

/// Thin, typed wrapper over Supabase: auth (email OTP), data loads, the
/// server-side trade RPCs, storage, and realtime. Only used in live mode
/// ([AppConfig.isLive]); the in-memory store is the offline fallback.
class Backend {
  Backend._();
  static final Backend I = Backend._();

  SupabaseClient get _db => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // The "anon"/publishable key is safe on the client; RLS protects data.
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  // ── auth (email OTP) ──────────────────────────────────────
  String? get uid => _db.auth.currentUser?.id;
  bool get signedIn => _db.auth.currentSession != null;
  Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

  Future<void> sendEmailOtp(String email,
      {required Role role, required String fullName}) {
    return _db.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
      data: {'role': role.name, 'full_name': fullName},
    );
  }

  Future<void> verifyEmailOtp(String email, String token) async {
    await _db.auth.verifyOTP(type: OtpType.email, email: email, token: token);
  }

  // Password auth (no email verification needed when "Confirm email" is OFF in
  // the Supabase dashboard). Sign up; if the account already exists, sign in.
  Future<void> signUpOrIn(String email, String password,
      {required Role role, required String fullName}) async {
    try {
      final res = await _db.auth.signUp(
        email: email,
        password: password,
        data: {'role': role.name, 'full_name': fullName},
      );
      if (res.session == null) {
        // confirmation likely still on, or user existed — try password sign-in
        await _db.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException {
      await _db.auth.signInWithPassword(email: email, password: password);
    }
  }

  Future<void> signOut() => _db.auth.signOut();

  // ── profile / kyc ─────────────────────────────────────────
  Future<Map<String, dynamic>?> myUserRow() async {
    final id = uid;
    if (id == null) return null;
    return _db.from('users').select().eq('id', id).maybeSingle();
  }

  Future<void> updateMyName(String name) async {
    final id = uid;
    if (id == null) return;
    await _db.from('users').update({'full_name': name}).eq('id', id);
  }

  Future<void> submitFarmerKyc(
      {required String panLast4, required String aadhaarLast4}) async {
    final id = uid!;
    await _db.from('farmer_profiles').upsert({
      'user_id': id,
      'pan_last4': panLast4,
      'aadhaar_last4': aadhaarLast4,
      'consent_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _db.rpc('dev_autoverify_kyc'); // production: real provider via Express
  }

  Future<void> submitDealerKyc(
      {required String gstNumber, required String aadhaarLast4}) async {
    final id = uid!;
    await _db.from('dealer_profiles').upsert({
      'user_id': id,
      'gst_number': gstNumber,
      'aadhaar_last4': aadhaarLast4,
      'consent_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _db.rpc('dev_autoverify_kyc');
  }

  // ── reference data ────────────────────────────────────────
  /// Raw crop rows (id, name, emoji) — the store builds the [Crop] list and a
  /// name→id map (the UI's [Crop] model carries no DB id).
  Future<List<Map<String, dynamic>>> loadCropRows() async {
    final rows = await _db.from('crops').select('id, name, emoji').order('name');
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<MarketPrice>> loadPrices() async {
    final rows = await _db
        .from('price_records')
        .select('price_modal, crops(name, emoji)')
        .order('date', ascending: false)
        .limit(20);
    return [
      for (final r in rows)
        MarketPrice(
          (r['crops']?['name'] ?? '') as String,
          (r['crops']?['emoji'] ?? '🌱') as String,
          (r['price_modal'] ?? 0) as int,
          0,
        ),
    ];
  }

  // ── listings ──────────────────────────────────────────────
  Future<List<Listing>> loadMarketListings() async {
    final rows = await _db
        .from('listings')
        .select('*, crops(name, emoji)')
        .eq('status', 'live')
        .order('created_at', ascending: false);
    final sellerNames = await _sellerLookup(
        {for (final r in rows) r['farmer_id'] as String});
    return [for (final r in rows) _listing(r, sellerNames)];
  }

  Future<List<Listing>> loadMyListings() async {
    final id = uid;
    if (id == null) return [];
    final rows = await _db
        .from('listings')
        .select('*, crops(name, emoji)')
        .eq('farmer_id', id)
        .order('created_at', ascending: false);
    final names = await _sellerLookup({id});
    return [for (final r in rows) _listing(r, names)];
  }

  Future<Map<String, Map<String, dynamic>>> _sellerLookup(
      Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _db
        .from('profiles_public')
        .select()
        .inFilter('id', ids.toList());
    return {for (final r in rows) r['id'] as String: r};
  }

  Future<String> createListing({
    required String cropId,
    required double qty,
    required Unit unit,
    required Grade grade,
    required bool organic,
    required int price,
    required int marketPrice,
    required int harvestInDays,
    List<String> photos = const [],
  }) async {
    final id = uid!;
    final res = await _db
        .from('listings')
        .insert({
          'farmer_id': id,
          'crop_id': cropId,
          'quantity': qty,
          'unit': unit.name,
          'quality_grade': grade.label,
          'is_organic': organic,
          'expected_price': price,
          'market_price': marketPrice,
          'photos': photos,
          'location_label': 'Kolar',
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // ── trade RPCs ────────────────────────────────────────────
  Future<String> makeOffer(String listingId, int price, double qty) async {
    final r = await _db.rpc('make_offer',
        params: {'p_listing': listingId, 'p_price': price, 'p_qty': qty});
    return r as String;
  }

  Future<String> acceptOffer(String offerId) async {
    final r = await _db.rpc('accept_offer', params: {'p_offer': offerId});
    return r as String;
  }

  Future<void> advanceOrder(String orderId) =>
      _db.rpc('advance_order', params: {'p_order': orderId});
  Future<void> completeOrder(String orderId) =>
      _db.rpc('complete_order', params: {'p_order': orderId});

  // ── orders / notifications / chat ─────────────────────────
  Future<List<Order>> loadOrders() async {
    final rows =
        await _db.from('orders').select().order('created_at', ascending: false);
    return [for (final r in rows) _order(r)];
  }

  /// Pending offers on the current farmer's listings.
  Future<List<Offer>> loadIncomingOffers() async {
    final id = uid;
    if (id == null) return [];
    final rows = await _db
        .from('offers')
        .select('*, threads!inner(farmer_id, dealer_id, crop_label, emoji)')
        .eq('threads.farmer_id', id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        Offer(
          id: r['id'] as String,
          listingId: (r['listing_id'] ?? '') as String,
          crop: (r['threads']?['crop_label'] ?? '') as String,
          emoji: (r['threads']?['emoji'] ?? '🌱') as String,
          party: 'Dealer',
          partyRole: 'Dealer',
          price: (r['price'] ?? 0) as int,
          qty: (r['quantity'] as num).toDouble(),
          unit: _unit(r['unit'] as String),
          marketPrice: 0,
          when: 'recent',
        ),
    ];
  }

  /// Conversation threads the user is part of, with messages.
  Future<List<Thread>> loadThreads() async {
    final id = uid;
    if (id == null) return [];
    final rows = await _db
        .from('threads')
        .select('*, messages(*), offers(*)')
        .order('updated_at', ascending: false);
    return [
      for (final r in rows)
        Thread(
          id: r['id'] as String,
          name: (r['farmer_id'] == id) ? 'Dealer' : 'Farmer',
          role: (r['farmer_id'] == id) ? 'Dealer' : 'Farmer',
          crop: (r['crop_label'] ?? '') as String,
          emoji: (r['emoji'] ?? '🌱') as String,
          messages: [
            for (final m in (r['messages'] as List? ?? []))
              Message(
                id: m['id'] as String,
                mine: m['sender_id'] == id,
                time: 'recent',
                text: m['body'] as String?,
                system: (m['type'] as String?) == 'system',
              )
          ]..sort((a, b) => a.id.compareTo(b.id)),
        ),
    ];
  }

  Future<List<AppNotification>> loadNotifications() async {
    final rows = await _db
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) _notif(r)];
  }

  Future<void> sendMessage(String threadId, String text) async {
    await _db.from('messages').insert({
      'thread_id': threadId,
      'sender_id': uid,
      'type': 'text',
      'body': text,
    });
  }

  Future<void> postRequirement({
    required String cropId,
    required double qty,
    required Unit unit,
    required int priceMin,
    required int priceMax,
    required int neededInDays,
  }) async {
    await _db.from('buy_requests').insert({
      'dealer_id': uid,
      'crop_id': cropId,
      'quantity': qty,
      'unit': unit.name,
      'price_min': priceMin,
      'price_max': priceMax,
      'location_label': 'within 50 km',
    });
  }

  Future<void> submitReview(String orderId, String toUser, int rating) async {
    await _db.from('reviews').insert({
      'order_id': orderId,
      'from_user': uid,
      'to_user': toUser,
      'rating': rating,
    });
  }

  // ── storage ───────────────────────────────────────────────
  Future<String> uploadListingPhoto(String filename, Uint8List bytes) async {
    final path = '${uid!}/$filename';
    await _db.storage.from('listing-photos').uploadBinary(path, bytes);
    return _db.storage.from('listing-photos').getPublicUrl(path);
  }

  Future<String> uploadKycDoc(String filename, Uint8List bytes) async {
    final path = '${uid!}/$filename';
    await _db.storage.from('kyc-docs').uploadBinary(path, bytes);
    // private bucket → short-lived signed URL, never public
    return _db.storage.from('kyc-docs').createSignedUrl(path, 60 * 10);
  }

  // ── realtime ──────────────────────────────────────────────
  RealtimeChannel subscribe(String name, void Function() onChange) {
    return _db
        .channel('rt:$name')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: name,
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  // ── mappers ───────────────────────────────────────────────
  Listing _listing(Map<String, dynamic> r, Map<String, Map<String, dynamic>> sellers) {
    final s = sellers[r['farmer_id']];
    return Listing(
      id: r['id'] as String,
      crop: (r['crops']?['name'] ?? '') as String,
      emoji: (r['crops']?['emoji'] ?? '🌱') as String,
      qty: (r['quantity'] as num).toDouble(),
      unit: _unit(r['unit'] as String),
      grade: _grade(r['quality_grade'] as String),
      organic: (r['is_organic'] ?? false) as bool,
      price: (r['expected_price'] ?? 0) as int,
      marketPrice: (r['market_price'] ?? 0) as int,
      harvestInDays: 0,
      location: (r['location_label'] ?? '') as String,
      distanceKm: 0,
      status: _listingStatus(r['status'] as String),
      offers: (r['offers'] ?? 0) as int,
      views: (r['views'] ?? 0) as int,
      seller: Seller(
        name: (s?['full_name'] ?? 'Farmer') as String,
        village: 'Kolar',
        rating: ((s?['avg_rating'] ?? 0) as num).toDouble(),
        deals: (s?['rating_count'] ?? 0) as int,
        verified: (s?['verified'] ?? false) as bool,
      ),
    );
  }

  Order _order(Map<String, dynamic> r) => Order(
        id: r['id'] as String,
        crop: (r['crop_label'] ?? '') as String,
        emoji: (r['emoji'] ?? '🌱') as String,
        counterparty: 'Counterparty',
        counterpartyRole: 'Trader',
        price: (r['final_price'] ?? 0) as int,
        qty: (r['quantity'] as num).toDouble(),
        unit: _unit(r['unit'] as String),
        marketPrice: 0,
        placedWhen: 'recent',
        stage: _stage(r['status'] as String),
        paidToEscrow: (r['status'] as String) != 'accepted',
      );

  AppNotification _notif(Map<String, dynamic> r) => AppNotification(
        id: r['id'] as String,
        kind: _notifKind(r['type'] as String),
        title: (r['title'] ?? '') as String,
        body: (r['body'] ?? '') as String,
        when: 'recent',
        read: (r['read'] ?? false) as bool,
      );

  Unit _unit(String s) =>
      Unit.values.firstWhere((u) => u.name == s, orElse: () => Unit.quintal);
  Grade _grade(String s) =>
      Grade.values.firstWhere((g) => g.label == s, orElse: () => Grade.b);
  ListingStatus _listingStatus(String s) => switch (s) {
        'offers' => ListingStatus.offers,
        'sold' => ListingStatus.sold,
        _ => ListingStatus.live,
      };
  OrderStage _stage(String s) =>
      OrderStage.values.firstWhere((x) => x.name == s, orElse: () => OrderStage.accepted);
  NotifKind _notifKind(String s) =>
      NotifKind.values.firstWhere((k) => k.name == s, orElse: () => NotifKind.system);
}
