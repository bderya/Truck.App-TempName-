# Cekici – Tow Truck On-Demand

Uber-style tow truck booking: **Client app** (request tow, track driver, pay), **Driver app** (receive jobs, navigate, complete with proof of work), and **Admin** (Flutter Web + Next.js dashboard) on a single Supabase backend.

---

## Tech stack

- **Flutter** – Client & Driver mobile apps; Flutter Web for a lightweight admin UI
- **Next.js** (Tailwind) – Admin dashboard (live map, drivers, bookings, reviews, financials)
- **Supabase** – PostgreSQL, Auth (phone OTP), Realtime, Storage, Edge Functions
- **Maps** – flutter_map (OSRM/OpenStreetMap), react-leaflet (admin)
- **Payments** – Stripe/Iyzico (tokenization, pre-auth, capture, split; tips 100% to driver)

---

## Setup

### 1. Flutter

- Install [Flutter](https://docs.flutter.dev/get-started/install).
- Generate platform files if needed:
  ```bash
  flutter create . --project-name cekici --org com.cekici
  ```
- Get dependencies:
  ```bash
  flutter pub get
  ```

### 2. Supabase

- Create a project at [supabase.com](https://supabase.com).
- Run migrations in order (see `supabase/migrations/`).
- In the Flutter app, configure Supabase URL and anon key (e.g. in `lib/core/supabase_service.dart` or env).

### 3. Run

- **Mobile (Client / Driver):** `flutter run` (choose device). On first launch you pick Customer or Driver app.
- **Flutter Web Admin:** `flutter run -d chrome` – opens the in-app admin (dark theme).
- **Next.js Admin Dashboard:** From `admin-dashboard/`: `npm install` then `npm run dev`. Use for live map, driver approval, bookings, **Reviews**, financials, manual job assignment.

---

## Main features

| Area | Description |
|------|-------------|
| **Booking** | Pickup/destination, vehicle type, price estimate, pre-auth payment, real-time driver search and assignment (or manual dispatch by admin). |
| **Tracking** | Live driver position (background location), ETA, smooth marker animation; optional external navigation (Yandex/Google/Apple). |
| **Payments** | Card tokenization, pre-authorize on request; capture + split (platform/driver) on completion; **tips** via Edge Function `process-tip` (100% to driver wallet). |
| **Reviews & tipping** | Post-job summary: star rating, comment, tags; optional tip (presets or custom). Stored in `reviews`; driver `average_rating` updated by trigger. See `docs/CUSTOMER_FEEDBACK_AND_TIPPING.md`. |
| **Driver wallet** | Balance and transaction list; withdrawal requests; credits from completed jobs and tips. |
| **Driver verification** | Onboarding (documents, vehicle, payout); admin approval; `is_verified` gates job access. Quality score and weekly inspection (photos) can affect availability. |
| **Manual dispatch** | Admin assigns a pending job to an online driver; driver sees “operator assigned” and confirms. See `docs/MANUAL_DISPATCH.md`. |
| **i18n** | `easy_localization` with TR/EN; locale persisted. See `docs/I18N.md`. |
| **Legal** | KVKK/EULA/sales agreement in `assets/legal/`; mandatory checkboxes at registration; consent version/date in DB. See `docs/LEGAL_CONSENT.md`. |

---

## Project structure

```
lib/
├── core/                 # Constants, theme, Supabase init, crash reporting
├── features/
│   ├── auth/             # Phone OTP, lazy registration, consent
│   ├── booking/          # Map flow, confirmation, receipt, post-job summary (review + tip)
│   ├── driver/           # Job overlay, wallet, onboarding, settings, shift toggle
│   ├── tracking/         # Driver tracking screen, ETA
│   ├── map/              # Customer map, vehicle selector, bottom sheet
│   └── admin_dashboard/  # Flutter Web admin
├── models/               # User, Booking, TowTruck, ReceiptData, WalletTransaction, etc.
└── services/             # Auth, payment, receipt, review, complete job, location, etc.

admin-dashboard/          # Next.js admin (drivers, bookings, reviews, financials, live map)
supabase/
├── migrations/           # Schema, RLS, triggers, RPCs (reviews, tips, wallet, etc.)
└── functions/            # Edge Functions (e.g. process-tip, manual-assign-job, capture-payment)
docs/                     # Feature docs (I18N, wallet, reviews & tipping, manual dispatch, etc.)
assets/
├── translations/         # tr-TR.json, en-US.json
└── legal/                # kvkk.html, eula.html, sales_agreement.html
```

---

## Documentation

- [Customer feedback & tipping](docs/CUSTOMER_FEEDBACK_AND_TIPPING.md) – Reviews table, post-job screen, tips (100% to driver), admin Reviews tab
- [Manual dispatch](docs/MANUAL_DISPATCH.md) – Admin assign job to driver, `assigned` status, driver confirm
- [Legal consent](docs/LEGAL_CONSENT.md) – KVKK/EULA, registration checkboxes, consent version in DB
- [I18n](docs/I18N.md) – easy_localization, locale detection, settings
- [Driver wallet](docs/DRIVER_WALLET.md) – Balance, transactions, withdrawals
- [Driver cancellation & penalty](docs/DRIVER_CANCELLATION_PENALTY.md) – Late cancel penalty, suspension
- [Real-time tracking](docs/REALTIME_TRACKING_PRODUCTION.md) – Background location, smoothing, battery
- [Error handling & crash reporting](docs/ERROR_HANDLING.md), [CRASH_REPORTING.md](docs/CRASH_REPORTING.md)

---

## Payment integration

- **Stripe/Iyzico**: Tokenize cards only; no raw card data in app. Pre-authorize on “Request tow”; capture + split on job completion (Edge Function / RPC).
- **Tips**: Edge Function `process-tip` charges the client card then calls RPC `credit_driver_tip`; 100% goes to driver wallet. Set `STRIPE_SECRET_KEY` in Supabase for production.
- Run `supabase/migrations/20250110000000_payment_rpc_stubs.sql` and replace RPC bodies with your gateway logic where needed.

---

## Dependencies (Flutter)

- **supabase_flutter** – Backend, auth, realtime, storage  
- **flutter_riverpod** – State management  
- **flutter_map** + **latlong2** – Maps (OSRM tiles)  
- **geolocator** – Location; **flutter_background_geolocation** (mobile) for driver background updates  
- **easy_localization** – i18n  
- **webview_flutter** – Legal documents  
- **pdf** / **printing** – Receipt PDF  
- **sentry_flutter** / **firebase_crashlytics** – Crash reporting  

See `pubspec.yaml` for full list.
