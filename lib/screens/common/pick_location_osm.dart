import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// OSM-based location picker (no API key).
/// Returns { 'lat': double, 'lng': double, 'address': String } via Navigator.pop
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({Key? key}) : super(key: key);

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  // Default center: Abbottabad
  static const LatLng kAbbottabad = LatLng(34.1688, 73.2215);

  final MapController _mapController = MapController();
  LatLng _center = kAbbottabad;

  LatLng? _selected;
  String? _selectedAddress;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _centerOnGps(); // just centers; selection is user-controlled
  }

  Future<void> _centerOnGps() async {
    setState(() => _locating = true);

    final hasService = await Geolocator.isLocationServiceEnabled();
    if (!hasService) {
      setState(() => _locating = false);
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      setState(() => _locating = false);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _center = LatLng(pos.latitude, pos.longitude);
      _mapController.move(_center, 15);
      // Do not auto-select here; user will pick or press My location below.
    } catch (_) {
      // keep default
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() {
      _selected = p;
      _selectedAddress = null;
    });
    try {
      final placemarks = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final parts = <String?>[
          pm.name,
          pm.street,
          pm.subLocality,
          pm.locality,
          pm.administrativeArea,
          pm.postalCode,
        ].where((e) => (e ?? '').trim().isNotEmpty).cast<String>().toList();
        setState(() => _selectedAddress = parts.join(', '));
      } else {
        setState(() => _selectedAddress =
        '(${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)})');
      }
    } catch (_) {
      setState(() => _selectedAddress =
      '(${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)})');
    }
  }

  /// Selects current GPS location (centers + drops marker + enables confirm)
  Future<void> _selectMyLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final here = LatLng(pos.latitude, pos.longitude);
      _mapController.move(here, 16);
      await _reverseGeocode(here); // also fills _selectedAddress
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get current location: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _useThisLocation() {
    if (_selected == null) return;
    Navigator.of(context).pop({
      'lat': _selected!.latitude,
      'lng': _selected!.longitude,
      'address': _selectedAddress ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location (Abbottabad)')),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onTap: (tapPos, point) => _reverseGeocode(point),
              onLongPress: (tapPos, point) => _reverseGeocode(point),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.blood_donation_app',
                maxNativeZoom: 19,
                maxZoom: 19,
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin, size: 44),
                    ),
                  ],
                ),
            ],
          ),

          // Loading overlay
          if (_locating)
            const Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // Bottom controls (side-by-side buttons)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected Address', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        _selectedAddress ?? 'Tap or long-press the map to select.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _locating ? null : _selectMyLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('My location'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _selected == null ? null : _useThisLocation,
                              icon: const Icon(Icons.check),
                              label: const Text('Use this location'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // No FAB; actions are in the bottom card.
    );
  }
}
