import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/money.dart';
import '../widgets/produce_image.dart';

/// Free map view of market listings that have coordinates — CARTO Voyager
/// basemap (no key). Tap a price marker for a preview card.
class ListingsMapScreen extends StatefulWidget {
  const ListingsMapScreen(this.listings, {super.key, this.onOpen});
  final List<Listing> listings;
  final void Function(Listing)? onOpen;

  @override
  State<ListingsMapScreen> createState() => _ListingsMapScreenState();
}

class _ListingsMapScreenState extends State<ListingsMapScreen> {
  final _map = MapController();
  Listing? _selected;

  List<Listing> get _pins =>
      widget.listings.where((l) => l.lat != null && l.lng != null).toList();

  void _fitAll() {
    final pins = _pins;
    if (pins.isEmpty) return;
    if (pins.length == 1) {
      _map.move(LatLng(pins.first.lat!, pins.first.lng!), 12);
      return;
    }
    final bounds = LatLngBounds.fromPoints(
        [for (final l in pins) LatLng(l.lat!, l.lng!)]);
    _map.fitCamera(CameraFit.bounds(
        bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins;
    final center = pins.isNotEmpty
        ? LatLng(pins.first.lat!, pins.first.lng!)
        : const LatLng(20.5937, 78.9629);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text('Map · ${pins.length} nearby',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
        actions: [
          if (pins.length > 1)
            IconButton(
              tooltip: 'Fit all',
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: _fitAll,
            ),
        ],
      ),
      body: pins.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(Insets.s6),
                child: Text(
                  'No listings have a location yet. Farmers who pin their '
                  'location when posting will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: pins.length > 1 ? 7 : 11,
                    minZoom: 3,
                    maxZoom: 18,
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.openmandi.app',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        for (final l in pins)
                          Marker(
                            point: LatLng(l.lat!, l.lng!),
                            width: 110,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: _PriceMarker(
                              listing: l,
                              selected: identical(_selected, l),
                              onTap: () {
                                setState(() => _selected = l);
                                _map.move(LatLng(l.lat!, l.lng!), _map.camera.zoom);
                              },
                            ),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap · CARTO'),
                      ],
                    ),
                  ],
                ),
                if (_selected != null)
                  Positioned(
                    left: Insets.s3,
                    right: Insets.s3,
                    bottom: Insets.s3,
                    child: _PreviewCard(
                      listing: _selected!,
                      onView: () => widget.onOpen?.call(_selected!),
                      onClose: () => setState(() => _selected = null),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker(
      {required this.listing, required this.selected, required this.onTap});
  final Listing listing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.accent : AppColors.primary;
    final fg = selected ? AppColors.onAccent : AppColors.onPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.pill),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Text('${listing.emoji} ${inr(listing.price)}',
                style: TextStyle(
                    color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          Icon(Icons.arrow_drop_down, color: bg, size: 20),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard(
      {required this.listing, required this.onView, required this.onClose});
  final Listing listing;
  final VoidCallback onView;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Container(
      padding: const EdgeInsets.all(Insets.s3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          ProduceImage(l.crop, imageUrl: l.photoUrl, size: 60, radius: Radii.sm),
          const SizedBox(width: Insets.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${l.crop} · Grade ${l.grade.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    InkWell(
                      onTap: onClose,
                      child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                  ],
                ),
                Text('${inr(l.price)}/qtl · ${l.seller.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (l.location.trim().isNotEmpty)
                  Text(l.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.sm)),
                    ),
                    onPressed: onView,
                    child: const Text('View listing',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
