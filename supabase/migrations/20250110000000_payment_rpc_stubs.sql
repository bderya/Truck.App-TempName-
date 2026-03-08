-- Payment RPC stubs. Replace with real Stripe Connect / Iyzico logic in your backend.
-- Security: Never store raw card data. Only store token IDs from the gateway.

-- Add card: store token from gateway (Stripe PM id or Iyzico token).
CREATE OR REPLACE FUNCTION payment_add_card(
  p_payment_method_id TEXT,
  p_customer_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- TODO: Call Stripe/Iyzico to attach PM to customer; store token_id in your table.
  RETURN jsonb_build_object(
    'ok', false,
    'error', 'Payment not configured. Implement payment_add_card with your gateway.'
  );
END;
$$;

-- Process simple payment (no split).
CREATE OR REPLACE FUNCTION payment_process(
  p_card_token_id TEXT,
  p_amount DOUBLE PRECISION,
  p_currency TEXT,
  p_booking_id TEXT,
  p_customer_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- TODO: Charge via Stripe/Iyzico using p_card_token_id; never store raw card.
  RETURN jsonb_build_object(
    'ok', false,
    'error', 'Payment not configured. Implement payment_process with your gateway.'
  );
END;
$$;

-- Split payment: X% platform, Y% driver (Stripe Connect transfer or Iyzico settlement).
CREATE OR REPLACE FUNCTION payment_distribute_funds(
  p_card_token_id TEXT,
  p_total_amount DOUBLE PRECISION,
  p_currency TEXT,
  p_booking_id TEXT,
  p_driver_stripe_account_id TEXT,
  p_platform_percent DOUBLE PRECISION DEFAULT 0.15,
  p_driver_percent DOUBLE PRECISION DEFAULT 0.85,
  p_customer_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_platform_amount DOUBLE PRECISION;
  v_driver_amount DOUBLE PRECISION;
BEGIN
  v_platform_amount := p_total_amount * p_platform_percent;
  v_driver_amount   := p_total_amount * p_driver_percent;

  -- TODO: 1. Create PaymentIntent with transfer_data to driver (Stripe Connect)
  --       or use Iyzico marketplace APIs.
  --       2. Charge p_card_token_id; on success return breakdown.
  --       3. On failure return ok=false, error=..., code=... (e.g. insufficient_funds, card_declined).

  RETURN jsonb_build_object(
    'ok', false,
    'error', 'Payment not configured. Implement payment_distribute_funds with Stripe Connect or Iyzico.'
  );
END;
$$;
