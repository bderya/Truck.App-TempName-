import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';

/// Pending job request shown to the driver (booking + pickup distance).
class PendingJobRequest {
  const PendingJobRequest({
    required this.booking,
    required this.pickupDistanceKm,
  });

  final Booking booking;
  final double pickupDistanceKm;
}

/// Provider that listens for new pending bookings and exposes them to nearby drivers.
/// Trigger: Supabase Realtime (INSERT on bookings). Alternatively wire Socket.io
/// to set state when a new pending booking is pushed from the server.
class DriverBookingNotifier extends StateNotifier<PendingJobRequest?> {
  DriverBookingNotifier({
    required this.driverId,
    required this.driverTruckType,
    required this.supabase,
    required this.locationService,
    this.maxDistanceKm = 10,
  }) : super(null) {
    if (driverId != null && driverTruckType != null) {
      _subscribe();
    }
  }

  final int? driverId;
  final String? driverTruckType;
  final SupabaseClient supabase;
  final LocationService locationService;
  final double maxDistanceKm;

  RealtimeChannel? _channel;

  void _subscribe() {
    final id = driverId!;
    _channel = supabase.channel('driver-bookings-$id').onPostgresChanges(
          schema: 'public',
          table: 'bookings',
          event: PostgresChangeEvent.insert,
          callback: _onBookingInsert,
        );
    _channel?.subscribe();
  }

  Future<void> _onBookingInsert(PostgresChangePayload payload) async {
    final record = payload.newRecord;
    if (record == null) return;

    final status = record['status'] as String?;
    if (status != 'pending') return;

    final vehicleType = record['vehicle_type_requested'] as String?;
    if (vehicleType != null &&
        driverTruckType != null &&
        vehicleType != driverTruckType) return;

    final pickupLat = (record['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (record['pickup_lng'] as num?)?.toDouble();
    if (pickupLat == null || pickupLng == null) return;

    final position = await locationService.getCurrentPosition();
    if (position == null) return;

    const distance = Distance();
    final meters = distance(
      LatLng(position.latitude, position.longitude),
      LatLng(pickupLat, pickupLng),
    );
    final km = meters / 1000;

    if (km > maxDistanceKm) return;

    final booking = Booking.fromJson(record);
    state = PendingJobRequest(booking: booking, pickupDistanceKm: km);
  }

  Future<bool> acceptJob() async {
    final current = state;
    final id = driverId;
    if (current == null || id == null) return false;

    try {
      await supabase.from('bookings').update({
        'status': 'accepted',
        'driver_id': id,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', current.booking.id);

      state = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  void declineJob() {
    state = null;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

/// Current driver's user ID. Set after login; replace with auth when available.
final driverIdProvider = StateProvider<int?>((ref) => null);

/// Alias for driverIdProvider value.
final currentDriverIdProvider = Provider<int?>((ref) => ref.watch(driverIdProvider));

/// Current driver's user profile (for is_verified, status). Fetches when driverId is set.
final currentDriverUserProvider = FutureProvider<User?>((ref) async {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', driverId)
        .maybeSingle();

    if (response == null) return null;
    return User.fromJson(response as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Provider for the current driver's tow truck. Fetches from Supabase when driverId is set.
final currentDriverTruckProvider = FutureProvider<TowTruck?>((ref) async {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('tow_trucks')
        .select()
        .eq('driver_id', driverId)
        .eq('is_available', true)
        .maybeSingle();

    if (response == null) return null;
    return TowTruck.fromJson(response as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Provider for pending job requests. Active when driver ID is set and has a truck.
final driverBookingProvider =
    StateNotifierProvider<DriverBookingNotifier, PendingJobRequest?>((ref) {
  final driverId = ref.watch(currentDriverIdProvider);
  final truckAsync = ref.watch(currentDriverTruckProvider);
  final truck = truckAsync.valueOrNull;

  return DriverBookingNotifier(
    driverId: driverId,
    driverTruckType: truck?.truckType,
    supabase: Supabase.instance.client,
    locationService: ref.watch(locationServiceProvider),
    maxDistanceKm: 10,
  );
});
