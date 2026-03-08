-- Dynamic commission calculation engine and surge pricing flag for split payment.

-- Bookings: surge pricing flag (reduces platform commission by 5% to incentivize driver).
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS is_surge_pricing BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN bookings.is_surge_pricing IS 'When true, platform commission is reduced by 5% for this booking.';

-- Optional: store actual applied split at completion for earnings display.
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS driver_net_amount DECIMAL(10, 2),
  ADD COLUMN IF NOT EXISTS platform_commission_percent DECIMAL(5, 2);

COMMENT ON COLUMN bookings.driver_net_amount IS 'Net amount sent to driver for this booking (set at completion).';
COMMENT ON COLUMN bookings.platform_commission_percent IS 'Platform commission % applied (set at completion).';

-- -----------------------------------------------------------------------------
-- calculate_net_earnings(total_price, driver_id, booking_id)
-- Fetches driver's quality_score and vehicle age; applies tiered commission and surge.
-- Returns: net_amount (driver), platform_amount, commission_percent, platform_percent, driver_percent.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_net_earnings(
  p_total_price DECIMAL,
  p_driver_id BIGINT,
  p_booking_id BIGINT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_score          DECIMAL(3, 2);
  v_model_year     SMALLINT;
  v_vehicle_age    INT;
  v_commission_pct DECIMAL(5, 2);  -- platform commission (e.g. 15, 20, 25)
  v_surge          BOOLEAN := FALSE;
  v_platform_amt   DECIMAL(10, 2);
  v_driver_amt     DECIMAL(10, 2);
  v_platform_pct   DECIMAL(5, 4);
  v_driver_pct     DECIMAL(5, 4);
BEGIN
  IF p_total_price IS NULL OR p_total_price <= 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Invalid total_price',
      'net_amount', 0,
      'platform_amount', 0,
      'commission_percent', 25
    );
  END IF;

  -- Driver's quality_score and vehicle_model_year from tow_trucks
  SELECT t.quality_score, t.vehicle_model_year
  INTO v_score, v_model_year
  FROM tow_trucks t
  WHERE t.driver_id = p_driver_id
  LIMIT 1;

  -- Vehicle age: current year - model year; if null treat as old (5+)
  v_vehicle_age := COALESCE(
    EXTRACT(YEAR FROM CURRENT_DATE)::INT - NULLIF(v_model_year, 0),
    99
  );

  -- Tiered commission (platform takes this %)
  IF (v_score IS NOT NULL AND v_score > 4.8) AND v_vehicle_age < 5 THEN
    v_commission_pct := 15;
  ELSIF v_score IS NOT NULL AND v_score > 4.2 THEN
    v_commission_pct := 20;
  ELSE
    v_commission_pct := 25;
  END IF;

  -- Surge adjustment: reduce platform commission by 5%
  IF p_booking_id IS NOT NULL THEN
    SELECT COALESCE(b.is_surge_pricing, FALSE) INTO v_surge
    FROM bookings b WHERE b.id = p_booking_id;
  END IF;
  IF v_surge THEN
    v_commission_pct := GREATEST(0, v_commission_pct - 5);
  END IF;

  v_commission_pct := v_commission_pct / 100.0;
  v_platform_amt   := ROUND((p_total_price * v_commission_pct)::numeric, 2);
  v_driver_amt     := ROUND((p_total_price * (1 - v_commission_pct))::numeric, 2);
  v_platform_pct   := v_commission_pct;
  v_driver_pct     := 1 - v_commission_pct;

  RETURN jsonb_build_object(
    'ok', true,
    'net_amount', v_driver_amt,
    'platform_amount', v_platform_amt,
    'commission_percent', ROUND((v_commission_pct * 100)::numeric, 2),
    'platform_percent', v_platform_pct,
    'driver_percent', v_driver_pct,
    'is_surge', v_surge
  );
END;
$$;

COMMENT ON FUNCTION calculate_net_earnings(DECIMAL, BIGINT, BIGINT) IS
  'Dynamic commission: tier by quality_score and vehicle_age; surge reduces commission by 5%. Returns split for capture/split API.';

-- -----------------------------------------------------------------------------
-- payment_capture_on_booking_complete: use calculate_net_earnings for split
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION payment_capture_on_booking_complete(p_booking_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
  v_split   JSONB;
  v_client_token TEXT;
  v_driver_account_id TEXT;
BEGIN
  SELECT id, payment_id, price, client_id, driver_id
  INTO v_booking
  FROM bookings
  WHERE id = p_booking_id AND status = 'completed';

  IF NOT FOUND OR v_booking.payment_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Booking not found or no payment_id');
  END IF;

  -- Dynamic commission split
  v_split := calculate_net_earnings(
    v_booking.price,
    v_booking.driver_id,
    p_booking_id
  );

  IF (v_split->>'ok')::boolean IS NOT TRUE THEN
    RETURN v_split;
  END IF;

  SELECT default_card_token_id INTO v_client_token
  FROM users WHERE id = v_booking.client_id;

  v_driver_account_id := 'acct_placeholder';

  -- Return split so caller (Edge Function / app) can pass to Stripe/Iyzico split API
  RETURN jsonb_build_object(
    'ok', true,
    'booking_id', p_booking_id,
    'payment_id', v_booking.payment_id,
    'total_amount', v_booking.price,
    'driver_net_amount', v_split->'net_amount',
    'platform_amount', v_split->'platform_amount',
    'commission_percent', v_split->'commission_percent',
    'platform_percent', (v_split->>'platform_percent')::double precision,
    'driver_percent', (v_split->>'driver_percent')::double precision,
    'message', 'Use driver_net_amount and platform_amount for split API capture.'
  );
END;
$$;
