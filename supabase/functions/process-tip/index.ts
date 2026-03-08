// Process tip: charge client's card then credit 100% to driver wallet (0% platform commission).
// POST body: { bookingId, driverId, amount, cardTokenId, currency? }
// Requires: Stripe secret key to charge; then calls credit_driver_tip RPC.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ ok: false, error: "Method not allowed" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 405 }
      );
    }

    const body = await req.json().catch(() => ({}));
    const bookingId = Number(body?.bookingId ?? body?.booking_id);
    const driverId = Number(body?.driverId ?? body?.driver_id);
    const amount = Number(body?.amount);
    const cardTokenId = body?.cardTokenId ?? body?.card_token_id ?? body?.payment_method_id;
    const currency = (body?.currency ?? "try").toLowerCase();

    if (!bookingId || !driverId || !amount || amount <= 0 || !cardTokenId) {
      return new Response(
        JSON.stringify({ ok: false, error: "bookingId, driverId, amount, cardTokenId required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // 1. Charge the client's card (100% tip; no platform commission)
    if (!stripeSecret) {
      return new Response(
        JSON.stringify({ ok: false, error: "Payment not configured" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 503 }
      );
    }
    const amountCents = Math.round(amount * 100);
    const res = await fetch("https://api.stripe.com/v1/payment_intents", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${stripeSecret}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          amount: String(amountCents),
          currency,
          "payment_method": cardTokenId,
          confirm: "true",
          "metadata[booking_id]": String(bookingId),
          "metadata[driver_id]": String(driverId),
          "metadata[type]": "tip",
        }),
      });

    const chargeData = await res.json().catch(() => ({}));
    if (chargeData.error || !res.ok) {
      return new Response(
        JSON.stringify({ ok: false, error: chargeData.error?.message ?? "Charge failed" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // 2. Credit driver wallet (100% to driver)
    const { data: creditResult, error: creditError } = await supabase.rpc("credit_driver_tip", {
      p_booking_id: bookingId,
      p_driver_id: driverId,
      p_amount: amount,
      p_payment_ref: "Tip (100% to driver)",
    });

    if (creditError) {
      return new Response(
        JSON.stringify({ ok: false, error: creditError.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    const result = creditResult as { ok?: boolean; error?: string };
    if (!result?.ok) {
      return new Response(
        JSON.stringify({ ok: false, error: result?.error ?? "Credit failed" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    return new Response(
      JSON.stringify({ ok: true, amount }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
