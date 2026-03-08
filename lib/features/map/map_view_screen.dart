import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error_messages_tr.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../booking/booking_confirmation_screen.dart';
import '../booking/screens/payment_methods_screen.dart';
import '../tracking/driver_tracking_screen.dart';
import 'providers/map_providers.dart';
import 'widgets/booking_bottom_sheet.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key});

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  final MapController _mapController = MapController();
  late final DriverTrackingService _trackingService;
  LatLng? _userLocation;
  List<TowTruck> _towTrucks = [];
  bool _isLoadingTrucks = false;
  String? _error;
  StreamSubscription<Booking?>? _bookingSubscription;
  /// When non-null, we are waiting for a driver to accept; show "Searching..." overlay.
  Booking? _searchingBooking;
  Timer? _searchTimeoutTimer;
  static const Duration _driverSearchTimeout = Duration(seconds: 120);
  static const String _supportPhone = '+908501234567';

  static const LatLng _defaultCenter = LatLng(41.0082, 28.9784); // Istanbul

  @override
  void initState() {
    super.initState();
    _trackingService = ref.read(driverTrackingServiceProvider);
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

      List<TowTruck> trucks = [];
      try {
        trucks = await service.getNearestAvailableTowTrucks(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusKm: 10,
          limit: 10,
        );
      } catch (_) {
        // RPC may not exist yet; use empty list
      }

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
          _error = 'Konum izni verilmedi. Lütfen ayarlardan izin verin.';
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
  void dispose() {
    _searchTimeoutTimer?.cancel();
    _bookingSubscription?.cancel();
    _trackingService.dispose();
    super.dispose();
  }

  Future<void> _openBookingConfirmation() async {
    final user = _userLocation;
    if (user == null) return;
    final dest = LatLng(
      user.latitude + 0.03,
      user.longitude + 0.02,
    );
    final result = await Navigator.of(context).push<Booking>(
      MaterialPageRoute<Booking>(
        builder: (_) => BookingConfirmationScreen(
          userLocation: user,
          destinationLocation: dest,
          pickupAddress: 'Current location',
          destinationAddress: 'Destination',
        ),
      ),
    );
    if (result == null || !mounted) return;
    _searchTimeoutTimer?.cancel();
    setState(() => _searchingBooking = result);
    _searchTimeoutTimer = Timer(_driverSearchTimeout, () {
      if (!mounted || _searchingBooking == null) return;
      _searchTimeoutTimer = null;
      _showDriverSearchTimeoutDialog();
    });
    _bookingSubscription?.cancel();
    _bookingSubscription = _trackingService.watchBookingById(result.id).listen((updated) {
      if (updated?.driverId != null && mounted && _userLocation != null) {
        _searchTimeoutTimer?.cancel();
        _searchTimeoutTimer = null;
        _bookingSubscription?.cancel();
        _bookingSubscription = null;
        setState(() => _searchingBooking = null);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DriverTrackingScreen(
              booking: updated!,
              clientLocation: _userLocation!,
            ),
          ),
        );
      }
    });
  }

  void _showDriverSearchTimeoutDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(ErrorMessagesTr.stillSearchingTitle),
        content: const Text(ErrorMessagesTr.stillSearchingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(ErrorMessagesTr.keepWaiting),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri(scheme: 'tel', path: _supportPhone);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: const Text(ErrorMessagesTr.callSupport),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cekici'),
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card),
            tooltip: 'Payment methods',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PaymentMethodsScreen(),
              ),
            ),
          ),
        ],
      ),
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
          if (_searchingBooking != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: _SearchingForDriversOverlay(),
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
                      TextButton(
                        onPressed: () async {
                          final service = ref.read(locationServiceProvider);
                          await service.requestBackgroundLocationPermission();
                          _loadUserLocationAndTrucks();
                        },
                        child: Text(
                          'Retry',
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
                    : _openBookingConfirmation,
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

/// Pulse overlay shown on the map while waiting for a driver to accept (Client app).
class _SearchingForDriversOverlay extends StatefulWidget {
  @override
  State<_SearchingForDriversOverlay> createState() =>
      _SearchingForDriversOverlayState();
}

class _SearchingForDriversOverlayState extends State<_SearchingForDriversOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return Opacity(
              opacity: 0.5 + _pulse.value * 0.5,
              child: child,
            );
          },
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Searching for nearby drivers...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
