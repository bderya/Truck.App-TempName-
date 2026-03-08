import 'package:geolocator/geolocator.dart';

/// Default location settings (e.g. web): distance filter and high accuracy.
LocationSettings getDriverTrackingLocationSettings() {
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );
}
