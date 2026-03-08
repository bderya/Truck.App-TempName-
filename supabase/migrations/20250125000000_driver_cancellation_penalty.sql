-- Driver Cancellation & Penalty System: violations table, penalty logic, suspension, client recovery.

-- -----------------------------------------------------------------------------
-- 1. Bookings: cancellation tracking and priority rematch
-- -----------------------------------------------------------------------------
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS cancelled_by TEXT,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS estimated_arrival_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS driver_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_priority_rematch BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE bookings
  ADD CONSTRAINT chk_cancelled_by CHECK (cancelled_by IS NULL OR cancelled_by IN ('client', 'driver'));

COMMENT ON COLUMN bookings.cancelled_by IS 'Who cancelled: client or driver.';
COMMENT ON COLUMN bookings.cancelled_at IS 'When the booking was cancelled.';
COMMENT ON COLUMN bookings.accepted_at IS 'When the driver accepted the booking.';
COMMENT ON COLUMN bookings.estimated_arrival_at IS 'Estimated arrival at pickup (for penalty: 50% through time).';
COMMENT ON COLUMN bookings.driver_started_at IS 'When driver status became on_the_way (start of trip).';
COMMENT ON COLUMN bookings.is_priority_rematch IS 'True when re-opened after driver cancel; high priority for other drivers.';

-- -----------------------------------------------------------------------------
-- 2. Users: active flag and suspension window
-- -----------------------------------------------------------------------------
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMPTZ;

COMMENT ON COLUMN users.is_active IS 'False when driver is suspended (e.g. 3 cancels in 7 days).';
COMMENT ON COLUMN users.suspended_until IS 'When suspension ends (e.g. now() + 48 hours).';

