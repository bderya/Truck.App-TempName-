# Cekici - Tow Truck On-Demand App

Uber-style tow truck booking app built with Flutter.

## Setup

1. **Install Flutter** (if not already): https://docs.flutter.dev/get-started/install

2. **Generate platform files** (if needed – run once to create Gradle wrapper, iOS project, etc.):
   ```bash
   flutter create . --project-name cekici --org com.cekici
   ```
   Flutter will add any missing platform files without overwriting your `lib/` or `pubspec.yaml`.

3. **Get dependencies:**
   ```bash
   flutter pub get
   ```

4. **Configure Supabase** – Update `lib/main.dart` with your Supabase URL and anon key.

5. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure (Clean Architecture)

```
lib/
├── core/           # Constants, theme, shared utilities
├── features/       # Feature modules (auth, booking, map, etc.)
├── models/         # Shared data models
├── services/       # Supabase, Geolocator, Socket.io
└── main.dart
```

## Driver verification & Admin approval

- **Driver app**: If the driver's user row has `is_verified = false`, they only see a "Verification in Progress" screen and cannot open the job map until an admin approves.
- **Verification fields**: `users` has `is_verified`, `status` (pending/approved/rejected), `license_image_url`, `criminal_record_url`; `tow_trucks` has `plate_image_url`.
- **Admin approval**: Run the migrations in `supabase/migrations/` then use either:
  - **App**: Open "Admin – Approval" from the home screen, enter user ID and status (pending/approved/rejected), then Apply.
  - **Supabase Dashboard SQL**: `SELECT approve_user(123, 'approved');` or `SELECT set_user_verified(123, true);`

## Dependencies

- **supabase_flutter** – Backend & auth
- **flutter_riverpod** – State management
- **latlong2** + **flutter_map** – Cost-effective maps (OpenStreetMap)
- **geolocator** – Location services
- **socket_io_client** – Real-time updates
