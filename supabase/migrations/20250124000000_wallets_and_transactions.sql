-- Driver Wallet System: wallets table, transactions table, auto-credit on booking completed, withdrawal request.

DO $$ BEGIN
  CREATE TYPE wallet_transaction_type AS ENUM (
    'booking_credit',
    'withdrawal',
    'withdrawal_fee',
    'adjustment'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE wallet_transaction_status AS ENUM (
    'completed',
    'pending_admin_approval',
    'rejected',
    'cancelled'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- One wallet per driver.
CREATE TABLE IF NOT EXISTS wallets (
  id                BIGSERIAL PRIMARY KEY,
  driver_id         BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  available_balance DECIMAL(12, 2) NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
  total_earned      DECIMAL(12, 2) NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_driver_wallet CHECK (
    EXISTS (SELECT 1 FROM users u WHERE u.id = driver_id AND u.user_type = 'driver')
  )
);

CREATE INDEX IF NOT EXISTS idx_wallets_driver_id ON wallets(driver_id);

ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY wallets_driver_own ON wallets FOR ALL
  USING (true) WITH CHECK (true);

COMMENT ON TABLE wallets IS 'Driver wallets. Balance updated by trigger on booking completed and by withdrawal requests.';

-- Every credit/debit is logged.
CREATE TABLE IF NOT EXISTS transactions (
  id           BIGSERIAL PRIMARY KEY,
  wallet_id    BIGINT NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  amount       DECIMAL(12, 2) NOT NULL,
  type         wallet_transaction_type NOT NULL,
  status       wallet_transaction_status NOT NULL DEFAULT 'completed',
  reference_id BIGINT,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_credit_debit CHECK (
    (type = 'booking_credit' AND amount > 0) OR
    (type IN ('withdrawal', 'withdrawal_fee') AND amount < 0) OR
    (type = 'adjustment')
  )
);

CREATE INDEX IF NOT EXISTS idx_transactions_wallet_id ON transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON transactions(reference_id) WHERE reference_id IS NOT NULL;

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY transactions_all ON transactions FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE transactions IS 'Wallet transaction log. Positive = credit (e.g. booking_credit), negative = debit (withdrawal).';

-- Ensure wallet exists for driver (used by trigger and withdrawal).
CREATE OR REPLACE FUNCTION ensure_wallet(p_driver_id BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id BIGINT;
BEGIN
  SELECT id INTO v_wallet_id FROM wallets WHERE driver_id = p_driver_id;
  IF v_wallet_id IS NOT NULL THEN
    RETURN v_wallet_id;
  END IF;
  INSERT INTO wallets (driver_id) VALUES (p_driver_id)
  ON CONFLICT (driver_id) DO NOTHING;
  SELECT id INTO v_wallet_id FROM wallets WHERE driver_id = p_driver_id;
  RETURN v_wallet_id;
END;
$$;

-- Credit wallet when a booking becomes completed (use driver_net_amount or price * 0.85).
CREATE OR REPLACE FUNCTION wallet_credit_on_booking_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id BIGINT;
  v_amount    DECIMAL(12, 2);
  v_booking_id BIGINT;
BEGIN
  IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;
  IF NEW.driver_id IS NULL OR NEW.price IS NULL OR NEW.price <= 0 THEN
    RETURN NEW;
  END IF;

  v_booking_id := NEW.id;
  v_amount := COALESCE(NEW.driver_net_amount, (NEW.price * 0.85)::DECIMAL(12, 2));

  v_wallet_id := ensure_wallet(NEW.driver_id);
  IF v_wallet_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE wallets
  SET
    available_balance = available_balance + v_amount,
    total_earned = total_earned + v_amount,
    updated_at = NOW()
  WHERE id = v_wallet_id;

  INSERT INTO transactions (wallet_id, amount, type, status, reference_id, description)
  VALUES (
    v_wallet_id,
    v_amount,
    'booking_credit',
    'completed',
    v_booking_id,
    'Job #' || v_booking_id || ' completed'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wallet_credit_on_booking_completed ON bookings;
CREATE TRIGGER trg_wallet_credit_on_booking_completed
  AFTER UPDATE OF status ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION wallet_credit_on_booking_completed();

-- Withdrawal request: deduct from available_balance and insert debit transaction with status pending_admin_approval.
CREATE OR REPLACE FUNCTION request_withdrawal(p_driver_id BIGINT, p_amount DECIMAL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id BIGINT;
  v_balance   DECIMAL(12, 2);
  v_txn_id    BIGINT;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Amount must be positive');
  END IF;

  v_wallet_id := ensure_wallet(p_driver_id);
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Wallet not found');
  END IF;

  SELECT available_balance INTO v_balance FROM wallets WHERE id = v_wallet_id FOR UPDATE;
  IF v_balance IS NULL OR v_balance < p_amount THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Insufficient balance');
  END IF;

  UPDATE wallets
  SET available_balance = available_balance - p_amount, updated_at = NOW()
  WHERE id = v_wallet_id;

  INSERT INTO transactions (wallet_id, amount, type, status, description)
  VALUES (v_wallet_id, -p_amount, 'withdrawal', 'pending_admin_approval', 'Withdrawal request')
  RETURNING id INTO v_txn_id;

  RETURN jsonb_build_object(
    'ok', true,
    'transaction_id', v_txn_id,
    'amount', p_amount,
    'new_balance', v_balance - p_amount
  );
END;
$$;

COMMENT ON FUNCTION request_withdrawal(BIGINT, DECIMAL) IS
  'Driver requests payout. Deducts from available_balance and creates transaction with status pending_admin_approval.';

-- Get or create wallet for driver (so UI can show 0 balance before first completed job).
CREATE OR REPLACE FUNCTION get_or_create_wallet(p_driver_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet RECORD;
BEGIN
  PERFORM ensure_wallet(p_driver_id);
  SELECT * INTO v_wallet FROM wallets WHERE driver_id = p_driver_id LIMIT 1;
  IF v_wallet IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Wallet not found');
  END IF;
  RETURN jsonb_build_object('ok', true, 'wallet', to_jsonb(v_wallet));
END;
$$;

-- Realtime for wallet balance and transaction list
ALTER PUBLICATION supabase_realtime ADD TABLE wallets;
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
