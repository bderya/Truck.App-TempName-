-- Verification fields for users and tow_trucks
-- Users: is_verified, status (pending/approved/rejected), document URLs
-- Tow_trucks: plate_image_url

DO $$ BEGIN
  CREATE TYPE user_verification_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE users
  ADD COLUMN is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN status user_verification_status NOT NULL DEFAULT 'pending',
  ADD COLUMN license_image_url TEXT,
  ADD COLUMN criminal_record_url TEXT;

ALTER TABLE tow_trucks
  ADD COLUMN plate_image_url TEXT;

CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_is_verified ON users(is_verified) WHERE user_type = 'driver';
