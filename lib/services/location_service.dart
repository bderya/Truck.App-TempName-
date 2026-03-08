import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/driver_location_settings_stub.dart'
    if (dart.library.io) '../core/driver_location_settings_io.dart' as driver_loc;
import '../models/models.dart';

/// Service for location permissions, GPS streaming to Supabase, and nearby truck queries.
/// Supports background-capable streaming with distance filter and interval for battery optimization.
class LocationService {
  LocationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Timer? _syncTimer;
  StreamSubscription<Position>? _positionSubscription;
  int? _activeTowTruckId;
  DateTime? _lastSyncAt;
  static const Duration _minSyncInterval = Duration(seconds: 5);

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

  /// Starts a **background-capable** location stream: distance filter 10 m, min interval 5 s.
  /// On Android, shows a foreground notification so updates continue when app is in background or screen is off.
  /// Call when driver has an active job; call [stopLocationStream] when job ends.
  void startBackgroundCapableLocationStream({
    required int towTruckId,
    int distanceFilterMeters = 10,
    Duration minInterval = const Duration(seconds: 5),
  }) {
    stopLocationStream();
    _activeTowTruckId = towTruckId;
    _lastSyncAt = null;

    final settings = driver_loc.getDriverTrackingLocationSettings();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) => _onPositionUpdate(position, minInterval),
      onError: (_) {
        // GPS/signal error – client will show "Signal lost" when no updates
      },
      cancelOnError: false,
    );
  }

  void _onPositionUpdate(Position position, Duration minInterval) {
    final now = DateTime.now();
    if (_lastSyncAt != null && now.difference(_lastSyncAt!) < minInterval) {
      return;
    }
    _lastSyncAt = now;
    _syncPositionToSupabaseRaw(
      _activeTowTruckId!,
      position.latitude,
      position.longitude,
    );
  }

  /// Starts streaming the driver's GPS coordinates to Supabase every [intervalSeconds].
  /// Prefer [startBackgroundCapableLocationStream] for active jobs (background + battery-friendly).
  void startLocationStreamToSupabase({
    required int towTruckId,
    int intervalSeconds = 5,
  }) {
    stopLocationStream();

    _syncTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _syncPositionToSupabase(towTruckId),
    );

    _syncPositionToSupabase(towTruckId);
  }

  /// High-frequency location sync for the Driver app.
  /// Uses **background-capable** stream: 10 m distance filter, 5 s interval, foreground notification on Android.
  /// Call [stopLocationStream] when done.
  void startHighFrequencyLocationSync({
    required int towTruckId,
    int intervalSeconds = 2,
  }) {
    startBackgroundCapableLocationStream(
      towTruckId: towTruckId,
      distanceFilterMeters: 10,
      minInterval: Duration(seconds: intervalSeconds.clamp(2, 10)),
    );
  }

  Future<void> _syncPositionToSupabase(int towTruckId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _syncPositionToSupabaseRaw(
        towTruckId,
        position.latitude,
        position.longitude,
      );
    } catch (_) {}
  }

  Future<void> _syncPositionToSupabaseRaw(
    int towTruckId,
    double lat,
    double lng,
  ) async {
    try {
      await _supabase.from('tow_trucks').update({
        'current_latitude': lat,
        'current_longitude': lng,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', towTruckId);
    } catch (_) {}
  }

  /// Stops the location stream and any timer.
  void stopLocationStream() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeTowTruckId = null;
    _lastSyncAt = null;
  }

  /// Fetches the nearest [limit] available tow trucks within [radiusKm] of the given point.
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

  /// One-shot: get current position.
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
