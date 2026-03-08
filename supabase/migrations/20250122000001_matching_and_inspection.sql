-- Matching: exclude drivers under review and not inspected; weekly audit reset; inspection submit.

-- -----------------------------------------------------------------------------
-- get_nearest_available_tow_trucks: hide drivers in review or not inspected
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
AS $$
  SELECT t.*
  FROM tow_trucks t
  JOIN users u ON u.id = t.driver_id
  WHERE t.is_available = TRUE
    AND t.is_inspected = TRUE
    AND (u.is_under_review = FALSE OR u.is_under_review IS NULL)
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

COMMENT ON FUNCTION get_nearest_available_tow_trucks IS 'Returns tow trucks that are available, inspected, and driver not under review (rating >= 3.5).';

-- -----------------------------------------------------------------------------
-- Weekly audit: reset is_inspected every Monday (run via pg_cron or Supabase cron)
-- Call this from a scheduled job (e.g. Monday 00:01) to require drivers to re-upload 3 photos.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION weekly_reset_inspection()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE tow_trucks
  SET is_inspected = FALSE, updated_at = NOW()
  WHERE is_inspected = TRUE;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION weekly_reset_inspection IS 'Call every Monday to require all drivers to re-submit 3 inspection photos. Sets is_inspected = FALSE for all.';

-- -----------------------------------------------------------------------------
-- Driver submits 3 inspection photos; sets is_inspected = TRUE and last_inspection_at
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION submit_inspection_photos(
  p_tow_truck_id BIGINT,
  p_photo_urls TEXT[]  -- exactly 3 URLs
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF array_length(p_photo_urls, 1) IS DISTINCT FROM 3 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Exactly 3 photos required');
  END IF;

  UPDATE tow_trucks
  SET
    is_inspected = TRUE,
    last_inspection_at = NOW(),
    inspection_photo_urls = to_jsonb(p_photo_urls),
    updated_at = NOW()
  WHERE id = p_tow_truck_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tow truck not found');
  END IF;

  RETURN jsonb_build_object('ok', true, 'last_inspection_at', NOW());
END;
$$;

COMMENT ON FUNCTION submit_inspection_photos IS 'Driver uploads 3 photos; app calls with URLs. Enables job-taking until next Monday reset.';

-- -----------------------------------------------------------------------------
-- Estimated vehicle value tier for matching (high value → Gold drivers only)
-- Client can call with make/model/year or pass tier from app logic.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION estimate_vehicle_value_tier(
  p_make TEXT DEFAULT NULL,
  p_model TEXT DEFAULT NULL,
  p_year SMALLINT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_tier TEXT := 'medium';
  v_year INT;
BEGIN
  v_year := COALESCE(p_year, 2015);

  -- Simple rules: recent year + luxury brands → high; old or economy → low
  IF p_make IS NOT NULL AND lower(p_make) IN ('mercedes-benz', 'bmw', 'audi', 'porsche', 'lexus', 'tesla', 'range rover') THEN
    IF v_year >= 2018 THEN v_tier := 'high'; ELSE v_tier := 'medium'; END IF;
  ELSIF v_year >= 2020 THEN
    v_tier := 'high';
  ELSIF v_year <= 2010 THEN
    v_tier := 'low';
  END IF;

  RETURN v_tier;
END;
$$;

COMMENT ON FUNCTION estimate_vehicle_value_tier IS 'Returns low/medium/high for client car. Use result in booking.vehicle_value_tier; high restricts to Gold drivers.';
