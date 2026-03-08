import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../services/payment/payment_types.dart';
import '../auth/providers/auth_state_provider.dart';
import '../auth/widgets/lazy_auth_bottom_sheet.dart';
import 'route_helper.dart';
import 'widgets/add_card_sheet.dart';
import 'widgets/payment_failure_sheet.dart';

/// Vehicle type for UI: Car = standard, Bike = motorcycle, Truck = heavy.
const _vehicleOptions = [
  ('car', 'standard', Icons.directions_car_rounded),
  ('bike', 'motorcycle', Icons.two_wheeler_rounded),
  ('truck', 'heavy', Icons.local_shipping_rounded),
];

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.userLocation,
    required this.destinationLocation,
    this.pickupAddress = 'Pickup',
    this.destinationAddress = 'Destination',
    this.clientId,
  });

  final LatLng userLocation;
  final LatLng destinationLocation;
  final String pickupAddress;
  final String destinationAddress;
  final int? clientId;

  @override
  ConsumerState<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends ConsumerState<BookingConfirmationScreen> {
  List<LatLng> _routePoints = [];
  bool _routeLoading = true;
  int _selectedIndex = 0;
  bool _isMatching = false;
  bool _isAuthorizing = false;
  /// For intercity: desired pickup date/time (null = ASAP).
  DateTime? _desiredPickupAt;

  String get _vehicleType => _vehicleOptions[_selectedIndex].$2;
  bool get _isIntercity => _distanceKm >= AppConstants.intercityDistanceThresholdKm;

  /// Resolves client, ensures saved card, runs pre-auth, then creates booking with payment_id.
  Future<void> _onRequestTow() async {
    int? clientId = widget.clientId;
    User? currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser != null && currentUser.userType == 'client') {
      clientId = currentUser.id;
    }
    if (clientId == null) {
      final user = await showLazyAuthBottomSheet(context);
      if (user != null) {
        ref.invalidate(authStatusProvider);
        clientId = user.id;
        currentUser = user;
      }
    }
    if (clientId == null) return;

    currentUser = ref.read(currentAppUserProvider).valueOrNull ?? currentUser;
    if (currentUser == null) {
      final u = await ref.read(currentAppUserProvider.future);
      currentUser = u;
    }

    String? cardTokenId = currentUser?.defaultCardTokenId;
    if (cardTokenId == null || cardTokenId.isEmpty) {
      final added = await showAddCardSheet(context, userId: clientId);
      if (!added || !mounted) return;
      final updated = await ref.read(currentAppUserProvider.future);
      cardTokenId = updated?.defaultCardTokenId;
    }
    if (cardTokenId == null || cardTokenId.isEmpty) return;

    setState(() => _isAuthorizing = true);
    final authResult = await ref.read(paymentServiceProvider).authorizeOnly(
          cardTokenId: cardTokenId,
          amount: _price,
          currency: 'TRY',
          customerId: clientId.toString(),
        );
    if (mounted) setState(() => _isAuthorizing = false);

    if (authResult is PaymentFailure) {
      if (mounted) {
        await showPaymentFailureSheet(
          context,
          failure: authResult,
          userId: clientId,
          onUpdatePaymentMethod: () => _onRequestTow(),
        );
      }
      return;
    }

    final paymentId = (authResult as PaymentSuccess<String>).data;
    if (mounted) _startMatching(clientId, paymentId: paymentId);
  }

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final points = await getRoutePoints(
      originLat: widget.userLocation.latitude,
      originLng: widget.userLocation.longitude,
      destLat: widget.destinationLocation.latitude,
      destLng: widget.destinationLocation.longitude,
    );
    if (mounted) setState(() { _routePoints = points; _routeLoading = false; });
  }

  double get _distanceKm {
    if (_routePoints.length < 2) return 0;
    const distance = Distance();
    double meters = 0;
    for (int i = 1; i < _routePoints.length; i++) {
      meters += distance(_routePoints[i - 1], _routePoints[i]);
    }
    return meters / 1000;
  }

  /// Price: (Base + (Distance * Rate)) * Multiplier. Intercity >100km: discounted rate + tolls.
  double get _price {
    final base = AppConstants.basePriceByVehicleType[_vehicleType] ?? 50;
    var rate = AppConstants.ratePerKmByVehicleType[_vehicleType] ?? 3.5;
    final mult = AppConstants.vehicleMultiplierByType[_vehicleType] ?? 1.0;
    if (_distanceKm >= AppConstants.intercityDiscountThresholdKm) {
      rate *= AppConstants.intercityRateMultiplier;
    }
    final tolls = _isIntercity ? _distanceKm * AppConstants.intercityTollPerKm : 0.0;
    return (base + (_distanceKm * rate)) * mult + tolls;
  }

  double? get _estimatedTolls => _isIntercity ? _distanceKm * AppConstants.intercityTollPerKm : null;

  Future<void> _startMatching(int clientId, {String? paymentId}) async {
    setState(() => _isMatching = true);

    try {
      final res = await ref.read(supabaseClientProvider)
          .from('bookings')
          .insert({
            'client_id': clientId,
            'pickup_address': widget.pickupAddress,
            'destination_address': widget.destinationAddress,
            'pickup_lat': widget.userLocation.latitude,
            'pickup_lng': widget.userLocation.longitude,
            'destination_lat': widget.destinationLocation.latitude,
            'destination_lng': widget.destinationLocation.longitude,
            'price': _price,
            'vehicle_type_requested': _vehicleType,
            'status': 'pending',
            'is_intercity': _isIntercity,
            if (_desiredPickupAt != null) 'desired_pickup_at': _desiredPickupAt!.toIso8601String(),
            if (_estimatedTolls != null) 'estimated_tolls': _estimatedTolls,
            if (paymentId != null && paymentId.isNotEmpty) 'payment_id': paymentId,
          })
          .select()
          .single();

      final booking = Booking.fromJson(res as Map<String, dynamic>);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tow request sent. Searching for nearby drivers...'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(booking);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (widget.userLocation.latitude + widget.destinationLocation.latitude) / 2,
      (widget.userLocation.longitude + widget.destinationLocation.longitude) / 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm booking'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12,
                    minZoom: 5,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cekici.cekici',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.userLocation,
                          width: 32,
                          height: 32,
                          child: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                        ),
                        Marker(
                          point: widget.destinationLocation,
                          width: 32,
                          height: 32,
                          child: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.flag, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_routeLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (_isAuthorizing || _isMatching)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        if (_isMatching) _RippleOverlay(),
                        Container(
                          color: Colors.black26,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _isAuthorizing
                                      ? 'Authorizing payment...'
                                      : 'Searching for nearby drivers...',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isIntercity) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.route, color: Theme.of(context).colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Text(
                            'Intercity trip (${_distanceKm.toStringAsFixed(0)} km)',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Desired pickup',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _desiredPickupAt = null),
                            icon: Icon(_desiredPickupAt == null ? Icons.check_circle : Icons.circle_outlined, size: 20),
                            label: const Text('ASAP'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _desiredPickupAt == null
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date == null || !mounted) return;
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time == null || !mounted) return;
                              setState(() => _desiredPickupAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                            },
                            icon: Icon(_desiredPickupAt != null ? Icons.check_circle : Icons.calendar_today, size: 20),
                            label: Text(_desiredPickupAt != null
                                ? '${_desiredPickupAt!.day}/${_desiredPickupAt!.month}/${_desiredPickupAt!.year} ${_desiredPickupAt!.hour.toString().padLeft(2, '0')}:${_desiredPickupAt!.minute.toString().padLeft(2, '0')}'
                                : 'Pick date'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _desiredPickupAt != null
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Vehicle type',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_vehicleOptions.length, (i) {
                      final (label, _, icon) = _vehicleOptions[i];
                      final selected = _selectedIndex == i;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Material(
                            color: selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => setState(() => _selectedIndex = i),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      icon,
                                      size: 28,
                                      color: selected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label == 'car'
                                          ? 'Car'
                                          : label == 'bike'
                                              ? 'Bike'
                                              : 'Truck',
                                      style: TextStyle(
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                        color: selected
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Estimated price',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isIntercity && _estimatedTolls != null
                        ? '(Base + distance × rate) × multiplier + tolls (${_estimatedTolls!.toStringAsFixed(0)} ${AppConstants.currencySymbol})'
                        : '(Base + (Distance × Rate)) × Multiplier',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: (_isAuthorizing || _isMatching) ? null : _onRequestTow,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isMatching
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Request Tow'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing ripple overlay on the map during matching.
class _RippleOverlay extends StatefulWidget {
  @override
  State<_RippleOverlay> createState() => _RippleOverlayState();
}

class _RippleOverlayState extends State<_RippleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(
            progress: _animation.value,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.width + size.height) * 0.3 * progress;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, paint);
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, maxRadius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.progress != progress;
}
