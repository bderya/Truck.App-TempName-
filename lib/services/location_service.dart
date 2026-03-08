import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Service for location permissions, GPS streaming to Supabase, and nearby truck queries.
class LocationService {
  LocationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Timer? _syncTimer;

  /// Requests background (always) location permission.
  /// On Android 10+, you must first have foreground permission before requesting background.
  /// Returns [LocationPermission.always] if granted, or the actual permission state.
  Future<LocationPermission> requestBackgroundLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return LocationPermission.denied;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse) {
      // On Android 10+, request background permission separately
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Starts streaming the driver's GPS coordinates to Supabase every [intervalSeconds].
  /// Updates the [towTruckId] row in [tow_trucks] with current latitude/longitude.
  /// Call when a job is active; call [stopLocationStream] when job ends or driver goes offline.
  void startLocationStreamToSupabase({
    required int towTruckId,
    int intervalSeconds = 5,
  }) {
    stopLocationStream();

    _syncTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _syncPositionToSupabase(towTruckId),
    );

    // Sync immediately on start
    _syncPositionToSupabase(towTruckId);
  }

  Future<void> _syncPositionToSupabase(int towTruckId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _supabase.from('tow_trucks').update({
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', towTruckId);
    } catch (e) {
      // Log or handle error - e.g. permission denied, no fix
    }
  }

  /// Stops the location stream and timer.
  void stopLocationStream() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Fetches the nearest [limit] available tow trucks within [radiusKm] of the given point.
  /// Uses a PostGIS RPC function for efficient spatial indexing.
  ///
  /// **Requires** the `get_nearest_available_tow_trucks` RPC to be created in your database.
  /// Run the migration in `supabase/migrations/get_nearest_tow_trucks.sql`.
  Future<List<TowTruck>> getNearestAvailableTowTrucks({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 5,
  }) async {
    final response = await _supabase.rpc(
      'get_nearest_available_tow_trucks',
      params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_km': radiusKm,
        'p_limit': limit,
      },
    );

    if (response == null || response is! List) return [];

    return (response as List)
        .map((e) => TowTruck.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One-shot: get current position. For permission flow, use [requestBackgroundLocationPermission] first.
  Future<Position?> getCurrentPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
