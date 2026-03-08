-- Stub: trigger automated email with receipt link after payment is confirmed.
-- Implement with Resend, SendGrid, or Supabase Auth email template.
CREATE OR REPLACE FUNCTION send_receipt_email(p_booking_id BIGINT, p_to_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_to_email IS NULL OR trim(p_to_email) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Email required');
  END IF;

  -- TODO: Call your email provider (Resend/SendGrid/Edge Function) with receipt link.
  -- Example: SELECT net.http_post('https://your-app.com/api/send-receipt', ...);
  -- Or: pg_notify('send_receipt', json_build_object('booking_id', p_booking_id, 'email', p_to_email)::text);
  RETURN jsonb_build_object(
    'ok', true,
    'message', 'Receipt email queued. Implement with your email provider.'
  );
END;
$$;

COMMENT ON FUNCTION send_receipt_email(BIGINT, TEXT) IS
  'Sends receipt/invoice link to customer email. Implement with Resend, SendGrid, or Edge Function.';
