import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/is_mobile_stub.dart' if (dart.library.io) '../core/is_mobile_io.dart' as mobile;
import '../core/supabase_service.dart';

/// Keys for headless task (must be readable in isolate).
const String _keyTowTruckId = 'bg_tow_truck_id';
const String _keySupabaseUrl = 'bg_supabase_url';
const String _keySupabaseAnonKey = 'bg_supabase_anon_key';

/// Persist credentials and active tow_truck_id for headless Supabase sync when app is terminated.
Future<void> persistHeadlessContext(int towTruckId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_keyTowTruckId, towTruckId);
  await prefs.setString(_keySupabaseUrl, SupabaseService.url);
  await prefs.setString(_keySupabaseAnonKey, SupabaseService.anonKey);
}

/// Clear headless context when driver stops tracking.
Future<void> clearHeadlessContext() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyTowTruckId);
}

/// Called from headless task: sync location to Supabase using persisted context.
/// Init Supabase in this isolate and update tow_trucks.
Future<void> headlessSyncLocationToSupabase({
  required double latitude,
  required double longitude,
  double? heading,
  double? speedMs,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final towTruckId = prefs.getInt(_keyTowTruckId);
  final url = prefs.getString(_keySupabaseUrl);
  final anonKey = prefs.getString(_keySupabaseAnonKey);
  if (towTruckId == null || url == null || anonKey == null) return;

  await Supabase.initialize(url: url, anonKey: anonKey);
  final client = Supabase.instance.client;

  final speedKmh = speedMs != null ? speedMs * 3.6 : null;
  await client.from('tow_trucks').update({
    'current_latitude': latitude,
    'current_longitude': longitude,
    if (heading != null) 'current_heading': heading,
    if (speedKmh != null) 'current_speed_kmh': speedKmh,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', towTruckId);
}

/// Returns true if we should use background geolocation (mobile driver app, not web).
bool get useBackgroundGeolocation => !kIsWeb && mobile.isMobile;
