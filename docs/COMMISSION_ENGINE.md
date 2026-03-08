# Dynamic Commission Calculation Engine

Driver payouts use a **tiered commission** and an optional **surge adjustment**. The split is computed by `calculate_net_earnings` and used during the capture/split payment phase.

## Logic

- **Tiers** (from driver’s `quality_score` on `tow_trucks` and vehicle age = current year − `vehicle_model_year`):
  - **Score > 4.8 and vehicle age < 5** → platform commission **15%**
  - **Score > 4.2** → platform commission **20%**
  - **Else** → platform commission **25%**

- **Surge adjustment**: If the booking has `is_surge_pricing = true`, platform commission is **reduced by 5%** (driver gets 5% more).

## Database

- **Bookings**: `is_surge_pricing` (boolean), `driver_net_amount`, `platform_commission_percent` (set at completion).
- **RPC**: `calculate_net_earnings(p_total_price, p_driver_id, p_booking_id)`  
  Returns: `net_amount`, `platform_amount`, `commission_percent`, `platform_percent`, `driver_percent`, `is_surge`.

## Capture / split payment

1. **App (CompleteJobService)**  
   On job completion it:
   - Calls `calculate_net_earnings(price, driver_id, booking_id)`.
   - Calls `distributeFunds(..., platformPercent, driverPercent)` with the returned percents.
   - Updates the booking with `driver_net_amount` and `platform_commission_percent`.

2. **Edge Function**  
   `capture-payment-on-complete` calls `payment_capture_on_booking_complete(booking_id)`, which:
   - Calls `calculate_net_earnings` and returns the same split in the RPC response.
   - You can use `driver_net_amount` and `platform_amount` (or the percents) in your Stripe/Iyzico split API call.

## Driver earnings display

- **Driver wallet / earnings** use `booking.driver_net_amount` when present (actual net paid).
- Otherwise they fall back to `price * (1 - default_commission)`.

## Enabling surge pricing

- Set `is_surge_pricing = true` on a booking when creating it (e.g. when demand is high).
- The commission engine will then apply the 5% reduction for that booking.
