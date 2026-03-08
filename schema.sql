-- Tow Truck On-Demand App Schema (Uber-style)
-- Requires: PostgreSQL 12+ with PostGIS extension

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "postgis";

-- -----------------------------------------------------------------------------
-- ENUM TYPES
-- -----------------------------------------------------------------------------

CREATE TYPE user_type AS ENUM ('client', 'driver');

CREATE TYPE truck_type AS ENUM ('standard', 'heavy', 'motorcycle');

CREATE TYPE booking_status AS ENUM (
  'pending',
  'accepted',
  'on_the_way',
  'picked_up',
  'completed',
  'cancelled'
);

CREATE TYPE user_verification_status AS ENUM ('pending', 'approved', 'rejected');

-- -----------------------------------------------------------------------------
-- TABLES
-- -----------------------------------------------------------------------------

CREATE TABLE users (
  id                  BIGSERIAL PRIMARY KEY,
  phone_number        VARCHAR(20) NOT NULL UNIQUE,
  full_name           VARCHAR(255) NOT NULL,
  user_type           user_type NOT NULL,
  avatar_url          TEXT,
  is_verified         BOOLEAN NOT NULL DEFAULT FALSE,
  status              user_verification_status NOT NULL DEFAULT 'pending',
  license_image_url   TEXT,
  criminal_record_url TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tow_trucks (
  id                  BIGSERIAL PRIMARY KEY,
  driver_id           BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plate_number        VARCHAR(20) NOT NULL UNIQUE,
  truck_type          truck_type NOT NULL,
  current_latitude    DOUBLE PRECISION NOT NULL DEFAULT 0,
  current_longitude   DOUBLE PRECISION NOT NULL DEFAULT 0,
  is_available        BOOLEAN NOT NULL DEFAULT TRUE,
  plate_image_url     TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_driver CHECK (
    EXISTS (SELECT 1 FROM users u WHERE u.id = driver_id AND u.user_type = 'driver')
  )
);

-- Spatial index for location tracking (finds nearby trucks, distance queries)
CREATE INDEX idx_tow_trucks_location ON tow_trucks
  USING GIST (ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326)::geography);

CREATE INDEX idx_tow_trucks_driver_id ON tow_trucks(driver_id);
CREATE INDEX idx_tow_trucks_is_available ON tow_trucks(is_available) WHERE is_available = TRUE;

CREATE TABLE bookings (
  id                    BIGSERIAL PRIMARY KEY,
  client_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  driver_id             BIGINT REFERENCES users(id) ON DELETE SET NULL,
  pickup_address        TEXT NOT NULL,
  destination_address   TEXT NOT NULL,
  pickup_lat            DOUBLE PRECISION NOT NULL,
  pickup_lng            DOUBLE PRECISION NOT NULL,
  price                 DECIMAL(10, 2),
  vehicle_type_requested truck_type NOT NULL,
  status                booking_status NOT NULL DEFAULT 'pending',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_client CHECK (
    EXISTS (SELECT 1 FROM users u WHERE u.id = client_id AND u.user_type = 'client')
  ),
  CONSTRAINT valid_driver_booking CHECK (
    driver_id IS NULL OR EXISTS (SELECT 1 FROM users u WHERE u.id = driver_id AND u.user_type = 'driver')
  )
);

-- Spatial index for pickup location (nearby bookings, distance queries)
CREATE INDEX idx_bookings_pickup_location ON bookings
  USING GIST (ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326)::geography);

CREATE INDEX idx_bookings_client_id ON bookings(client_id);
CREATE INDEX idx_bookings_driver_id ON bookings(driver_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_created_at ON bookings(created_at DESC);

-- -----------------------------------------------------------------------------
-- HELPER: Auto-update updated_at timestamp
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER tow_trucks_updated_at
  BEFORE UPDATE ON tow_trucks
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- -----------------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
-- Before each request, set the current user: SET app.current_user_id = <user_id>;
-- With Supabase: use auth.uid() instead of current_user_id() in policies.

CREATE OR REPLACE FUNCTION current_user_id()
RETURNS BIGINT AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::bigint;
$$ LANGUAGE sql STABLE;

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tow_trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users
CREATE POLICY users_select_own ON users
  FOR SELECT USING (current_user_id() = id);

CREATE POLICY users_update_own ON users
  FOR UPDATE USING (current_user_id() = id);

CREATE POLICY users_insert ON users
  FOR INSERT WITH CHECK (true);

-- RLS Policies for tow_trucks
CREATE POLICY tow_trucks_select ON tow_trucks
  FOR SELECT USING (
    driver_id = current_user_id() OR
    is_available = TRUE  -- Clients can see available trucks
  );

CREATE POLICY tow_trucks_insert_driver ON tow_trucks
  FOR INSERT WITH CHECK (driver_id = current_user_id());

CREATE POLICY tow_trucks_update_driver ON tow_trucks
  FOR UPDATE USING (driver_id = current_user_id());

CREATE POLICY tow_trucks_delete_driver ON tow_trucks
  FOR DELETE USING (driver_id = current_user_id());

-- RLS Policies for bookings
CREATE POLICY bookings_select_participant ON bookings
  FOR SELECT USING (
    client_id = current_user_id() OR driver_id = current_user_id()
  );

CREATE POLICY bookings_insert_client ON bookings
  FOR INSERT WITH CHECK (client_id = current_user_id());

CREATE POLICY bookings_update_participant ON bookings
  FOR UPDATE USING (
    client_id = current_user_id() OR driver_id = current_user_id()
  );
