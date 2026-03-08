-- Manual dispatch: status 'assigned' when admin assigns a job to a driver.
-- admin_logs: audit trail for admin actions (e.g. manual assign).

-- Add 'assigned' to booking_status enum (after pending, before accepted in flow)
DO $$ BEGIN
  ALTER TYPE booking_status ADD VALUE 'assigned';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Audit log for admin actions (manual assign, etc.)
CREATE TABLE IF NOT EXISTS admin_logs (
  id                BIGSERIAL PRIMARY KEY,
  admin_user_id     UUID,                    -- Supabase auth user id (if admin uses auth)
  admin_email       TEXT,                    -- For display: "Admin X"
  action            TEXT NOT NULL,           -- e.g. 'manual_assign'
  job_id            BIGINT REFERENCES bookings(id),
  driver_id         BIGINT REFERENCES users(id),
  metadata          JSONB DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_logs_job_id ON admin_logs(job_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON admin_logs(created_at DESC);

COMMENT ON TABLE admin_logs IS 'Audit log for admin dashboard actions (e.g. Admin X assigned Job Y to Driver Z).';

-- RPC: Driver confirms an admin-assigned job (assigned -> accepted).
CREATE OR REPLACE FUNCTION confirm_admin_assigned_booking(p_booking_id BIGINT, p_driver_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
BEGIN
  SELECT id, status, driver_id INTO v_booking
  FROM bookings WHERE id = p_booking_id FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Booking not found');
  END IF;
  IF v_booking.status <> 'assigned' OR v_booking.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Not assigned to this driver');
  END IF;

  UPDATE bookings
  SET status = 'accepted', accepted_at = NOW(), updated_at = NOW()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

COMMENT ON FUNCTION confirm_admin_assigned_booking IS 'Driver confirms an admin-assigned job: status assigned -> accepted.';
