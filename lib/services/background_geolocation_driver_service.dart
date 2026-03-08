import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'background_geolocation_service.dart';

/// Whether to use flutter_background_geolocation (mobile only).
bool get _useBg => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Configures and runs flutter_background_geolocation for driver tracking:
/// HIGH accuracy, 10 m distance filter, stopOnTerminate: false, startOnBoot: true,
/// persistent notification, headless Supabase sync when app is terminated.
class BackgroundGeolocationDriverService {
  BackgroundGeolocationDriverService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  int? _activeTowTruckId;
  bool _configured = false;

  /// One-time configuration. Call from app startup (e.g. main or first driver screen).
  Future<void> ensureConfigured() async {
    if (!_useBg || _configured) return;
    try {
      await bg.BackgroundGeolocation.ready(_config());
      await bg.BackgroundGeolocation.onLocation(_onLocation);
      _configured = true;
    } catch (_) {}
  }

  bg.Config _config() {
    return bg.Config(
      geolocation: bg.GeoConfig(
        desiredAccuracy: bg.GeoConfig.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10.0,
      ),
      app: bg.AppConfig(
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        notification: bg.Notification(
          title: 'Aktif Görevde',
          text: 'Konumunuz müşteriye iletiliyor',
          channelName: 'Sürücü konum',
        ),
      ),
    );
  }

  /// Start tracking and syncing to Supabase for this [towTruckId].
  /// Saves context for headless task. Call when driver has an active job.
  Future<void> start(int towTruckId) async {
    if (!_useBg) return;
    await ensureConfigured();
    _activeTowTruckId = towTruckId;
    await persistHeadlessContext(towTruckId);

    await bg.BackgroundGeolocation.start();
  }

  Future<void> _onLocation(bg.Location location) async {
    final id = _activeTowTruckId;
    if (id == null) return;
    final c = location.coords;
    final lat = c.latitude;
    final lng = c.longitude;
    final heading = c.heading;
    final speedMs = c.speed;
    final speedKmh = speedMs != null && speedMs >= 0 ? speedMs * 3.6 : null;

    try {
      await _supabase.from('tow_trucks').update({
        'current_latitude': lat,
        'current_longitude': lng,
        if (heading != null && heading >= 0) 'current_heading': heading,
        if (speedKmh != null) 'current_speed_kmh': speedKmh,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (_) {}
  }

  /// Stop tracking and clear headless context.
  Future<void> stop() async {
    if (!_useBg) return;
    _activeTowTruckId = null;
    await clearHeadlessContext();
    try {
      await bg.BackgroundGeolocation.stop();
    } catch (_) {}
  }
}
