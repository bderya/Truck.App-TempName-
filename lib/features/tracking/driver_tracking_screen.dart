import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crash_reporting_service.dart';
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
    CrashReportingService.setBookingId(widget.booking.id.toString());
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
      if (booking.status == 'pending' && booking.isPriorityRematch) {
        Navigator.of(context).pop(booking);
        return;
      }
      if (booking.status == 'completed') {
        _reviewShown = true;
        final completedBooking = booking;
        ReviewPopup.show(
          context,
          driverName: null,
          onSubmit: (rating) async {
            if (rating > 0 && completedBooking.driverId != null) {
              try {
                await ref.read(supabaseClientProvider).from('driver_ratings').insert({
                  'booking_id': completedBooking.id,
                  'driver_id': completedBooking.driverId,
                  'score': rating,
                });
              } catch (_) {}
            }
            if (mounted) _openReceipt(completedBooking.id);
          },
          onDismiss: () => _openReceipt(completedBooking.id),
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
    CrashReportingService.setBookingId(null);
    _subscription?.cancel();
    _bookingSubscription?.cancel();
    _trackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_towTruck == null) {
      return Scaffold(
        appBar: AppBar(title: Text('driver_on_the_way'.tr())),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('waiting_driver_position'.tr()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('driver_on_the_way'.tr()),
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

/// Tween for smooth LatLng interpolation (required for Animation<LatLng>).
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + t * (end!.latitude - begin!.latitude),
        begin!.longitude + t * (end!.longitude - begin!.longitude),
      );
}

/// Bearing in degrees (0 = North, 90 = East) from [from] to [to].
double _bearingBetween(LatLng from, LatLng to) {
  final dLon = (to.longitude - from.longitude) * math.pi / 180;
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final y = math.sin(dLon) * math.cos(lat2);
  var bearing = math.atan2(y, x) * 180 / math.pi;
  if (bearing < 0) bearing += 360;
  return bearing;
}

class _TrackingMapState extends State<_TrackingMap> with TickerProviderStateMixin {
  LatLng? _animFrom;
  LatLng? _animTo;
  late AnimationController _positionController;
  late Animation<LatLng> _positionAnimation;
  late Animation<double> _bearingAnimation;
  double _lastBearingDeg = 0;
  Timer? _staleCheckTimer;

  static const Duration _driverMarkerAnimationDuration = Duration(seconds: 2);
  static const Duration _signalLostThreshold = Duration(seconds: 45);
  static const Duration _staleCheckInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _positionController = AnimationController(
      vsync: this,
      duration: _driverMarkerAnimationDuration,
    );
    final curved = CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeInOut,
    );
    _positionAnimation = _LatLngTween(begin: LatLng(0, 0), end: LatLng(0, 0)).animate(curved);
    _bearingAnimation = Tween<double>(begin: 0, end: 0).animate(curved);
    _staleCheckTimer = Timer.periodic(_staleCheckInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = null;
    _positionController.dispose();
    super.dispose();
  }

  bool get _isDriverSignalStale {
    final updatedAt = widget.truck.updatedAt;
    if (updatedAt == null) return true;
    final age = DateTime.now().difference(updatedAt.isUtc ? updatedAt.toLocal() : updatedAt);
    return age > _signalLostThreshold;
  }

  @override
  void didUpdateWidget(_TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.truck.currentLatitude != widget.truck.currentLatitude ||
        oldWidget.truck.currentLongitude != widget.truck.currentLongitude) {
      final from = LatLng(
        oldWidget.truck.currentLatitude,
        oldWidget.truck.currentLongitude,
      );
      final to = LatLng(
        widget.truck.currentLatitude,
        widget.truck.currentLongitude,
      );
      _animFrom = from;
      _animTo = to;
      final bearingTo = _bearingBetween(from, to);
      _positionAnimation = _LatLngTween(begin: from, end: to)
          .animate(CurvedAnimation(parent: _positionController, curve: Curves.easeInOut));
      _bearingAnimation = Tween<double>(begin: _lastBearingDeg, end: bearingTo)
          .animate(CurvedAnimation(parent: _positionController, curve: Curves.easeInOut));
      _lastBearingDeg = bearingTo;
      _positionController.forward(from: 0);
    }
  }

  LatLng _driverDisplayPosition() {
    final current = LatLng(widget.truck.currentLatitude, widget.truck.currentLongitude);
    if (_animTo == null || _animFrom == null) return current;
    return _positionAnimation.value;
  }

  double _driverDisplayBearing() {
    if (_animFrom == null || _animTo == null) return _lastBearingDeg;
    return _bearingAnimation.value;
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
        if (_isDriverSignalStale)
          Material(
            color: Colors.amber.shade700,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.signal_cellular_off, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'driver_signal_lost'.tr(),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: AnimatedBuilder(
            animation: _positionController,
            builder: (context, _) {
              final driverPos = _driverDisplayPosition();
              final bearingDeg = _driverDisplayBearing();
              final bearingRad = (bearingDeg - 90) * math.pi / 180;
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
                        child: Transform.rotate(
                          angle: bearingRad,
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
                  'ETA ${eta.inMinutes} ${'eta_min'.tr()}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${distanceKm.toStringAsFixed(1)} ${'km_to_pickup'.tr()}',
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
