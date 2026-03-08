-- Legal consent tracking for App Store / KVKK compliance.
-- Version and date stored when user accepts terms during registration.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS consent_version TEXT,
  ADD COLUMN IF NOT EXISTS consent_date TIMESTAMPTZ;

COMMENT ON COLUMN users.consent_version IS 'Version of accepted terms (e.g. v1.0).';
COMMENT ON COLUMN users.consent_date IS 'When the user accepted the terms (registration).';
