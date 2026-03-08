# Capture payment on booking complete

This Edge Function is intended to be triggered when a booking’s status changes to `completed`, so that the pre-authorized payment can be captured and funds distributed.

## Setup

1. **Database Webhook (Supabase Dashboard)**  
   - Database → Webhooks → Create webhook  
   - Table: `bookings`  
   - Events: **Update**  
   - HTTP URL:  
     - Production: `https://<project-ref>.supabase.co/functions/v1/capture-payment-on-complete`  
     - Local: `http://host.docker.internal:54321/functions/v1/capture-payment-on-complete`  
   - (Optional) Add a filter so the webhook only runs when `record.status = 'completed'` if your provider supports it.

2. **RPC**  
   Ensure the migration that creates `payment_capture_on_booking_complete(p_booking_id)` is applied. Implement the TODO inside that function to call your payment gateway (Stripe Capture PaymentIntent, Iyzico capture, etc.).

3. **Deploy**  
   `supabase functions deploy capture-payment-on-complete`

## Payload

The function expects a Supabase Database Webhook payload with `table`, `type`, `record`, and `old_record`. On `bookings` UPDATE it checks `record.status === 'completed'` and then calls the capture RPC.
