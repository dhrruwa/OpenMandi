import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../backend/backend.dart';
import '../backend/config.dart';
import '../store/app_store.dart';

class LocationPickerWidget extends StatefulWidget {
  const LocationPickerWidget({
    super.key,
    required this.onLocationSelected,
    this.initialLat,
    this.initialLng,
  });

  final Function({
    required double lat,
    required double lng,
    required String pincode,
    required String village,
    required String taluk,
    required String district,
    required String state,
    required String country,
  }) onLocationSelected;

  final double? initialLat;
  final double? initialLng;

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  final _pinController = TextEditingController();
  final _villageController = TextEditingController();
  final _talukController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();

  double _lat = 13.1367;
  double _lng = 78.1292;
  bool _loading = false;
  String? _error;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _lat = widget.initialLat!;
      _lng = widget.initialLng!;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _villageController.dispose();
    _talukController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentGps() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (lat, lng) = await Backend.I.currentLatLng();
      if (lat == null || lng == null) {
        throw Exception('Could not fetch GPS coordinates. Please check permissions.');
      }

      _lat = lat;
      _lng = lng;

      // Update map camera
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(_lat, _lng), 15),
        );
      }

      final address = await Backend.I.reverseGeocode(_lat, _lng);
      if (address != null) {
        setState(() {
          _pinController.text = address['pincode'] ?? '';
          _villageController.text = address['village'] ?? '';
          _talukController.text = address['taluk'] ?? '';
          _districtController.text = address['district'] ?? '';
          _stateController.text = address['state'] ?? '';
          _countryController.text = address['country'] ?? '';
        });
        _notifySelection();
      } else {
        setState(() {
          _error = 'Reverse geocoding failed. Please fill details manually.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '');
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _geocodePin(String pin) async {
    if (pin.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final address = await Backend.I.geocodePincode(pin);
      if (address != null) {
        _lat = double.tryParse(address['lat'] ?? '') ?? _lat;
        _lng = double.tryParse(address['lng'] ?? '') ?? _lng;

        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(_lat, _lng), 14),
          );
        }

        setState(() {
          _villageController.text = address['village'] ?? '';
          _talukController.text = address['taluk'] ?? '';
          _districtController.text = address['district'] ?? '';
          _stateController.text = address['state'] ?? '';
          _countryController.text = address['country'] ?? '';
        });
        _notifySelection();
      } else {
        setState(() {
          _error = 'Could not find details for PIN code. Please enter manually.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _notifySelection() {
    if (_pinController.text.isEmpty ||
        _villageController.text.isEmpty ||
        _talukController.text.isEmpty ||
        _districtController.text.isEmpty ||
        _stateController.text.isEmpty ||
        _countryController.text.isEmpty) {
      return; // incomplete
    }
    widget.onLocationSelected(
      lat: _lat,
      lng: _lng,
      pincode: _pinController.text,
      village: _villageController.text,
      taluk: _talukController.text,
      district: _districtController.text,
      state: _stateController.text,
      country: _countryController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // GPS Location Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading ? null : _useCurrentGps,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              store.getTranslated('use_gps'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),

          // Map view or visual placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: AppConfig.googleMapsApiKey.isNotEmpty
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_lat, _lng),
                      zoom: 14,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected_pin'),
                        position: LatLng(_lat, _lng),
                        draggable: true,
                        onDragEnd: (newPos) {
                          _lat = newPos.latitude;
                          _lng = newPos.longitude;
                          Backend.I.reverseGeocode(_lat, _lng).then((addr) {
                            if (addr != null) {
                              setState(() {
                                _pinController.text = addr['pincode'] ?? _pinController.text;
                                _villageController.text = addr['village'] ?? _villageController.text;
                                _talukController.text = addr['taluk'] ?? _talukController.text;
                                _districtController.text = addr['district'] ?? _districtController.text;
                                _stateController.text = addr['state'] ?? _stateController.text;
                                _countryController.text = addr['country'] ?? _countryController.text;
                              });
                              _notifySelection();
                            }
                          });
                        },
                      ),
                    },
                  )
                : Container(
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Interactive visual representation of a map
                        Opacity(
                          opacity: 0.2,
                          child: Icon(Icons.map, size: 100, color: primaryColor),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on, size: 40, color: primaryColor),
                            const SizedBox(height: 8),
                            const Text(
                              'Offline Map Mode',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Lat: ${_lat.toStringAsFixed(4)}, Lng: ${_lng.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],

          // Location Fields
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: store.getTranslated('pincode_label'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    if (val.length == 6) {
                      _geocodePin(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _villageController,
                  decoration: InputDecoration(
                    labelText: store.getTranslated('village'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _notifySelection(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _talukController,
                  decoration: InputDecoration(
                    labelText: store.getTranslated('taluk'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _notifySelection(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _districtController,
                  decoration: InputDecoration(
                    labelText: store.getTranslated('district'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _notifySelection(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: InputDecoration(
                    labelText: store.getTranslated('state'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _notifySelection(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: store.getTranslated('country'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _notifySelection(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
