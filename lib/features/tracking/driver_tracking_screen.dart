import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/models.dart';
import '../../services/eta_service.dart';
import '../booking/screens/job_summary_receipt_screen.dart';
import '../booking/widgets/review_popup.dart';
import '../chat/chat_screen.dart';

/// Client screen: real-time driver tracking with smooth animated marker and ETA.
class DriverTrackingScreen extends ConsumerStatefulWidget {
  const DriverTrackingScreen({
    super.key,
    required this.booking,
    required this.clientLocation,
  });

  final Booking booking;
  final LatLng clientLocation;

  @override
  ConsumerState<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends ConsumerState<DriverTrackingScreen> {
  late final DriverTrackingService _trackingService;
  final EtaService _etaService = EtaService(averageSpeedKmh: 25);
  StreamSubscription<TowTruck?>? _subscription;
  StreamSubscription<Booking?>? _bookingSubscription;
  bool _reviewShown = false;

  TowTruck? _towTruck;

  @override
  void initState() {
    super.initState();
    _trackingService = ref.read(driverTrackingServiceProvider);
    _subscribe();
    _subscribeToBooking();
  }

  void _subscribe() {
    _subscription = _trackingService.watchDriverForBooking(widget.booking).listen((truck) {
      if (!mounted) return;
      setState(() => _towTruck = truck);
    });
  }

  void _subscribeToBooking() {
    _bookingSubscription = _trackingService.watchBookingById(widget.booking.id).listen((booking) {
      if (!mounted || booking == null || _reviewShown) return;
      if (booking.status == 'completed') {
        _reviewShown = true;
        ReviewPopup.show(
          context,
          onSubmit: (_) => _openReceipt(booking.id),
          onDismiss: () => _openReceipt(booking.id),
        );
      }
    });
  }

  void _openReceipt(int bookingId) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobSummaryReceiptScreen(bookingId: bookingId),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bookingSubscription?.cancel();
    _trackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_towTruck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver on the way')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Waiting for driver position...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver on the way'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatScreen(
                  bookingId: widget.booking.id,
                  currentUserId: widget.booking.clientId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _TrackingMap(
        key: ValueKey(_towTruck!.id),
        truck: _towTruck!,
        booking: widget.booking,
        clientLocation: widget.clientLocation,
        etaService: _etaService,
      ),
    );
  }
}

class _TrackingMap extends StatefulWidget {
  const _TrackingMap({
    super.key,
    required this.truck,
    required this.booking,
    required this.clientLocation,
    required this.etaService,
  });

  final TowTruck truck;
  final Booking booking;
  final LatLng clientLocation;
  final EtaService etaService;

  @override
  State<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<_TrackingMap> with SingleTickerProviderStateMixin {
  LatLng? _animFrom;
  LatLng? _animTo;
  late AnimationController _animController;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.truck.currentLatitude != widget.truck.currentLatitude ||
        oldWidget.truck.currentLongitude != widget.truck.currentLongitude) {
      _animFrom = LatLng(
        oldWidget.truck.currentLatitude,
        oldWidget.truck.currentLongitude,
      );
      _animTo = LatLng(
        widget.truck.currentLatitude,
        widget.truck.currentLongitude,
      );
      _animController.forward(from: 0);
    }
  }

  LatLng _driverDisplayPosition() {
    final current = LatLng(widget.truck.currentLatitude, widget.truck.currentLongitude);
    if (_animTo == null) return current;
    if (_animFrom == null) return _animTo!;
    final t = _anim.value;
    return LatLng(
      _animFrom!.latitude + t * (_animTo!.latitude - _animFrom!.latitude),
      _animFrom!.longitude + t * (_animTo!.longitude - _animFrom!.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.booking.pickupLat, widget.booking.pickupLng);
    final eta = widget.etaService.calculateEta(
      driverLat: widget.truck.currentLatitude,
      driverLng: widget.truck.currentLongitude,
      destLat: widget.booking.pickupLat,
      destLng: widget.booking.pickupLng,
    );
    final distanceKm = widget.etaService.distanceKm(
      widget.truck.currentLatitude,
      widget.truck.currentLongitude,
      widget.booking.pickupLat,
      widget.booking.pickupLng,
    );

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final driverPos = _driverDisplayPosition();
              return FlutterMap(
                options: MapOptions(
                  initialCenter: driverPos,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.cekici.cekici',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: driverPos,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      Marker(
                        point: pickup,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ETA ${eta.inMinutes} min',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${distanceKm.toStringAsFixed(1)} km to pickup',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.booking.pickupAddress,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
