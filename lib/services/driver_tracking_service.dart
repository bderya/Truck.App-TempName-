import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Listens to a specific tow_truck row via Supabase Realtime for client-side driver tracking.
class DriverTrackingService {
  DriverTrackingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  RealtimeChannel? _channel;

  /// Stream of the assigned tow truck's position updates (for the client).
  /// Only emits when the given [towTruckId] row is updated.
  Stream<TowTruck?> watchTowTruck(int towTruckId) async* {
    final controller = StreamController<TowTruck?>.broadcast();

    _channel?.unsubscribe();
    _channel = _client.channel('tow-truck-$towTruckId').onPostgresChanges(
          schema: 'public',
          table: 'tow_trucks',
          event: PostgresChangeEvent.update,
          callback: (payload) {
            final record = payload.newRecord;
            if (record == null) return;
            final id = record['id'] as int?;
            if (id != towTruckId) return;
            try {
              controller.add(TowTruck.fromJson(record as Map<String, dynamic>));
            } catch (_) {
              controller.add(null);
            }
          },
        ).onPostgresChanges(
          schema: 'public',
          table: 'tow_trucks',
          event: PostgresChangeEvent.insert,
          callback: (_) {},
        );
    _channel?.subscribe();

    yield* controller.stream;
  }

  /// Fetches the tow truck for the driver assigned to [booking], then returns
  /// a stream that emits whenever that truck's row is updated.
  Stream<TowTruck?> watchDriverForBooking(Booking booking) async* {
    if (booking.driverId == null) return;

    final res = await _client
        .from('tow_trucks')
        .select()
        .eq('driver_id', booking.driverId!)
        .maybeSingle();

    if (res == null) return;
    final truck = TowTruck.fromJson(res as Map<String, dynamic>);
    yield truck;
    yield* watchTowTruck(truck.id);
  }

  /// Watches a booking by id (e.g. to detect when a driver accepts and driver_id is set).
  /// Use this so the client can navigate to [DriverTrackingScreen] when [Booking.driverId] is non-null.
  Stream<Booking?> watchBookingById(int bookingId) async* {
    final controller = StreamController<Booking?>.broadcast();
    final channel = _client.channel('booking-$bookingId').onPostgresChanges(
          schema: 'public',
          table: 'bookings',
          event: PostgresChangeEvent.update,
          callback: (payload) {
            final record = payload.newRecord;
            if (record == null) return;
            final id = record['id'] as int?;
            if (id != bookingId) return;
            try {
              controller.add(Booking.fromJson(record as Map<String, dynamic>));
            } catch (_) {
              controller.add(null);
            }
          },
        );
    channel.subscribe();
    yield* controller.stream;
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
