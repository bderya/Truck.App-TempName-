-- Customer Feedback & Tipping: reviews table, tip_amount on bookings, tip transaction type, trigger to recalc driver average_rating.

-- -----------------------------------------------------------------------------
-- reviews: full feedback (rating, comment, tags) linked to booking/driver/client
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reviews (
  id          BIGSERIAL PRIMARY KEY,
  booking_id  BIGINT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  driver_id   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating      SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment     TEXT,
  tags        JSONB DEFAULT '[]',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(booking_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_driver_id ON reviews(driver_id);
CREATE INDEX IF NOT EXISTS idx_reviews_client_id ON reviews(client_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at DESC);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY reviews_all ON reviews FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE reviews IS 'Customer feedback after completed job: rating, comment, tags. Drives driver average_rating.';

-- Recalculate driver average_rating from reviews (and optionally from legacy driver_ratings for backward compat)
CREATE OR REPLACE FUNCTION update_driver_rating_on_review()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id BIGINT;
  v_avg       DECIMAL(3, 2);
BEGIN
  v_driver_id := COALESCE(NEW.driver_id, OLD.driver_id);
  IF v_driver_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  -- Average from reviews; if no reviews, use driver_ratings for backward compat
  SELECT ROUND(AVG(rating)::numeric, 2) INTO v_avg
  FROM reviews
  WHERE driver_id = v_driver_id;

  IF v_avg IS NULL THEN
    SELECT ROUND(AVG(score)::numeric, 2) INTO v_avg
    FROM driver_ratings
    WHERE driver_id = v_driver_id;
  END IF;

  UPDATE users
  SET
    average_rating = v_avg,
    is_under_review = (v_avg IS NOT NULL AND v_avg < 3.5),
    updated_at = NOW()
  WHERE id = v_driver_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_update_driver_rating ON reviews;
CREATE TRIGGER trg_reviews_update_driver_rating
  AFTER INSERT OR UPDATE OR DELETE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_driver_rating_on_review();

-- -----------------------------------------------------------------------------
-- bookings: optional tip amount (stored after successful tip payment)
-- -----------------------------------------------------------------------------
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS tip_amount DECIMAL(10, 2);

COMMENT ON COLUMN bookings.tip_amount IS 'Optional tip paid by client; 100% goes to driver wallet.';

-- -----------------------------------------------------------------------------
-- wallet_transaction_type: add 'tip'
-- -----------------------------------------------------------------------------
DO $$ BEGIN
  ALTER TYPE wallet_transaction_type ADD VALUE 'tip';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Allow tip credits (amount > 0, type = 'tip')
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS valid_credit_debit;
ALTER TABLE transactions ADD CONSTRAINT valid_credit_debit CHECK (
  (type = 'booking_credit' AND amount > 0) OR
  (type = 'tip' AND amount > 0) OR
  (type IN ('withdrawal', 'withdrawal_fee') AND amount < 0) OR
  (type = 'adjustment')
);

-- RPC: Credit driver wallet with tip (called after gateway charges the client; 100% to driver)
CREATE OR REPLACE FUNCTION credit_driver_tip(
  p_booking_id BIGINT,
  p_driver_id  BIGINT,
  p_amount     DECIMAL(10, 2),
  p_payment_ref TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id BIGINT;
  v_booking   RECORD;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid amount');
  END IF;

  SELECT id, driver_id, status INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Booking not found');
  END IF;
  IF v_booking.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Driver mismatch');
  END IF;
  IF v_booking.status <> 'completed' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Booking not completed');
  END IF;

  v_wallet_id := ensure_wallet(p_driver_id);
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Wallet not found');
  END IF;

  UPDATE wallets
  SET
    available_balance = available_balance + p_amount,
    total_earned = total_earned + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet_id;

  INSERT INTO transactions (wallet_id, amount, type, status, reference_id, description)
  VALUES (
    v_wallet_id,
    p_amount,
    'tip',
    'completed',
    p_booking_id,
    COALESCE(p_payment_ref, 'Tip for job #' || p_booking_id)
  );

  UPDATE bookings SET tip_amount = COALESCE(tip_amount, 0) + p_amount, updated_at = NOW() WHERE id = p_booking_id;

  RETURN jsonb_build_object('ok', true, 'amount', p_amount);
END;
$$;

COMMENT ON FUNCTION credit_driver_tip IS 'Credits driver wallet with tip amount (100%). Call after payment gateway charges the client.';
