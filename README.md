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

## Dependencies

- **supabase_flutter** – Backend & auth
- **flutter_riverpod** – State management
- **latlong2** + **flutter_map** – Cost-effective maps (OpenStreetMap)
- **geolocator** – Location services
- **socket_io_client** – Real-time updates
