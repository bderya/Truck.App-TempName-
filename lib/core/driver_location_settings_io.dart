import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';

/// Battery-optimized settings: 10 m distance filter, 5 s interval.
/// On Android: foreground notification so location continues in background.
LocationSettings getDriverTrackingLocationSettings() {
  if (Platform.isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Konum paylaşılıyor',
        notificationText: 'Müşteri sizi takip edebilsin diye konumunuz gönderiliyor.',
        notificationChannelName: 'Sürücü konum servisi',
        enableWakeLock: true,
      ),
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );
}
