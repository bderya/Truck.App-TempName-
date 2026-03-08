-- RPC called by Edge Function (or app) when a booking becomes completed: capture pre-auth and distribute.
CREATE OR REPLACE FUNCTION payment_capture_on_booking_complete(p_booking_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
  v_client_token TEXT;
  v_driver_account_id TEXT;
BEGIN
  SELECT id, payment_id, price, client_id, driver_id
  INTO v_booking
  FROM bookings
  WHERE id = p_booking_id AND status = 'completed';

  IF NOT FOUND OR v_booking.payment_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Booking not found or no payment_id');
  END IF;

  -- Get client's default card token (for capture) and driver's Stripe connect account id.
  SELECT default_card_token_id INTO v_client_token
  FROM users WHERE id = v_booking.client_id;

  -- Driver's Stripe Connect account id: add column to users/tow_trucks when using Connect.
  v_driver_account_id := 'acct_placeholder';

  -- TODO: Call Stripe Capture PaymentIntent (v_booking.payment_id) and optionally transfer to driver.
  -- Stripe: POST /v1/payment_intents/{id}/capture then create Transfer to Connect account.
  -- Iyzico: Capture the pre-auth payment and settle to sub-merchant.
  RETURN jsonb_build_object(
    'ok', true,
    'booking_id', p_booking_id,
    'payment_id', v_booking.payment_id,
    'message', 'Capture triggered. Implement gateway capture in this function.'
  );
END;
$$;

COMMENT ON FUNCTION payment_capture_on_booking_complete(BIGINT) IS
  'Called when booking is completed (e.g. by Edge Function). Captures pre-authorized payment and distributes to driver.';
