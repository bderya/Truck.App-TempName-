# Production-Ready Real-Time Tracking

## Driver: background and battery

### Background service (Android)

- **LocationService.startHighFrequencyLocationSync** (and **startBackgroundCapableLocationStream**) use **getPositionStream** with platform settings.
- **Android**: `geolocator_android.AndroidSettings` with **ForegroundNotificationConfig** so location continues when the app is in background or the screen is off. A persistent notification is shown ("Konum paylaşılıyor").
- **iOS**: Use **LocationSettings** with `distanceFilter: 10`. Enable **Background Modes → Location updates** in Xcode and add `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` in Info.plist.

### Battery optimization

- **Distance filter**: 10 m – position is emitted only after the device moves at least 10 m.
- **Interval**: 5 s – on Android, `intervalDuration: Duration(seconds: 5)` limits update frequency; the stream is also throttled so Supabase is updated at most every 5 seconds when using the stream.
- Driver flow: when the driver opens the job navigation screen, **startHighFrequencyLocationSync** is called with the above settings (and 2 s minimum interval for high-frequency mode).

### Required configuration

- **Android**: `AndroidManifest.xml` – `ACCESS_BACKGROUND_LOCATION` and `ACCESS_FINE_LOCATION`. For foreground service: no extra permission beyond location.
- **iOS**: Info.plist – `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`; Xcode → Signing & Capabilities → Background Modes → Location updates.

## Client: smoothing and signal lost

### Smooth marker (2–3 s)

- The driver marker animates between the previous and current position over **2.5 s** (`_driverMarkerAnimationDuration = 2500 ms`) with **Curves.easeInOut**.
- Implemented in **DriverTrackingScreen** → **_TrackingMapState**: `didUpdateWidget` starts the animation when `truck.currentLatitude`/`currentLongitude` change; **AnimatedBuilder** uses the interpolated position for the marker.

### Signal lost

- If the driver’s last position update is older than **45 s** (`_signalLostThreshold`), the client shows an amber banner: **"Sürücü konumu güncellenemiyor. Sinyal kaybı olabilir."**
- **Last update time**: from `TowTruck.updatedAt` (set by Supabase when the driver’s app updates `tow_trucks`).
- A **Timer** runs every **5 s** to re-check staleness and refresh the banner.

## Files

- **lib/services/location_service.dart**: Background-capable stream, distance filter, interval, throttle, Supabase sync.
- **lib/core/driver_location_settings_stub.dart**: Default settings (e.g. web).
- **lib/core/driver_location_settings_io.dart**: Android (foreground notification + distance/interval) and iOS (distance filter).
- **lib/features/tracking/driver_tracking_screen.dart**: 2.5 s marker animation, signal-lost banner, stale-check timer.
