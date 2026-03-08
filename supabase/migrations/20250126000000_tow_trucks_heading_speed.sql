-- Add heading (direction) and speed for driver tracking (background geolocation / headless sync).
ALTER TABLE tow_trucks
  ADD COLUMN IF NOT EXISTS current_heading DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS current_speed_kmh DOUBLE PRECISION;

COMMENT ON COLUMN tow_trucks.current_heading IS 'Direction of travel in degrees (0-360). From background geolocation.';
COMMENT ON COLUMN tow_trucks.current_speed_kmh IS 'Speed in km/h. From background geolocation.';
