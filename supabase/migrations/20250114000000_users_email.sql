-- Optional email for Complete Profile after phone auth.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email TEXT;

COMMENT ON COLUMN users.email IS 'Optional; collected at signup (Complete Profile).';
