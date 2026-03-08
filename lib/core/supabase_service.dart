import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Central Supabase client for dual-app architecture (Client + Driver).
/// Call [initialize] once at startup (e.g. in main.dart).
class SupabaseService {
  SupabaseService._();

  static String? _url;
  static String? _anonKey;
  static bool _initialized = false;

  /// Supabase project URL. Set before [initialize] or pass to [initialize].
  static String get url => _url ?? 'YOUR_SUPABASE_URL';

  /// Supabase anon (public) key. Set before [initialize] or pass to [initialize].
  static String get anonKey => _anonKey ?? 'YOUR_SUPABASE_ANON_KEY';

  /// Whether [initialize] has been called.
  static bool get isInitialized => _initialized;

  /// Initializes the Supabase connection. Call once at app startup.
  /// [httpClient] optional: e.g. [SupabaseHttpClient] to report non-200 as non-fatal.
  static Future<void> initialize({
    String? url,
    String? anonKey,
    http.Client? httpClient,
  }) async {
    _url = url ?? _url;
    _anonKey = anonKey ?? _anonKey;
    await Supabase.initialize(
      url: SupabaseService.url,
      anonKey: SupabaseService.anonKey,
      httpClient: httpClient,
    );
    _initialized = true;
  }

  /// Central Supabase client. Use this (or [Supabase.instance.client]) after [initialize].
  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'SupabaseService not initialized. Call SupabaseService.initialize() in main() before runApp.',
      );
    }
    return Supabase.instance.client;
  }

  // ---------------------------------------------------------------------------
  // Unified login: profile with user_type after SMS OTP verification
  // ---------------------------------------------------------------------------

  /// Fetches the app profile (users table) by phone after SMS OTP verification.
  /// Returns the profile including [user_type] ('client' | 'driver') for routing.
  /// Use after [AuthService.verifyOtp]; then route Client app vs Driver app by [User.userType].
  static Future<User?> getProfileAfterAuth(String phoneNumber) async {
    final res = await client
        .from('users')
        .select()
        .eq('phone_number', phoneNumber)
        .maybeSingle();
    if (res == null) return null;
    return User.fromJson(res as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Real-time: Client – listen to bookings where client_id = me (driver accept)
  // ---------------------------------------------------------------------------

  static RealtimeChannel? _clientBookingsChannel;

  /// Listens to [bookings] table for rows where [clientId] is the client.
  /// Use in the Client app to react when a driver accepts (e.g. status/driver_id update).
  static Stream<Booking> subscribeToBookingsForClient(int clientId) {
    final controller = StreamController<Booking>.broadcast();

    _clientBookingsChannel?.unsubscribe();
    _clientBookingsChannel = client
        .channel('client-bookings-$clientId')
        .onPostgresChanges(
          schema: 'public',
          table: 'bookings',
          event: PostgresChangeEvent.update,
          callback: (payload) {
            final record = payload.newRecord;
            if (record == null) return;
            final cid = record['client_id'] as int?;
            if (cid != clientId) return;
            try {
              controller.add(Booking.fromJson(record as Map<String, dynamic>));
            } catch (_) {}
          },
        )
        .onPostgresChanges(
          schema: 'public',
          table: 'bookings',
          event: PostgresChangeEvent.insert,
          callback: (payload) {
            final record = payload.newRecord;
            if (record == null) return;
            final cid = record['client_id'] as int?;
            if (cid != clientId) return;
            try {
              controller.add(Booking.fromJson(record as Map<String, dynamic>));
            } catch (_) {}
          },
        );
    _clientBookingsChannel?.subscribe();

    return controller.stream;
  }

  /// Unsubscribes the client bookings channel. Call when leaving the client booking flow.
  static void unsubscribeClientBookings() {
    _clientBookingsChannel?.unsubscribe();
    _clientBookingsChannel = null;
  }

  // ---------------------------------------------------------------------------
  // Real-time: Driver – listen to new 'pending' booking requests
  // ---------------------------------------------------------------------------

  /// Listens to [bookings] table for INSERT events (new requests).
  /// Filter by status = 'pending' and by distance/vehicle type on the client (Driver app).
  /// Returns the raw [PostgresChangePayload] for each insert; parse and filter locally.
  static Stream<PostgresChangePayload> subscribeToPendingBookingsForDriver() {
    final controller = StreamController<PostgresChangePayload>.broadcast();
    final channel = client
        .channel('driver-pending-bookings')
        .onPostgresChanges(
          schema: 'public',
          table: 'bookings',
          event: PostgresChangeEvent.insert,
          callback: controller.add,
        );
    channel.subscribe();
    return controller.stream;
  }
}