-- -----------------------------------------------------------------------------
-- 3. driver_violations: log each penalty event
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS driver_violations (
  id                    BIGSERIAL PRIMARY KEY,
  driver_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  booking_id             BIGINT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  violation_type         TEXT NOT NULL DEFAULT 'late_cancel',
  penalty_amount         DECIMAL(12, 2) NOT NULL DEFAULT 0,
  quality_score_deduction DECIMAL(3, 2) NOT NULL DEFAULT 0,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_violations_driver_created ON driver_violations(driver_id, created_at DESC);

COMMENT ON TABLE driver_violations IS 'Log of driver cancellation penalties and other violations.';

-- -----------------------------------------------------------------------------
-- 4. Wallet: add cancellation_penalty transaction type
-- -----------------------------------------------------------------------------
DO $$ BEGIN
  ALTER TYPE wallet_transaction_type ADD VALUE 'cancellation_penalty';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Allow negative amount for cancellation_penalty in transactions (alter constraint by dropping and re-adding)
ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS valid_credit_debit;

ALTER TABLE transactions
  ADD CONSTRAINT valid_credit_debit CHECK (
    (type = 'booking_credit' AND amount > 0) OR
    (type IN ('withdrawal', 'withdrawal_fee') AND amount < 0) OR
    (type = 'cancellation_penalty' AND amount < 0) OR
    (type = 'adjustment')
  );

-- -----------------------------------------------------------------------------
-- 5. Set accepted_at when driver accepts (update accept_booking)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION accept_booking(
  p_booking_id BIGINT,
  p_driver_id BIGINT,
  p_estimated_arrival_minutes INT DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated RECORD;
  v_count INT;
  v_eta TIMESTAMPTZ;
BEGIN
  v_eta := NOW() + (COALESCE(p_estimated_arrival_minutes, 15) || ' minutes')::INTERVAL;

  UPDATE bookings
  SET
    status = 'accepted',
    driver_id = p_driver_id,
    accepted_at = NOW(),
    estimated_arrival_at = v_eta,
    updated_at = NOW()
  WHERE id = p_booking_id
    AND status = 'pending'
    AND driver_id IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  IF v_count = 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_taken_or_invalid');
  END IF;

  SELECT * INTO v_updated FROM bookings WHERE id = p_booking_id;
  RETURN jsonb_build_object('ok', true, 'booking', to_jsonb(v_updated));
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. Set driver_started_at when status becomes on_the_way
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_driver_started_at_on_way()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'on_the_way' AND (OLD.status IS NULL OR OLD.status <> 'on_the_way') THEN
    NEW.driver_started_at := COALESCE(NEW.driver_started_at, NOW());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bookings_driver_started_at ON bookings;
CREATE TRIGGER trg_bookings_driver_started_at
  BEFORE UPDATE OF status ON bookings
  FOR EACH ROW
  EXECUTE PROCEDURE set_driver_started_at_on_way();

-- -----------------------------------------------------------------------------
-- 7. cancel_booking_by_driver: penalty, violation, quality, suspension, client recovery
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cancel_booking_by_driver(p_booking_id BIGINT, p_driver_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking     RECORD;
  v_elapsed_sec NUMERIC;
  v_estimated_sec NUMERIC;
  v_ratio       NUMERIC;
  v_apply_penalty BOOLEAN := FALSE;
  v_wallet_id   BIGINT;
  v_balance    DECIMAL(12, 2);
  v_penalty    DECIMAL(12, 2) := 250;
  v_deduction  DECIMAL(3, 2) := 0.30;
  v_count_7    INT;
BEGIN
  SELECT * INTO v_booking
  FROM bookings
  WHERE id = p_booking_id AND driver_id = p_driver_id
  FOR UPDATE;

  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'booking_not_found_or_not_your_job');
  END IF;

  IF v_booking.status NOT IN ('accepted', 'on_the_way', 'picked_up') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_status');
  END IF;

  -- Compute progress: elapsed time vs estimated time (50% threshold)
  v_estimated_sec := EXTRACT(EPOCH FROM (
    COALESCE(v_booking.estimated_arrival_at, v_booking.accepted_at + INTERVAL '15 minutes') - v_booking.accepted_at
  ));
  IF v_estimated_sec IS NULL OR v_estimated_sec <= 0 THEN
    v_estimated_sec := 900; -- 15 min default
  END IF;

  v_elapsed_sec := EXTRACT(EPOCH FROM (
    NOW() - COALESCE(v_booking.driver_started_at, v_booking.accepted_at)
  ));
  v_ratio := v_elapsed_sec / NULLIF(v_estimated_sec, 0);
  v_apply_penalty := (v_ratio >= 0.5);

  -- Apply penalty if >50% through
  IF v_apply_penalty THEN
    v_wallet_id := ensure_wallet(p_driver_id);
    IF v_wallet_id IS NOT NULL THEN
      SELECT available_balance INTO v_balance FROM wallets WHERE id = v_wallet_id FOR UPDATE;
      v_balance := COALESCE(v_balance, 0);
      IF v_balance >= v_penalty THEN
        UPDATE wallets
        SET available_balance = available_balance - v_penalty, updated_at = NOW()
        WHERE id = v_wallet_id;
        INSERT INTO transactions (wallet_id, amount, type, status, reference_id, description)
        VALUES (v_wallet_id, -v_penalty, 'cancellation_penalty', 'completed', p_booking_id,
                'Late cancellation penalty #' || p_booking_id);
      END IF;
    END IF;

    INSERT INTO driver_violations (driver_id, booking_id, violation_type, penalty_amount, quality_score_deduction)
    VALUES (p_driver_id, p_booking_id, 'late_cancel', v_penalty, v_deduction);

    UPDATE tow_trucks
    SET quality_score = GREATEST(0, COALESCE(quality_score, 5) - v_deduction), updated_at = NOW()
    WHERE driver_id = p_driver_id;
  END IF;

  -- Rolling 7-day cancellation count -> suspend if >= 3
  SELECT COUNT(*) INTO v_count_7
  FROM driver_violations
  WHERE driver_id = p_driver_id
    AND violation_type = 'late_cancel'
    AND created_at >= NOW() - INTERVAL '7 days';

  IF v_count_7 >= 3 THEN
    UPDATE users
    SET is_active = FALSE, suspended_until = NOW() + INTERVAL '48 hours', updated_at = NOW()
    WHERE id = p_driver_id;
  END IF;

  -- Client recovery: re-open booking as pending with top priority, clear driver
  UPDATE bookings
  SET
    status = 'pending',
    driver_id = NULL,
    cancelled_by = 'driver',
    cancelled_at = NOW(),
    is_priority_rematch = TRUE,
    accepted_at = NULL,
    estimated_arrival_at = NULL,
    driver_started_at = NULL,
    updated_at = NOW()
  WHERE id = p_booking_id;

  -- Free the driver's truck
  UPDATE tow_trucks SET is_available = TRUE, updated_at = NOW() WHERE driver_id = p_driver_id;

  RETURN jsonb_build_object(
    'ok', true,
    'penalty_applied', v_apply_penalty,
    'penalty_amount', CASE WHEN v_apply_penalty THEN v_penalty ELSE 0 END,
    'suspended', v_count_7 >= 3,
    'booking_status', 'pending',
    'is_priority_rematch', TRUE
  );
END;
$$;

COMMENT ON FUNCTION cancel_booking_by_driver(BIGINT, BIGINT) IS
  'Driver cancels an accepted job. If >50% through ETA: 250 TL penalty, violation log, -0.3 quality. 3 cancels in 7 days = 48h suspension. Booking re-opens as priority rematch.';

-- -----------------------------------------------------------------------------
-- 8. Lift suspension when suspended_until has passed (call from cron or app)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION lift_expired_suspensions()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE users
  SET is_active = TRUE, suspended_until = NULL, updated_at = NOW()
  WHERE user_type = 'driver' AND is_active = FALSE AND suspended_until IS NOT NULL AND suspended_until <= NOW();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION lift_expired_suspensions() IS 'Set is_active=TRUE for drivers whose suspended_until has passed. Run periodically (e.g. cron).';

-- -----------------------------------------------------------------------------
-- 9. get_nearest_available_tow_trucks: exclude suspended drivers (is_active = FALSE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_nearest_available_tow_trucks(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 10,
  p_limit INT DEFAULT 5
)
RETURNS SETOF tow_trucks
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT t.*
  FROM tow_trucks t
  JOIN users u ON u.id = t.driver_id
  WHERE t.is_available = TRUE
    AND t.is_inspected = TRUE
    AND (u.is_under_review = FALSE OR u.is_under_review IS NULL)
    AND (u.is_active = TRUE)
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(t.current_longitude, t.current_latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000
    )
  ORDER BY ST_Distance(
    ST_SetSRID(ST_MakePoint(t.current_longitude, t.current_latitude), 4326)::geography,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  )
  LIMIT p_limit;
$$;
