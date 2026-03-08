# Driver Wallet System

## Database

- **wallets**: One row per driver (`driver_id` unique). `available_balance` (≥ 0), `total_earned`. Updated by trigger on booking completed and by withdrawal requests.
- **transactions**: Every credit/debit. Columns: `wallet_id`, `amount` (positive = credit, negative = debit), `type` (booking_credit, withdrawal, withdrawal_fee, adjustment), `status` (completed, pending_admin_approval, rejected, cancelled), `reference_id`, `description`, `created_at`.

## Real-time balance

- When a booking is set to `status = 'completed'`, trigger `trg_wallet_credit_on_booking_completed` runs:
  - Ensures the driver has a wallet (`ensure_wallet`).
  - Credits `available_balance` and `total_earned` by `driver_net_amount` (or `price * 0.85` if not set).
  - Inserts a `booking_credit` transaction with `reference_id = booking.id`.
- The app subscribes to Realtime on the driver’s wallet row so the balance card updates when the trigger (or withdrawal) changes the wallet.

## Withdrawal flow

1. Driver taps **Para çek** and enters an amount (≤ available balance).
2. App calls `request_withdrawal(p_driver_id, p_amount)` RPC:
   - Deducts amount from `available_balance`.
   - Inserts a `withdrawal` transaction with `amount < 0` and `status = 'pending_admin_approval'`.
3. Admin approves or rejects the request (e.g. in admin dashboard); on approval the payout is sent via bank/Stripe; on rejection you can add a follow-up that refunds `available_balance` and sets transaction status to `rejected`.

## UI

- **Earnings (Cüzdan)** screen: balance card (gradient, available + total earned), **Withdraw** button, line chart (last 7 days earnings from transactions), scrollable transaction list (green = credits, red = withdrawals/fees).
- Transactions show type and status (e.g. “Çekim talebi (onay bekliyor)” for pending withdrawal).

## RPCs

- `get_or_create_wallet(p_driver_id)`: Returns wallet row; creates one with 0 balance if missing.
- `request_withdrawal(p_driver_id, p_amount)`: Deducts from balance and creates pending withdrawal transaction.

## Realtime

- `wallets` and `transactions` are in the `supabase_realtime` publication so the app can subscribe and refresh the balance/transaction list when data changes.
