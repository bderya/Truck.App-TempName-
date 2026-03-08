import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'background_geolocation_service.dart';

/// Headless task: receives location events when app is terminated.
/// Must be top-level. Register in main.dart with BackgroundGeolocation.registerHeadlessTask(backgroundGeolocationHeadlessTask).
@pragma('vm:entry-point')
void backgroundGeolocationHeadlessTask(bg.HeadlessEvent headlessEvent) async {
  switch (headlessEvent.name) {
    case bg.Event.LOCATION:
      final location = headlessEvent.event as bg.Location;
      final c = location.coords;
      await headlessSyncLocationToSupabase(
        latitude: c.latitude,
        longitude: c.longitude,
        heading: c.heading,
        speedMs: c.speed,
      );
      break;
    default:
      break;
  }
}
