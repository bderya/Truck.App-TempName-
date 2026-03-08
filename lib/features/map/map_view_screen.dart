import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/location_service.dart';
import 'providers/map_providers.dart';
import 'widgets/booking_bottom_sheet.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key});

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  List<TowTruck> _towTrucks = [];
  bool _isLoadingTrucks = false;
  String? _error;

  static const LatLng _defaultCenter = LatLng(41.0082, 28.9784); // Istanbul

  @override
  void initState() {
    super.initState();
    _loadUserLocationAndTrucks();
  }

  Future<void> _loadUserLocationAndTrucks() async {
    setState(() {
      _error = null;
      _isLoadingTrucks = true;
    });

    final service = ref.read(locationServiceProvider);
    final position = await service.getCurrentPosition();

    if (position != null && mounted) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_userLocation!, 14);

      final trucks = await service.getNearestAvailableTowTrucks(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: 10,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _towTrucks = trucks;
          _isLoadingTrucks = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingTrucks = false;
          _error = 'Location permission denied';
        });
      }
    }
  }

  void _showBookingSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingBottomSheet(
        userLat: _userLocation?.latitude,
        userLng: _userLocation?.longitude,
        towTrucks: _towTrucks,
        onRefresh: _loadUserLocationAndTrucks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _defaultCenter,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cekici.cekici',
              ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null) _buildUserMarker(),
                  ..._towTrucks.map(_buildTowTruckMarker),
                ],
              ),
            ],
          ),
          if (_isLoadingTrucks)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Finding nearby tow trucks...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: () {
                    if (_userLocation != null) {
                      _mapController.move(_userLocation!, 14);
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'refresh',
                  onPressed: _loadUserLocationAndTrucks,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Marker _buildUserMarker() {
    return Marker(
      point: _userLocation!,
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildTowTruckMarker(TowTruck truck) {
    return Marker(
      point: LatLng(truck.currentLatitude, truck.currentLongitude),
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.local_shipping,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_towTrucks.length} tow truck(s) nearby',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _towTrucks.isEmpty || _userLocation == null
                    ? null
                    : _showBookingSheet,
                icon: const Icon(Icons.add_road),
                label: const Text('Request Tow Truck'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
