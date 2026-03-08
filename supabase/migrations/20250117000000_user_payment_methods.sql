-- Store tokenized payment methods per user (no raw card data).
-- Token comes from gateway (Stripe PaymentMethod id or Iyzico token) after client-side or server-side tokenization.
CREATE TABLE IF NOT EXISTS user_payment_methods (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  card_token      TEXT NOT NULL,
  last4           CHAR(4),
  brand           VARCHAR(20),
  exp_month       SMALLINT,
  exp_year        SMALLINT,
  is_default      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, card_token)
);

CREATE INDEX idx_user_payment_methods_user_id ON user_payment_methods(user_id);
CREATE INDEX idx_user_payment_methods_default ON user_payment_methods(user_id, is_default) WHERE is_default = TRUE;

ALTER TABLE user_payment_methods ENABLE ROW LEVEL SECURITY;

-- Restrict to own rows when auth is linked to user_id (e.g. via custom claim). For now allow for app flow.
CREATE POLICY user_payment_methods_all ON user_payment_methods
  FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE user_payment_methods IS 'Tokenized cards only; card_token is gateway token/PM id. No raw PAN/CVV stored.';

-- Tokenize card via gateway and store in user_payment_methods.
-- In production: call Stripe CreatePaymentMethod/CreateToken or Iyzico equivalent; never log raw card.
-- Accepts token from client (preferred) or card params for server-side tokenization (PCI scope).
CREATE OR REPLACE FUNCTION payment_tokenize_and_save(
  p_user_id BIGINT,
  p_card_token TEXT DEFAULT NULL,
  p_card_number TEXT DEFAULT NULL,
  p_exp_month SMALLINT DEFAULT NULL,
  p_exp_year SMALLINT DEFAULT NULL,
  p_cvc TEXT DEFAULT NULL,
  p_set_default BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token_id TEXT;
  v_last4 TEXT;
  v_brand TEXT;
  v_exp_m SMALLINT;
  v_exp_y SMALLINT;
BEGIN
  IF p_card_token IS NOT NULL AND length(trim(p_card_token)) > 0 THEN
    v_token_id := trim(p_card_token);
    v_last4 := right(replace(p_card_token, ' ', ''), 4);
    v_brand := 'card';
    v_exp_m := p_exp_month;
    v_exp_y := p_exp_year;
  ELSIF p_card_number IS NOT NULL AND length(replace(p_card_number, ' ', '')) >= 13 THEN
    -- Server-side tokenization: call gateway API here (Stripe/Iyzico). Stub returns a placeholder.
    -- TODO: Stripe.paymentMethods.create({ type: 'card', card: { number, exp_month, exp_year, cvc } })
    --       or Iyzico tokenize; then v_token_id := gateway_response.id, v_last4, v_brand from response.
    v_token_id := 'pm_' || substr(md5(p_card_number || coalesce(p_cvc, '') || clock_timestamp()::text), 1, 24);
    v_last4 := right(replace(trim(p_card_number), ' ', ''), 4);
    v_brand := 'card';
    v_exp_m := p_exp_month;
    v_exp_y := p_exp_year;
  ELSE
    RETURN jsonb_build_object('ok', false, 'error', 'Missing card_token or valid card_number');
  END IF;

  IF p_set_default THEN
    UPDATE user_payment_methods SET is_default = FALSE WHERE user_id = p_user_id;
  END IF;

  INSERT INTO user_payment_methods (user_id, card_token, last4, brand, exp_month, exp_year, is_default)
  VALUES (p_user_id, v_token_id, v_last4, v_brand, v_exp_m, v_exp_y, p_set_default)
  ON CONFLICT (user_id, card_token) DO UPDATE SET
    last4 = EXCLUDED.last4,
    brand = EXCLUDED.brand,
    exp_month = EXCLUDED.exp_month,
    exp_year = EXCLUDED.exp_year,
    is_default = EXCLUDED.is_default;

  UPDATE users SET default_card_token_id = v_token_id, updated_at = now() WHERE id = p_user_id AND p_set_default;

  RETURN jsonb_build_object(
    'ok', true,
    'token_id', v_token_id,
    'last4', v_last4,
    'brand', v_brand,
    'exp_month', v_exp_m,
    'exp_year', v_exp_y
  );
END;
$$;

COMMENT ON FUNCTION payment_tokenize_and_save IS 'Store gateway token for user. Prefer p_card_token from client-side tokenization (Stripe Elements).';
