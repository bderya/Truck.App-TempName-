-- Intercity transport: driver preference, booking mode, scheduling, tolls.

-- Tow trucks: driver opts in to receive intercity (long-distance) requests.
ALTER TABLE tow_trucks
  ADD COLUMN IF NOT EXISTS open_to_intercity BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN tow_trucks.open_to_intercity IS 'When true, driver sees pending intercity (long-distance) jobs.';

-- Bookings: intercity flag, scheduled pickup, destination coords, estimated tolls.
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS is_intercity BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS desired_pickup_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS estimated_tolls DECIMAL(10, 2),
  ADD COLUMN IF NOT EXISTS destination_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS destination_lng DOUBLE PRECISION;

COMMENT ON COLUMN bookings.is_intercity IS 'True when pickup and destination are in different cities / long distance.';
COMMENT ON COLUMN bookings.desired_pickup_at IS 'For intercity: preferred pickup date/time (planned transfer).';
COMMENT ON COLUMN bookings.estimated_tolls IS 'Estimated highway/bridge tolls included in price for intercity.';
COMMENT ON COLUMN bookings.destination_lat IS 'Destination coordinates for route distance and intercity detection.';
COMMENT ON COLUMN bookings.destination_lng IS 'Destination longitude.';

CREATE INDEX IF NOT EXISTS idx_bookings_is_intercity ON bookings(is_intercity) WHERE is_intercity = TRUE;
CREATE INDEX IF NOT EXISTS idx_bookings_desired_pickup_at ON bookings(desired_pickup_at) WHERE desired_pickup_at IS NOT NULL;
