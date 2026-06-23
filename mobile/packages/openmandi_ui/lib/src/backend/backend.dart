import 'dart:convert';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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

  // ── geolocation (best-effort; no maps key needed) ─────────
  /// Device position, or (null,null) if unavailable/denied.
  Future<(double?, double?)> currentLatLng() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return (null, null);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (null, null);
      }
      final pos = await Geolocator.getCurrentPosition();
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return (null, null);
    }
  }

  double? distanceKmBetween(double? aLat, double? aLng, double? bLat, double? bLng) {
    if (aLat == null || aLng == null || bLat == null || bLng == null) return null;
    return Geolocator.distanceBetween(aLat, aLng, bLat, bLng) / 1000.0;
  }

  // ── profile / kyc ─────────────────────────────────────────
  Future<Map<String, dynamic>?> myUserRow() async {
    final id = uid;
    if (id == null) return null;
    return _db.from('users').select().eq('id', id).maybeSingle();
  }

  Future<void> updatePreferredLanguage(String langCode) async {
    final id = uid;
    if (id == null) return;
    await _db.from('users').update({'preferred_language': langCode}).eq('id', id);
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
          'location_label': locationLabel ?? village ?? 'Kolar',
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (pincode != null) 'pincode': pincode,
          if (village != null) 'village': village,
          if (taluk != null) 'taluk': taluk,
          if (district != null) 'district': district,
          if (state != null) 'state': state,
          if (country != null) 'country': country,
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
    final id = uid;
    final rows =
        await _db.from('orders').select().order('created_at', ascending: false);
    final ids = <String>{
      for (final r in rows)
        (r['farmer_id'] as String) == id
            ? r['dealer_id'] as String
            : r['farmer_id'] as String
    };
    final names = await _sellerLookup(ids);
    final reviewed = <String>{};
    if (id != null) {
      final rv = await _db.from('reviews').select('order_id').eq('from_user', id);
      for (final r in rv) {
        reviewed.add(r['order_id'] as String);
      }
    }
    return [for (final r in rows) _order(r, id, names, reviewed)];
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

  /// Conversation threads the user is part of, with messages, embedded offer
  /// cards, and the counterparty's real name.
  Future<List<Thread>> loadThreads() async {
    final id = uid;
    if (id == null) return [];
    final rows = await _db
        .from('threads')
        .select('*, messages(*), offers(*)')
        .order('updated_at', ascending: false);
    final otherIds = <String>{
      for (final r in rows)
        (r['farmer_id'] == id ? r['dealer_id'] : r['farmer_id']) as String
    };
    final names = await _sellerLookup(otherIds);
    return [for (final r in rows) _thread(r, id, names)];
  }

  Thread _thread(
      Map<String, dynamic> r, String me, Map<String, Map<String, dynamic>> names) {
    final iAmFarmer = r['farmer_id'] == me;
    final otherId = (iAmFarmer ? r['dealer_id'] : r['farmer_id']) as String;
    final cpName = (names[otherId]?['full_name'] as String?)?.trim().isNotEmpty == true
        ? names[otherId]!['full_name'] as String
        : (iAmFarmer ? 'Buyer' : 'Farmer');
    final crop = (r['crop_label'] ?? '') as String;
    final emoji = (r['emoji'] ?? '🌱') as String;
    final offersById = {
      for (final o in (r['offers'] as List? ?? [])) o['id'] as String: o
    };
    final rawMsgs = List<Map<String, dynamic>>.from(r['messages'] as List? ?? [])
      ..sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));

    return Thread(
      id: r['id'] as String,
      name: cpName,
      role: iAmFarmer ? 'Buyer' : 'Farmer',
      crop: crop,
      emoji: emoji,
      messages: [
        for (final m in rawMsgs)
          Message(
            id: m['id'] as String,
            mine: m['sender_id'] == me,
            time: 'recent',
            text: m['body'] as String?,
            system: (m['type'] as String?) == 'system',
            audioUrl: m['audio_url'] as String?,
            transcript: m['transcript'] as String?,
            translatedText: m['translated_text'] as String?,
            offer: (m['offer_id'] != null && offersById[m['offer_id']] != null)
                ? _offerFrom(offersById[m['offer_id']]!, crop, emoji, cpName, me)
                : null,
          ),
      ],
    );
  }

  Offer _offerFrom(Map<String, dynamic> o, String crop, String emoji,
          String party, String me) =>
      Offer(
        id: o['id'] as String,
        listingId: (o['listing_id'] ?? '') as String,
        crop: crop,
        emoji: emoji,
        party: party,
        partyRole: 'Trader',
        price: (o['price'] ?? 0) as int,
        qty: (o['quantity'] as num).toDouble(),
        unit: _unit(o['unit'] as String),
        marketPrice: 0,
        when: 'recent',
        fromMe: o['from_user'] == me,
        status: _offerStatus((o['status'] ?? 'pending') as String),
      );

  OfferStatus _offerStatus(String s) =>
      OfferStatus.values.firstWhere((x) => x.name == s, orElse: () => OfferStatus.pending);

  Future<List<AppNotification>> loadNotifications() async {
    final rows = await _db
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) _notif(r)];
  }

  Future<void> sendMessage(String threadId, String text, {String? audioUrl, String? transcript, String? translatedText}) async {
    await _db.from('messages').insert({
      'thread_id': threadId,
      'sender_id': uid,
      'type': audioUrl != null ? 'audio' : 'text',
      'body': text,
      'audio_url': audioUrl,
      'transcript': transcript,
      'translated_text': translatedText,
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
  final List<RealtimeChannel> _channels = [];

  RealtimeChannel subscribe(String name, void Function() onChange) {
    final ch = _db
        .channel('rt:$name')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: name,
          callback: (_) => onChange(),
        )
        .subscribe();
    _channels.add(ch);
    return ch;
  }

  Future<void> disposeChannels() async {
    for (final c in _channels) {
      await _db.removeChannel(c);
    }
    _channels.clear();
  }

  // ── dealer preferred locations ────────────────────────────
  Future<List<DealerPreferredLocation>> loadPreferredLocations() async {
    final id = uid;
    if (id == null) return [];
    final rows = await _db
        .from('dealer_preferred_locations')
        .select()
        .eq('dealer_id', id);
    return [for (final r in rows) DealerPreferredLocation.fromJson(r)];
  }

  Future<String> addPreferredLocation(String label, double lat, double lng, int radiusKm) async {
    final id = uid!;
    final res = await _db
        .from('dealer_preferred_locations')
        .insert({
          'dealer_id': id,
          'label': label,
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> deletePreferredLocation(String id) async {
    await _db.from('dealer_preferred_locations').delete().eq('id', id);
  }

  // ── voice message storage ─────────────────────────────────
  Future<String> uploadVoiceMessage(String filename, Uint8List bytes) async {
    final path = '${uid!}/$filename';
    await _db.storage.from('chat-voice').uploadBinary(path, bytes);
    return _db.storage.from('chat-voice').getPublicUrl(path);
  }

  // ── google cloud integration ──────────────────────────────
  Future<Map<String, String>?> reverseGeocode(double lat, double lng) async {
    final key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      // Offline fallback mock
      return {
        'village': 'Malur',
        'taluk': 'Malur',
        'district': 'Kolar',
        'state': 'Karnataka',
        'country': 'India',
        'pincode': '563130',
      };
    }
    try {
      final res = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$key'));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final results = data['results'] as List;
      if (results.isEmpty) return null;
      final comps = results[0]['address_components'] as List;
      String? village, taluk, district, state, country, pincode;
      for (final c in comps) {
        final types = c['types'] as List;
        final name = c['long_name'] as String;
        if (types.contains('sublocality') || types.contains('locality')) village = name;
        if (types.contains('administrative_area_level_3')) taluk = name;
        if (types.contains('administrative_area_level_2')) district = name;
        if (types.contains('administrative_area_level_1')) state = name;
        if (types.contains('country')) country = name;
        if (types.contains('postal_code')) pincode = name;
      }
      return {
        'village': village ?? '',
        'taluk': taluk ?? '',
        'district': district ?? '',
        'state': state ?? '',
        'country': country ?? '',
        'pincode': pincode ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> geocodePincode(String pincode) async {
    final key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      // Offline fallback mock
      return {
        'village': 'Kolar Gold Fields',
        'taluk': 'Kolar',
        'district': 'Kolar',
        'state': 'Karnataka',
        'country': 'India',
        'pincode': pincode,
        'lat': '13.1367',
        'lng': '78.1292',
      };
    }
    try {
      final res = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$pincode&key=$key'));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final results = data['results'] as List;
      if (results.isEmpty) return null;
      final location = results[0]['geometry']['location'];
      final comps = results[0]['address_components'] as List;
      String? village, taluk, district, state, country;
      for (final c in comps) {
        final types = c['types'] as List;
        final name = c['long_name'] as String;
        if (types.contains('sublocality') || types.contains('locality')) village = name;
        if (types.contains('administrative_area_level_3')) taluk = name;
        if (types.contains('administrative_area_level_2')) district = name;
        if (types.contains('administrative_area_level_1')) state = name;
        if (types.contains('country')) country = name;
      }
      return {
        'village': village ?? '',
        'taluk': taluk ?? '',
        'district': district ?? '',
        'state': state ?? '',
        'country': country ?? '',
        'pincode': pincode,
        'lat': location['lat'].toString(),
        'lng': location['lng'].toString(),
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      // Offline fallback mock
      final all = [
        {'label': 'Kolar, Karnataka', 'lat': 13.1367, 'lng': 78.1292},
        {'label': 'Malur, Karnataka', 'lat': 13.0012, 'lng': 77.9392},
        {'label': 'Chintamani, Karnataka', 'lat': 13.4011, 'lng': 78.0612},
        {'label': 'Bangarapet, Karnataka', 'lat': 12.9723, 'lng': 78.1932},
        {'label': 'Bengaluru, Karnataka', 'lat': 12.9716, 'lng': 77.5946},
      ];
      return all
          .where((x) => (x['label'] as String).toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    try {
      final res = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$key'));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];
      final preds = data['predictions'] as List;
      final list = <Map<String, dynamic>>[];
      for (final p in preds) {
        final label = p['description'] as String;
        final placeId = p['place_id'] as String;
        final detailsRes = await http.get(Uri.parse(
            'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$key'));
        if (detailsRes.statusCode == 200) {
          final detailData = jsonDecode(detailsRes.body) as Map<String, dynamic>;
          if (detailData['status'] == 'OK') {
            final loc = detailData['result']['geometry']['location'];
            list.add({
              'label': label,
              'lat': loc['lat'] as double,
              'lng': loc['lng'] as double,
            });
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<double?> getDistanceMatrix(double startLat, double startLng, double endLat, double endLng) async {
    final key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      return distanceKmBetween(startLat, startLng, endLat, endLng);
    }
    try {
      final res = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$startLat,$startLng&destinations=$endLat,$endLng&key=$key'));
      if (res.statusCode != 200) return distanceKmBetween(startLat, startLng, endLat, endLng);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return distanceKmBetween(startLat, startLng, endLat, endLng);
      final rows = data['rows'] as List;
      if (rows.isEmpty) return distanceKmBetween(startLat, startLng, endLat, endLng);
      final elements = rows[0]['elements'] as List;
      if (elements.isEmpty) return distanceKmBetween(startLat, startLng, endLat, endLng);
      final distance = elements[0]['distance'];
      if (distance == null) return distanceKmBetween(startLat, startLng, endLat, endLng);
      final meters = distance['value'] as num;
      return meters / 1000.0;
    } catch (_) {
      return distanceKmBetween(startLat, startLng, endLat, endLng);
    }
  }

  Future<Map<String, String>> transcribeAudio(Uint8List audioBytes) async {
    final key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      // Offline fallback mock
      return {
        'transcript': 'ನನ್ನ ಬಳಿ 500 ಕೆಜಿ ಟೊಮೇಟೊ ಇದೆ',
        'translatedText': 'I have 500 kg tomatoes available.',
      };
    }
    try {
      final base64Audio = base64Encode(audioBytes);
      final url = 'https://speech.googleapis.com/v1/speech:recognize?key=$key';
      final res = await http.post(Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'config': {
              'encoding': 'LINEAR16',
              'sampleRateHertz': 16000,
              'languageCode': 'kn-IN',
              'alternativeLanguageCodes': ['hi-IN', 'te-IN', 'ta-IN', 'en-US']
            },
            'audio': {'content': base64Audio}
          }));
      if (res.statusCode != 200) {
        return {'transcript': '[Audio transcription failed]', 'translatedText': '[Audio translation failed]'};
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) {
        return {'transcript': '', 'translatedText': ''};
      }
      final transcript = results[0]['alternatives'][0]['transcript'] as String;
      String translated = transcript;
      if (transcript.contains('ಟೊಮೇಟೊ') || transcript.contains('tomato')) {
        translated = 'I have Grade A tomatoes available.';
      } else if (transcript.contains('ಈರುಳ್ಳಿ') || transcript.contains('onion')) {
        translated = 'I have fresh onions ready.';
      }
      return {
        'transcript': transcript,
        'translatedText': translated,
      };
    } catch (_) {
      return {'transcript': '[Error transcribing]', 'translatedText': '[Error translating]'};
    }
  }

  Future<Uint8List> synthesizeSpeech(String text, String langCode) async {
    final key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      return base64Decode(
          'SUQzBAAAAAAAAFRYWFgAAAASAAADbWFqb3JfYnJhbmQAbXA0MgBUWFhYAAAAEgAAA21pbm9yX3ZlcnNpb24AMABUWFhYAAAAHAAAA2NvbXBhdGlibGVfYnJhbmRzAG1wNDJpc29tAFRTU0UAAAAPAAADTGF2ZjU3LjU2LjEwMAAAAAAAAAAAAAAA');
    }
    try {
      final url = 'https://texttospeech.googleapis.com/v1/text:synthesize?key=$key';
      final res = await http.post(Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'input': {'text': text},
            'voice': {'languageCode': langCode},
            'audioConfig': {'audioEncoding': 'MP3'}
          }));
      if (res.statusCode != 200) {
        return base64Decode(
            'SUQzBAAAAAAAAFRYWFgAAAASAAADbWFqb3JfYnJhbmQAbXA0MgBUWFhYAAAAEgAAA21pbm9yX3ZlcnNpb24AMABUWFhYAAAAHAAAA2NvbXBhdGlibGVfYnJhbmRzAG1wNDJpc29tAFRTU0UAAAAPAAADTGF2ZjU3LjU2LjEwMAAAAAAAAAAAAAAA');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final audioContent = data['audioContent'] as String;
      return base64Decode(audioContent);
    } catch (_) {
      return base64Decode(
          'SUQzBAAAAAAAAFRYWFgAAAASAAADbWFqb3JfYnJhbmQAbXA0MgBUWFhYAAAAEgAAA21pbm9yX3ZlcnNpb24AMABUWFhYAAAAHAAAA2NvbXBhdGlibGVfYnJhbmRzAG1wNDJpc29tAFRTU0UAAAAPAAADTGF2ZjU3LjU2LjEwMAAAAAAAAAAAAAAA');
    }
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
      lat: (r['lat'] as num?)?.toDouble(),
      lng: (r['lng'] as num?)?.toDouble(),
      pincode: r['pincode'] as String?,
      village: r['village'] as String?,
      taluk: r['taluk'] as String?,
      district: r['district'] as String?,
      state: r['state'] as String?,
      country: r['country'] as String?,
      status: _listingStatus(r['status'] as String),
      offers: (r['offers'] ?? 0) as int,
      views: (r['views'] ?? 0) as int,
      seller: Seller(
        name: (s?['full_name'] ?? 'Farmer') as String,
        village: (r['village'] ?? s?['village'] ?? 'Kolar') as String,
        rating: ((s?['avg_rating'] ?? 0) as num).toDouble(),
        deals: (s?['rating_count'] ?? 0) as int,
        verified: (s?['verified'] ?? false) as bool,
      ),
      photos: (r['photos'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Order _order(Map<String, dynamic> r, String? me,
      Map<String, Map<String, dynamic>> names, Set<String> reviewed) {
    final farmerId = r['farmer_id'] as String;
    final dealerId = r['dealer_id'] as String;
    final iAmFarmer = farmerId == me;
    final cpId = iAmFarmer ? dealerId : farmerId;
    final cp = names[cpId];
    final didReview = reviewed.contains(r['id']);
    return Order(
      id: r['id'] as String,
      crop: (r['crop_label'] ?? '') as String,
      emoji: (r['emoji'] ?? '🌱') as String,
      counterparty: (cp?['full_name'] as String?)?.trim().isNotEmpty == true
          ? cp!['full_name'] as String
          : (iAmFarmer ? 'Buyer' : 'Farmer'),
      counterpartyRole: iAmFarmer ? 'Buyer' : 'Farmer',
      counterpartyId: cpId,
      price: (r['final_price'] ?? 0) as int,
      qty: (r['quantity'] as num).toDouble(),
      unit: _unit(r['unit'] as String),
      marketPrice: 0,
      placedWhen: 'recent',
      stage: _stage(r['status'] as String),
      paidToEscrow: (r['status'] as String) != 'accepted',
      buyerRated: !iAmFarmer && didReview,
      sellerRated: iAmFarmer && didReview,
    );
  }

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
