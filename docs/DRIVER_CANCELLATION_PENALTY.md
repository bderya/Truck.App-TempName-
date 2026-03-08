# Driver Cancellation & Penalty System

## Overview

When a driver cancels an accepted booking, the system applies time-based penalty logic, logs violations, can suspend the driver, and re-opens the booking for the client as a priority rematch.

## Trigger

- **When**: Driver taps "İşi iptal et" on the job navigation screen (after accepting, before/during pickup or delivery).
- **RPC**: `cancel_booking_by_driver(p_booking_id, p_driver_id)`.

## Penalty logic (>50% through ETA)

- **Elapsed time**: From `driver_started_at` (when status became `on_the_way`) or `accepted_at` if not yet on the way.
- **Estimated duration**: From `estimated_arrival_at - accepted_at` (set when driver accepts; default 15 minutes if not provided).
- **Condition**: If `elapsed / estimated_duration >= 0.5`, then:
  - **250 TL** is deducted from the driver’s wallet (transaction type `cancellation_penalty`).
  - A row is inserted into **driver_violations** (type `late_cancel`, penalty_amount 250, quality_score_deduction 0.30).
  - The driver’s **quality_score** (on `tow_trucks`) is reduced by **0.30** (floor 0).

## Automated suspension (3 cancels in 7 days)

- Count of `driver_violations` with `violation_type = 'late_cancel'` and `created_at >= NOW() - 7 days` for that driver.
- If count **≥ 3** at the time of this cancel:
  - **users**: `is_active = FALSE`, `suspended_until = NOW() + 48 hours`.
- **Lifting**: Call `lift_expired_suspensions()` periodically (e.g. cron every hour). It sets `is_active = TRUE` and `suspended_until = NULL` for drivers where `suspended_until <= NOW()`.
- Suspended drivers:
  - Do not appear in `get_nearest_available_tow_trucks`.
  - Do not receive new job requests (driver app uses `is_active`).
  - See the “Hesabınız askıya alındı” screen until `suspended_until` has passed.

## Client recovery

- Booking is **not** set to `cancelled`. It is re-opened:
  - `status = 'pending'`, `driver_id = NULL`, `is_priority_rematch = TRUE`, `cancelled_by = 'driver'`, `cancelled_at = NOW()`.
- Driver’s truck is set **is_available = TRUE**.
- **Client app**: Realtime sees `status = 'pending'` and `is_priority_rematch = true`; client is returned to the map with “Sürücü iptal etti. Yeniden eşleştiriliyorsunuz. Ek ücret alınmaz.” and the same booking is watched again for a new driver. No extra charge.
- **Driver app**: Pending bookings with `is_priority_rematch = true` are shown with **red border** and **“Öncelikli”** badge so other drivers see them as high priority.

## Database

- **bookings**: `cancelled_by`, `cancelled_at`, `accepted_at`, `estimated_arrival_at`, `driver_started_at`, `is_priority_rematch`.
- **users**: `is_active`, `suspended_until`.
- **driver_violations**: `driver_id`, `booking_id`, `violation_type`, `penalty_amount`, `quality_score_deduction`, `created_at`.
- **transactions**: type `cancellation_penalty` (negative amount).
- **accept_booking**: Now sets `accepted_at`, `estimated_arrival_at` (optional third arg `p_estimated_arrival_minutes`, default 15).
- **Trigger**: On `bookings` status update to `on_the_way`, set `driver_started_at = NOW()` if null.

## Cron

- Schedule **lift_expired_suspensions()** (e.g. hourly) to clear expired suspensions.
