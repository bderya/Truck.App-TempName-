import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Topic used for job alerts. Backend should send to this topic; we subscribe when online, unsubscribe when offline.
const String driverJobAlertsTopic = 'driver_job_alerts';

/// Manages driver online/offline state: DB (tow_trucks.is_available), location stream, and FCM job-alert topic.
class DriverOnlineService {
  DriverOnlineService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Sets driver online/offline in DB and triggers location/FCM. Call [setOnline] from UI.
  /// When going offline, [sendLastSeenThenSetOffline] stops location, sends one position, then sets is_available = false.
  Future<void> setOnline({
    required int towTruckId,
    required bool online,
    required void Function(int towTruckId) startLocationStream,
    required void Function() stopLocationStream,
  }) async {
    if (online) {
      await _supabase.from('tow_trucks').update({
        'is_available': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', towTruckId);
      startLocationStream(towTruckId);
      await _subscribeToJobAlerts();
    } else {
      await sendLastSeenThenSetOffline(
        towTruckId: towTruckId,
        stopLocationStream: stopLocationStream,
      );
      await _unsubscribeFromJobAlerts();
    }
  }

  /// Stops location stream, sends one final position to server, then sets is_available = false.
  Future<void> sendLastSeenThenSetOffline({
    required int towTruckId,
    required void Function() stopLocationStream,
  }) async {
    stopLocationStream();
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      await _supabase.from('tow_trucks').update({
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'is_available': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', towTruckId);
    } catch (_) {
      await _supabase.from('tow_trucks').update({
        'is_available': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', towTruckId);
    }
  }

  Future<void> _subscribeToJobAlerts() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(driverJobAlertsTopic);
    } catch (_) {}
  }

  Future<void> _unsubscribeFromJobAlerts() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(driverJobAlertsTopic);
    } catch (_) {}
  }

  /// Returns true if the driver has any booking in status accepted, on_the_way, or picked_up.
  Future<bool> hasActiveJob(int driverId) async {
    try {
      final res = await _supabase
          .from('bookings')
          .select('id')
          .eq('driver_id', driverId)
          .inFilter('status', ['accepted', 'on_the_way', 'picked_up'])
          .limit(1);
      return res != null && res.isNotEmpty;
    } catch (_) {
      return true;
    }
  }
}
