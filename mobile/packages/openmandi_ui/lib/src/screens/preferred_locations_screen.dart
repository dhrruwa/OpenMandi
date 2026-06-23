import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/models.dart';
import '../backend/backend.dart';
import '../backend/config.dart';
import '../store/app_store.dart';

class PreferredLocationsScreen extends StatefulWidget {
  const PreferredLocationsScreen({super.key});

  @override
  State<PreferredLocationsScreen> createState() => _PreferredLocationsScreenState();
}

class _PreferredLocationsScreenState extends State<PreferredLocationsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  LatLng _selectedPos = const LatLng(13.1367, 78.1292);
  String _selectedLabel = 'Kolar, Karnataka';
  int _radiusKm = 50;
  GoogleMapController? _mapController;
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final list = await Backend.I.searchPlaces(query);
    setState(() {
      _searchResults = list;
      _searching = false;
    });
  }

  void _selectPlace(Map<String, dynamic> place) {
    setState(() {
      _selectedLabel = place['label'] as String;
      _selectedPos = LatLng(place['lat'] as double, place['lng'] as double);
      _searchResults = [];
      _searchController.clear();
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_selectedPos, 13),
    );
  }

  Future<void> _saveLocation() async {
    final store = context.store;
    setState(() => _loading = true);
    try {
      store.addPreferredLocation(
        label: _selectedLabel,
        lat: _selectedPos.latitude,
        lng: _selectedPos.longitude,
        radiusKm: _radiusKm,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preferred buying location saved successfully!'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save location: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(store.getTranslated('preferred_locations')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Autocomplete
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: store.getTranslated('search_crops').replaceAll('crops...', 'locations...'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => _search(val),
                ),
                if (_searchResults.isNotEmpty)
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(top: 4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, idx) {
                        final item = _searchResults[idx];
                        return ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(item['label'] as String),
                          onTap: () => _selectPlace(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Map Picker Area
          Expanded(
            child: Stack(
              children: [
                AppConfig.googleMapsApiKey.isNotEmpty
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedPos,
                          zoom: 12,
                        ),
                        onMapCreated: (c) => _mapController = c,
                        onTap: (pos) {
                          setState(() {
                            _selectedPos = pos;
                            _selectedLabel = 'Pinned Location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
                          });
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('pin'),
                            position: _selectedPos,
                            draggable: true,
                            onDragEnd: (pos) {
                              setState(() {
                                _selectedPos = pos;
                                _selectedLabel = 'Pinned Location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
                              });
                            },
                          ),
                        },
                        circles: {
                          Circle(
                            circleId: const CircleId('radius_circle'),
                            center: _selectedPos,
                            radius: _radiusKm * 1000.0,
                            fillColor: primaryColor.withOpacity(0.15),
                            strokeColor: primaryColor,
                            strokeWidth: 2,
                          ),
                        },
                      )
                    : Container(
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 0.1,
                              child: Icon(Icons.map, size: 200, color: primaryColor),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_pin, size: 60, color: primaryColor),
                                const SizedBox(height: 12),
                                const Text(
                                  'Offline Map Mode',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  'Target: $_selectedLabel',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),

          // Settings (Radius, Label, Save)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('${store.getTranslated('radius')}: '),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [10, 25, 50, 100].map((r) {
                            final selected = _radiusKm == r;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ChoiceChip(
                                label: Text('$r km'),
                                selected: selected,
                                onSelected: (val) {
                                  if (val) setState(() => _radiusKm = r);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : _saveLocation,
                        icon: _loading ? const CircularProgressIndicator() : const Icon(Icons.add),
                        label: Text(store.getTranslated('add_location'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.list),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) {
                            return ListSavedLocationsSheet(store: store);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListSavedLocationsSheet extends StatelessWidget {
  const ListSavedLocationsSheet({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final locs = store.preferredLocations;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                store.getTranslated('preferred_locations'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (locs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No preferred locations saved yet.')),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: locs.length,
                    itemBuilder: (context, idx) {
                      final item = locs[idx];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(item.label),
                        subtitle: Text('Radius: ${item.radiusKm} km'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            store.deletePreferredLocation(item.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
