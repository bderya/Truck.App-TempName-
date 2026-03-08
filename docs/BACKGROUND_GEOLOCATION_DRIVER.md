# Background Geolocation (Driver App)

Production-ready driver location tracking using **flutter_background_geolocation** (Transistor Software) with Supabase sync and a custom permission rationale for store approval.

## Features

- **Plugin**: `flutter_background_geolocation` (gold standard for production).
- **Config**: `desiredAccuracy: HIGH`, `distanceFilter: 10`, `stopOnTerminate: false`, `startOnBoot: true`.
- **Foreground notification**: Title **"Aktif Görevde"**, body **"Konumunuz müşteriye iletiliyor"** (Android).
- **Headless task**: Sends `latitude`, `longitude`, `heading`, and `speed` to the `tow_trucks` table even when the app is terminated.
- **Permission flow**: Custom dialog explaining why "Always Allow" is needed, then the OS system prompt (for App Store / Play Store approval).

## Database

- **Migration**: `supabase/migrations/20250126000000_tow_trucks_heading_speed.sql` adds:
  - `tow_trucks.current_heading` (degrees 0–360)
  - `tow_trucks.current_speed_kmh` (km/h)

## Flow

1. Driver accepts a job → navigates to `JobNavigationScreen`.
2. If mobile (Android/iOS), a **custom rationale dialog** is shown (why we need "Always Allow").
3. User taps **"Anla ve İzin Ver"** → OS location permission prompt appears.
4. If granted → `BackgroundGeolocationDriverService.start(towTruckId)` runs:
   - Persists `tow_truck_id` and Supabase URL/anon key for headless.
   - Configures plugin (once) and starts tracking.
   - Each location update is sent to Supabase (`tow_trucks`).
5. When the app is **terminated**, the **headless task** (registered in `main.dart`) still receives location events and calls `headlessSyncLocationToSupabase(...)` so the client keeps seeing driver position.
6. When the job ends (driver leaves screen), `stop()` is called and headless context is cleared.

## Files

| File | Purpose |
|------|--------|
| `lib/services/background_geolocation_driver_service.dart` | Plugin config, start/stop, onLocation → Supabase (IO only). |
| `lib/services/background_geolocation_driver_service_stub.dart` | No-op implementation for web. |
| `lib/services/background_geolocation_service.dart` | Persist/clear headless context, `headlessSyncLocationToSupabase`, `useBackgroundGeolocation`. |
| `lib/services/background_geolocation_headless_task.dart` | Headless entry point; on `LOCATION` → `headlessSyncLocationToSupabase`. |
| `lib/core/bg_registrar_io.dart` | Registers headless task (IO only). |
| `lib/core/bg_registrar_stub.dart` | No-op for web. |
| `lib/core/is_mobile_io.dart` / `is_mobile_stub.dart` | Platform check for `useBackgroundGeolocation`. |
| `lib/features/driver/widgets/location_permission_rationale_dialog.dart` | Custom dialog + `requestLocationPermissionWithRationale()`. |
| `lib/features/driver/screens/job_navigation_screen.dart` | Starts tracking (with permission flow) and stops on dispose. |
| `lib/main.dart` | Registers headless task when `!kIsWeb`. |

## Android

- **Foreground service**: The plugin shows the configured notification when tracking.
- **Headless**: Requires `enableHeadless: true` and `stopOnTerminate: false`. Declare any required permissions and background/location usage in `AndroidManifest.xml` as per the plugin docs.

## iOS

- No headless mode; tracking runs while the app is in background or suspended as allowed by iOS.
- Request "Always" location with the custom rationale before the system prompt to satisfy App Review.

## Web / Desktop

- `useBackgroundGeolocation` is false; the stub driver service is used and no plugin code runs.
- Headless task is not registered on web.
