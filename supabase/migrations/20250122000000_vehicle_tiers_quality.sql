-- Vehicle tiers, quality scoring, inspection, and vehicle value tier for matching.

-- -----------------------------------------------------------------------------
-- tow_trucks: tier, quality score, inspection (weekly audit)
-- -----------------------------------------------------------------------------
ALTER TABLE tow_trucks
  ADD COLUMN IF NOT EXISTS vehicle_model_year SMALLINT,
  ADD COLUMN IF NOT EXISTS tier_category TEXT,
  ADD COLUMN IF NOT EXISTS quality_score DECIMAL(3, 2),
  ADD COLUMN IF NOT EXISTS is_inspected BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS last_inspection_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS inspection_photo_urls JSONB;

ALTER TABLE tow_trucks
  ADD CONSTRAINT chk_tier_category
  CHECK (tier_category IS NULL OR tier_category IN ('Gold', 'Silver', 'Bronze'));

ALTER TABLE tow_trucks
  ADD CONSTRAINT chk_quality_score
  CHECK (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 5));

COMMENT ON COLUMN tow_trucks.vehicle_model_year IS 'Year of the tow truck model.';
COMMENT ON COLUMN tow_trucks.tier_category IS 'Gold, Silver, Bronze. High-value jobs go to Gold only.';
COMMENT ON COLUMN tow_trucks.quality_score IS 'Aggregate quality/rating score 0-5.';
COMMENT ON COLUMN tow_trucks.is_inspected IS 'Weekly audit: must be true to receive jobs. Reset every Monday until 3 photos uploaded.';
COMMENT ON COLUMN tow_trucks.last_inspection_at IS 'When driver last submitted inspection photos.';
COMMENT ON COLUMN tow_trucks.inspection_photo_urls IS 'Array of 3 photo URLs from last weekly inspection.';

-- -----------------------------------------------------------------------------
-- users: average rating and review status (quality penalty)
-- -----------------------------------------------------------------------------
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS average_rating DECIMAL(3, 2),
  ADD COLUMN IF NOT EXISTS is_under_review BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE users
  ADD CONSTRAINT chk_average_rating
  CHECK (average_rating IS NULL OR (average_rating >= 0 AND average_rating <= 5));

COMMENT ON COLUMN users.average_rating IS 'Driver: average of client ratings. Below 3.5 triggers review status.';
COMMENT ON COLUMN users.is_under_review IS 'Driver: true when average_rating < 3.5; hidden from map and job dispatch.';

-- -----------------------------------------------------------------------------
-- bookings: client vehicle value tier (for Gold-only matching)
-- -----------------------------------------------------------------------------
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS vehicle_value_tier TEXT;

ALTER TABLE bookings
  ADD CONSTRAINT chk_vehicle_value_tier
  CHECK (vehicle_value_tier IS NULL OR vehicle_value_tier IN ('low', 'medium', 'high'));

COMMENT ON COLUMN bookings.vehicle_value_tier IS 'Estimated value tier of client vehicle. high = only Gold drivers get notified.';

-- -----------------------------------------------------------------------------
-- driver_ratings: per-booking rating for drivers (updates users.average_rating)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS driver_ratings (
  id         BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  driver_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score      SMALLINT NOT NULL CHECK (score >= 1 AND score <= 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(booking_id)
);

CREATE INDEX IF NOT EXISTS idx_driver_ratings_driver_id ON driver_ratings(driver_id);

ALTER TABLE driver_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY driver_ratings_all ON driver_ratings FOR ALL USING (true) WITH CHECK (true);

-- Recompute driver's average_rating and set is_under_review when < 3.5 (handles INSERT/UPDATE/DELETE)
CREATE OR REPLACE FUNCTION update_driver_rating_on_new_rating()
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

  SELECT ROUND(AVG(score)::numeric, 2) INTO v_avg
  FROM driver_ratings
  WHERE driver_id = v_driver_id;

  UPDATE users
  SET
    average_rating = v_avg,
    is_under_review = (v_avg IS NOT NULL AND v_avg < 3.5),
    updated_at = NOW()
  WHERE id = v_driver_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_driver_rating_update ON driver_ratings;
CREATE TRIGGER trg_driver_rating_update
  AFTER INSERT OR UPDATE OR DELETE ON driver_ratings
  FOR EACH ROW
  EXECUTE FUNCTION update_driver_rating_on_new_rating();
