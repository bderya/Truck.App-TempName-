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

## Flutter Web Admin Dashboard

On **web** (e.g. `flutter run -d chrome`), the app starts directly in the **Admin Dashboard** (dark theme, blue & gold).

- **Dashboard**: Earnings cards (Total Revenue, Platform Commission, Active Jobs) and a **Live Map** of active drivers (flutter_map, `is_available = true`).
- **Drivers**: Table of all drivers; **Review Documents** (license/criminal record URLs) and a **toggle** to approve/reject (updates `is_verified` via RPC).
- **Bookings**: Table of all bookings.
- **Settings**: Placeholder.

Ensure web is enabled: `flutter create . --platforms web` if needed.

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

## Payment service

The app includes a **Payment Service** (Stripe/marketplace-style) with tokenization only (no raw card data stored):

- **addCard(gatewayTokenOrPaymentMethodId)** – Store a token from your gateway (e.g. Stripe Elements); returns a [CardToken].
- **processPayment(...)** – Charge a card token for a booking.
- **distributeFunds(...)** – Split payment when a booking is completed: X% platform, Y% driver (uses `AppConstants.platformCommissionRate`).

**Security:** Only token IDs are sent to your backend; implement the actual charge in Supabase Edge Functions or your API using Stripe Connect / Iyzico.

**Failure handling:** Use `handlePaymentResult()` or `processBookingPaymentAndNotify()` from `payment_notification_helper.dart` to show a snackbar on failure (e.g. insufficient funds, card declined).

Database stubs: run the migration in `supabase/migrations/20250110000000_payment_rpc_stubs.sql`, then replace the RPC bodies with your gateway logic.

## Dependencies

- **supabase_flutter** – Backend & auth
- **flutter_riverpod** – State management
- **latlong2** + **flutter_map** – Cost-effective maps (OpenStreetMap)
- **geolocator** – Location services
- **socket_io_client** – Real-time updates
