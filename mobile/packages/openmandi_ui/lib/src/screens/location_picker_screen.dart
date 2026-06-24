import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/buttons.dart';

/// What the picker returns once the user confirms a spot.
class PickedLocation {
  const PickedLocation(this.lat, this.lng, this.label);
  final double lat;
  final double lng;
  final String label;
}

class _Place {
  _Place(this.lat, this.lng, this.label);
  final double lat;
  final double lng;
  final String label;
}

/// Free map location picker — CARTO Voyager basemap (no key) + Nominatim search
/// & reverse geocoding. Search a place, tap the map, or use GPS.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});
  final double? initialLat;
  final double? initialLng;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  LatLng _pin = const LatLng(20.5937, 78.9629);
  String _label = '';
  bool _resolving = false;
  bool _searching = false;
  List<_Place> _results = [];
  Timer? _debounce;

  bool get _hasInitial => widget.initialLat != null && widget.initialLng != null;

  @override
  void initState() {
    super.initState();
    if (_hasInitial) {
      _pin = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setPin(LatLng p, {bool clearResults = true}) {
    setState(() {
      _pin = p;
      if (clearResults) _results = [];
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reverseGeocode);
  }

  Map<String, String> get _headers => {
        'User-Agent': 'OpenMandi/1.0 (agri marketplace)',
        'Accept-Language': 'en',
      };

  Future<void> _reverseGeocode() async {
    setState(() => _resolving = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${_pin.latitude}&lon=${_pin.longitude}&zoom=12');
      final res =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) setState(() => _label = _shortLabel(data['address']));
      }
    } catch (_) {
      // keep previous label; coordinates remain valid
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  String _shortLabel(dynamic address) {
    final a = (address as Map<String, dynamic>?) ?? {};
    final place =
        a['village'] ?? a['town'] ?? a['city'] ?? a['suburb'] ?? a['county'];
    final district = a['state_district'] ?? a['county'];
    final state = a['state'];
    final parts = <String>[
      for (final p in [place, district, state])
        if (p != null && '$p'.isNotEmpty) '$p'
    ];
    final seen = <String>{};
    return parts.where((p) => seen.add(p)).take(2).join(', ');
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=jsonv2&countrycodes=in&limit=6&q=${Uri.encodeQueryComponent(q)}');
      final res =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final places = [
          for (final r in list)
            _Place(
              double.parse(r['lat'] as String),
              double.parse(r['lon'] as String),
              (r['display_name'] as String).split(',').take(3).join(',').trim(),
            ),
        ];
        if (mounted) setState(() => _results = places);
      }
    } catch (_) {
      // ignore — user can still tap the map
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(q));
  }

  void _pickResult(_Place p) {
    FocusScope.of(context).unfocus();
    _search.text = p.label;
    final ll = LatLng(p.lat, p.lng);
    _map.move(ll, 13);
    setState(() {
      _results = [];
      _label = p.label;
    });
    _setPin(ll, clearResults: true);
  }

  Future<void> _useGps() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Location permission denied — search or tap the map'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final p = LatLng(pos.latitude, pos.longitude);
      _map.move(p, 15);
      _setPin(p);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not get location: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _zoom(double delta) {
    final c = _map.camera;
    _map.move(c.center, (c.zoom + delta).clamp(3, 18));
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _pin,
              initialZoom: _hasInitial ? 13 : 5,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, p) {
                FocusScope.of(context).unfocus();
                _setPin(p);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.openmandi.app',
                maxZoom: 19,
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _pin,
                  width: 80,
                  height: 80,
                  alignment: Alignment.topCenter,
                  child: _Pin(),
                ),
              ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap · CARTO'),
                ],
              ),
            ],
          ),

          // search bar
          Positioned(
            top: topInset + 8,
            left: Insets.s3,
            right: Insets.s3,
            child: _searchBar(),
          ),

          // zoom + gps controls
          Positioned(
            right: Insets.s3,
            bottom: 150,
            child: Column(
              children: [
                _circleBtn(Icons.add, () => _zoom(1)),
                const SizedBox(height: Insets.s2),
                _circleBtn(Icons.remove, () => _zoom(-1)),
                const SizedBox(height: Insets.s3),
                _circleBtn(Icons.my_location, _useGps, accent: true),
              ],
            ),
          ),

          // confirm card
          Positioned(
            left: Insets.s3,
            right: Insets.s3,
            bottom: Insets.s3,
            child: _confirmCard(),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Column(
      children: [
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(Radii.md),
          shadowColor: const Color(0x33000000),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: _runSearch,
            decoration: InputDecoration(
              hintText: 'Search a village, town or district…',
              prefixIcon: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : (_search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppColors.muted),
                          onPressed: () {
                            _search.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(Radii.md),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                for (final p in _results)
                  ListTile(
                    dense: true,
                    leading:
                        const Icon(Icons.place_outlined, color: AppColors.primary),
                    title: Text(p.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => _pickResult(p),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _confirmCard() {
    return Container(
      padding: const EdgeInsets.all(Insets.s4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: AppColors.primaryTint, shape: BoxShape.circle),
                child: const Icon(Icons.place, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: Insets.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolving
                          ? 'Finding place…'
                          : (_label.isEmpty ? 'Drop a pin to choose' : _label),
                      style:
                          const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${_pin.latitude.toStringAsFixed(4)}, ${_pin.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.s3),
          AppButton.primary('Use this location', icon: Icons.check, onPressed: () {
            Navigator.of(context).pop(PickedLocation(_pin.latitude, _pin.longitude,
                _label.isEmpty ? 'Pinned location' : _label));
          }),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool accent = false}) {
    return Material(
      color: accent ? AppColors.primary : AppColors.bg,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon,
              size: 22, color: accent ? AppColors.onPrimary : AppColors.ink),
        ),
      ),
    );
  }
}

/// A polished map pin: teardrop marker with a soft shadow + ground dot.
class _Pin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on, color: AppColors.danger, size: 46),
        Container(
          width: 10,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0x33000000),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
