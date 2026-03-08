# Customer Feedback & Tipping System

## Overview

- **Reviews**: One review per completed booking (rating 1–5, optional comment, tags JSONB). Driver `average_rating` is recalculated on each review.
- **Tipping**: Optional tip after job; charged via Stripe; 100% credited to driver wallet (0% platform commission).
- **Admin**: Reviews tab with optional “Low ratings (≤2)” filter for disputes.

---

## Database

### `reviews` table

- `id`, `booking_id` (FK, UNIQUE), `driver_id`, `client_id`, `rating` (1–5), `comment` (TEXT), `tags` (JSONB, default `[]`), `created_at`.
- Trigger `trg_reviews_update_driver_rating`: on INSERT/UPDATE/DELETE, recomputes `users.average_rating` (and `is_under_review` when &lt; 3.5) from `reviews.rating`; falls back to `driver_ratings` if no reviews.

### `bookings`

- `tip_amount` (DECIMAL, nullable): total tip paid for this booking.

### Wallets

- `wallet_transaction_type`: added value `'tip'`.
- `transactions`: rows with `type = 'tip'` and `amount > 0` for tip credits.

### RPCs

- **`credit_driver_tip(p_booking_id, p_driver_id, p_amount, p_payment_ref)`**  
  Validates booking (completed, driver match), ensures wallet, credits driver, appends to `bookings.tip_amount`, returns `{ ok, amount }`.

---

## Client app (Flutter)

### Post-job summary screen

- Shown after booking status becomes `completed` (replaces the previous simple review dialog).
- **Rating**: 1–5 stars (required for submit; default 3 if user skips rating).
- **Comment**: optional text.
- **Tags**: optional chips (keys: `tag_on_time`, `tag_professional`, `tag_clean_truck`, `tag_friendly`, `tag_issue`); stored in `reviews.tags` as array of keys.
- **Tip**: optional presets (e.g. 20, 50, 100 TL) or “Other” custom amount.
- Submit: inserts into `reviews` (via `submitReview()`), then if tip &gt; 0 calls Edge Function `process-tip` with default card token, then navigates to Job Summary / Receipt.

### Tip flow

1. User selects tip amount (or custom).
2. On “Submit and view receipt”, after saving the review, if tip &gt; 0:
   - Require default card (else show “tip_need_card” message).
   - Call Edge Function **`process-tip`** with `bookingId`, `driverId`, `amount`, `cardTokenId`, `currency`.
3. Edge Function charges the card (Stripe) then calls `credit_driver_tip`; 100% of tip goes to driver wallet.

---

## Edge Function: `process-tip`

- **Method**: POST.
- **Body**: `bookingId`, `driverId`, `amount`, `cardTokenId`, optional `currency` (default `try`).
- **Logic**:
  1. If `STRIPE_SECRET_KEY` is missing, return 503 “Payment not configured”.
  2. Create and confirm Stripe PaymentIntent for the tip amount.
  3. On success, call Supabase RPC `credit_driver_tip(booking_id, driver_id, amount, payment_ref)`.
- **Response**: `{ ok: true, amount }` or `{ ok: false, error }`.

---

## Driver impact

- **Average rating**: Trigger `update_driver_rating_on_review` runs on every review change; recomputes `users.average_rating` (and `is_under_review` when &lt; 3.5). Existing `driver_ratings` still used if driver has no rows in `reviews`.
- **Wallet**: Tip appears as a `tip` transaction and increases `available_balance` and `total_earned`.

---

## Admin panel (Next.js)

- **Reviews** tab (sidebar: “Değerlendirmeler”).
- **ReviewsTable**: Lists all reviews (ID, booking ID, rating, driver name, client name, comment, tags, date).
- **Filter**: “Düşük puanlar (≤2)” to show only low ratings for quick dispute handling.

---

## Translation keys (i18n)

- `rate_experience_title`, `rate_experience_thanks`, `rate_experience_with_driver`, `rate_stars_label`, `comment_optional`, `comment_hint`, `tags_label`, `send_tip_label`, `tip_disclaimer`, `tip_amount_label`, `tip_custom`, `submit_and_receipt`, `skip`, `tip_sent`, `tip_failed`, `tip_need_card`, `tag_on_time`, `tag_professional`, `tag_clean_truck`, `tag_friendly`, `tag_issue`.
