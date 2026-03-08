-- Allow drivers to update pending bookings (to accept and set driver_id).
-- Requires: RLS policies that permit updates. If using Supabase Auth with a
-- users table linked via auth_id, add a check: EXISTS (SELECT 1 FROM users u
-- WHERE u.auth_id = auth.uid() AND u.user_type = 'driver').
--
-- For demo/testing: this permissive policy allows any role with table access
-- to accept pending bookings. Tighten for production.
CREATE POLICY bookings_update_driver_accept ON bookings
  FOR UPDATE
  USING (status = 'pending' AND driver_id IS NULL);
