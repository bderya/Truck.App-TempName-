# Driver Online/Offline Shift Toggle

## Overview

- **Database**: Toggle updates `tow_trucks.is_available` (true = online, false = offline).
- **Location**: When online, the driver’s position is streamed to Supabase. When going offline, the stream stops and one final “last seen” coordinate is sent.
- **UI**: High-contrast “Slide to Online/Offline” widget; when online, a pulsating green dot indicates live connection.
- **FCM**: Driver subscribes to topic `driver_job_alerts` when online and unsubscribes when offline so they don’t get job alerts while offline.
- **Validation**: If the driver has an active job (status `accepted`, `on_the_way`, or `picked_up`), switching to offline is blocked with: “Lütfen önce mevcut işi tamamlayın.”

## Flow

1. **Going online**: `DriverOnlineService.setOnline(..., online: true)` updates `tow_trucks.is_available = true`, starts the location stream (e.g. `LocationService.startLocationStreamToSupabase`), and subscribes to FCM topic `driver_job_alerts`.
2. **Going offline**: If `hasActiveJob(driverId)` is true, show dialog and do nothing. Otherwise call `setOnline(..., online: false)`, which stops the stream, sends one last position to `tow_trucks`, sets `is_available = false`, and unsubscribes from the topic.
3. **Job requests**: `DriverBookingNotifier` uses `isAvailable` (from `tow_trucks.is_available`). When false, new pending bookings are ignored so offline drivers don’t see job alerts.

## Files

| File | Role |
|------|------|
| `lib/services/driver_online_service.dart` | `setOnline`, `sendLastSeenThenSetOffline`, FCM topic subscribe/unsubscribe, `hasActiveJob` |
| `lib/features/driver/widgets/online_offline_toggle.dart` | `OnlineOfflineToggle` (labels Çevrimiçi/Çevrimdışı), `_PulsatingGreenDot` |
| `lib/features/driver/driver_map_screen.dart` | Toggle on map screen, `_onOnlineOfflineChanged` (validation + setOnline), availability stream start/stop |
| `lib/features/driver/providers/driver_booking_provider.dart` | `isAvailable` on notifier; no job UI when offline |

## Backend / FCM

- Job alerts should be sent only to drivers who are online (e.g. `tow_trucks.is_available = true`) or to the FCM topic `driver_job_alerts` (clients subscribe only when online).
