-- Atomic accept: only the first driver who calls this gets the job.
-- Prevents race when multiple drivers click Accept on the same pending booking.
CREATE OR REPLACE FUNCTION accept_booking(p_booking_id BIGINT, p_driver_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated RECORD;
  v_count INT;
BEGIN
  UPDATE bookings
  SET
    status = 'accepted',
    driver_id = p_driver_id,
    updated_at = now()
  WHERE id = p_booking_id
    AND status = 'pending'
    AND driver_id IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  IF v_count = 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'reason', 'already_taken_or_invalid'
    );
  END IF;

  SELECT * INTO v_updated
  FROM bookings
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'ok', true,
    'booking', to_jsonb(v_updated)
  );
END;
$$;

COMMENT ON FUNCTION accept_booking(BIGINT, BIGINT) IS
  'Atomically accept a pending booking. Only the first caller succeeds; others get ok: false.';
