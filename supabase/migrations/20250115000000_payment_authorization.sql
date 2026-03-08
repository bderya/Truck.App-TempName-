-- Pre-auth payment_id on booking (capture when job is completed).
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS payment_id TEXT;

COMMENT ON COLUMN bookings.payment_id IS 'Gateway payment/intent id from pre-auth; capture when job is completed.';

-- Saved payment method per user (token ID only; no raw card data).
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS default_card_token_id TEXT;

COMMENT ON COLUMN users.default_card_token_id IS 'Saved payment method token ID from gateway (Stripe PM id or Iyzico token).';

-- Pre-auth: create PaymentRequest with auth only (paymentGroup=LISTING, capture later).
-- Returns payment_id to store on booking.
CREATE OR REPLACE FUNCTION payment_authorize(
  p_card_token_id TEXT,
  p_amount DOUBLE PRECISION,
  p_currency TEXT,
  p_customer_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- TODO: Stripe: Create PaymentIntent with capture_method='manual', amount=p_amount.
  --       Iyzico: Create PaymentRequest with paymentGroup='LISTING', auth only.
  --       Return payment_id / payment_intent_id for capture on job completion.
  RETURN jsonb_build_object(
    'ok', false,
    'error', 'Payment not configured. Implement payment_authorize with your gateway (auth-only).'
  );
END;
$$;
