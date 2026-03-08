-- Admin approval: set user verification status and is_verified.
-- Call from Admin Dashboard (Supabase Dashboard SQL or RPC).
-- For production: restrict to admin role (e.g. check auth.jwt() ->> 'role' = 'admin' or use service_role).

-- Approve or reject a user (sets status and is_verified).
CREATE OR REPLACE FUNCTION approve_user(
  p_user_id BIGINT,
  p_status TEXT  -- 'pending' | 'approved' | 'rejected'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status user_verification_status;
BEGIN
  v_status := p_status::user_verification_status;

  UPDATE users
  SET
    status = v_status,
    is_verified = (v_status = 'approved'),
    updated_at = NOW()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'user_id', p_user_id,
    'status', v_status::text,
    'is_verified', (v_status = 'approved')
  );
END;
$$;

-- Toggle is_verified only (convenience).
CREATE OR REPLACE FUNCTION set_user_verified(
  p_user_id BIGINT,
  p_verified BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE users
  SET
    is_verified = p_verified,
    status = CASE WHEN p_verified THEN 'approved'::user_verification_status ELSE status END,
    updated_at = NOW()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object('ok', true, 'user_id', p_user_id, 'is_verified', p_verified);
END;
$$;

-- Grant execute to authenticated users (tighten to admin-only in production).
-- GRANT EXECUTE ON FUNCTION approve_user(BIGINT, TEXT) TO authenticated;
-- GRANT EXECUTE ON FUNCTION set_user_verified(BIGINT, BOOLEAN) TO authenticated;
