import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';

/// Pending job request shown to the driver (booking + pickup distance).
/// [isAdminAssigned] true when status is 'assigned' (operator assigned this job to this driver).
class PendingJobRequest {
  const PendingJobRequest({
    required this.booking,
    required this.pickupDistanceKm,
    this.isAdminAssigned = false,
  });

  final Booking booking;
  final double pickupDistanceKm;
  final bool isAdminAssigned;
}

/// Provider that listens for new pending bookings and exposes them to nearby drivers.
/// Intercity jobs are only shown when [openToIntercity] is true.
class DriverBookingNotifier extends StateNotifier<PendingJobRequest?> {
  DriverBookingNotifier({
    required this.driverId,
    required this.driverTruckType,
    required this.supabase,
    required this.locationService,
    this.maxDistanceKm = 10,
    this.openToIntercity = false,
    this.isInspected = true,
    this.isUnderReview = false,
    this.isActive = true,
    this.isAvailable = true,
    this.tierCategory,
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
  final bool openToIntercity;
  /// When false, driver cannot take jobs (weekly inspection not done).
  final bool isInspected;
  /// When true, driver is in review (rating < 3.5) and hidden from jobs.
  final bool isUnderReview;
  /// When false, driver is suspended (e.g. 3 cancels in 7 days).
  final bool isActive;
  /// When false, driver is offline (shift toggle); do not show job requests.
  final bool isAvailable;
  /// Gold, Silver, Bronze. High-value jobs only go to Gold.
  final String? tierCategory;

  RealtimeChannel? _channel;

  void _subscribe() {
    final id = driverId!;
    _channel = supabase.channel('driver-bookings-$id')
      .onPostgresChanges(
        schema: 'public',
        table: 'bookings',
        event: PostgresChangeEvent.insert,
        callback: _onBookingInsert,
      )
      .onPostgresChanges(
        schema: 'public',
        table: 'bookings',
        event: PostgresChangeEvent.update,
        callback: _onBookingUpdate,
      );
    _channel?.subscribe();
  }

  /// Re-opened after driver cancel: status → pending, is_priority_rematch = true.
  /// Admin assign: status → assigned, driver_id = me → show admin-assigned UI.
  Future<void> _onBookingUpdate(PostgresChangePayload payload) async {
    final record = payload.newRecord;
    if (record == null) return;
    final status = record['status'] as String?;
    final driverIdRaw = record['driver_id'];
    final assignedDriverId = driverIdRaw != null ? (driverIdRaw is int ? driverIdRaw : int.tryParse(driverIdRaw.toString())) : null;

    if (status == 'assigned' && assignedDriverId == driverId) {
      await _showAdminAssignedJob(record);
      return;
    }

    final isPriorityRematch = record['is_priority_rematch'] as bool? ?? false;
    if (status != 'pending' || !isPriorityRematch) return;
    await _onBookingInsert(payload);
  }

  Future<void> _showAdminAssignedJob(Map<String, dynamic> record) async {
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
    final booking = Booking.fromJson(record);
    state = PendingJobRequest(booking: booking, pickupDistanceKm: km, isAdminAssigned: true);
  }

  Future<void> _onBookingInsert(PostgresChangePayload payload) async {
    final record = payload.newRecord;
    if (record == null) return;

    final status = record['status'] as String?;
    if (status != 'pending') return;

    if (!isInspected || isUnderReview || !isActive || !isAvailable) return;

    final vehicleValueTier = record['vehicle_value_tier'] as String?;
    if (vehicleValueTier == 'high' && tierCategory != 'Gold') return;

    final isIntercity = record['is_intercity'] as bool? ?? false;
    if (isIntercity && !openToIntercity) return;

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

  /// Calls the accept_booking RPC so only the first driver to accept gets the job (race-safe).
  Future<bool> acceptJob() async {
    final current = state;
    final id = driverId;
    if (current == null || id == null) return false;

    try {
      final res = await supabase.rpc(
        'accept_booking',
        params: {
          'p_booking_id': current.booking.id,
          'p_driver_id': id,
          'p_estimated_arrival_minutes': 15,
        },
      );
      state = null;

      final map = res as Map<String, dynamic>?;
      final ok = map?['ok'] as bool?;
      return ok == true;
    } catch (_) {
      state = null;
      return false;
    }
  }

  void declineJob() {
    state = null;
  }

  /// Confirms an admin-assigned job (status assigned → accepted). Returns true on success.
  Future<bool> confirmAdminAssignedJob() async {
    final current = state;
    final id = driverId;
    if (current == null || id == null || !current.isAdminAssigned) return false;

    try {
      final res = await supabase.rpc(
        'confirm_admin_assigned_booking',
        params: {
          'p_booking_id': current.booking.id,
          'p_driver_id': id,
        },
      );
      state = null;
      final map = res as Map<String, dynamic>?;
      final ok = map?['ok'] as bool?;
      return ok == true;
    } catch (_) {
      state = null;
      return false;
    }
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
    final client = ref.read(supabaseClientProvider);
    final response = await client
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
    final client = ref.read(supabaseClientProvider);
    final response = await client
        .from('tow_trucks')
        .select()
        .eq('driver_id', driverId)
        .maybeSingle();

    if (response == null) return null;
    return TowTruck.fromJson(response as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Provider for pending job requests. Active when driver ID is set and has a truck.
/// Excludes drivers not inspected (weekly audit) or under review (rating < 3.5).
/// High-value jobs only go to Gold tier.
final driverBookingProvider =
    StateNotifierProvider<DriverBookingNotifier, PendingJobRequest?>((ref) {
  final driverId = ref.watch(currentDriverIdProvider);
  final truckAsync = ref.watch(currentDriverTruckProvider);
  final userAsync = ref.watch(currentDriverUserProvider);
  final truck = truckAsync.valueOrNull;
  final user = userAsync.valueOrNull;

  return DriverBookingNotifier(
    driverId: driverId,
    driverTruckType: truck?.truckType,
    supabase: ref.watch(supabaseClientProvider),
    locationService: ref.watch(locationServiceProvider),
    maxDistanceKm: 10,
    openToIntercity: truck?.openToIntercity ?? false,
    isInspected: truck?.isInspected ?? true,
    isUnderReview: user?.isUnderReview ?? false,
    isActive: user?.isActive ?? true,
    isAvailable: truck?.isAvailable ?? true,
    tierCategory: truck?.tierCategory,
  );
});
