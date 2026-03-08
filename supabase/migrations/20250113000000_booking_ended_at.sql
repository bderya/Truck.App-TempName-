-- Timestamp when the job was completed (driver confirmed delivery).
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ;

COMMENT ON COLUMN bookings.ended_at IS 'When the booking was completed (delivery confirmed).';
