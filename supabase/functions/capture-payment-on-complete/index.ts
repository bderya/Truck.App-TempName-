// Capture payment when a booking is marked completed.
// Trigger this via Database Webhook: on bookings UPDATE when new record.status = 'completed'.
// Payload: { type, table, record, old_record } (Supabase webhook format).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const payload = await req.json();
    const table = payload?.table;
    const record = payload?.record ?? payload?.new ?? {};
    const oldRecord = payload?.old_record ?? payload?.old ?? {};
    const eventType = payload?.type ?? payload?.eventType;

    if (table !== "bookings" || eventType !== "UPDATE") {
      return new Response(
        JSON.stringify({ ok: true, skipped: "not a booking update" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const newStatus = record.status ?? record?.status;
    const oldStatus = oldRecord?.status;
    if (newStatus !== "completed" || oldStatus === "completed") {
      return new Response(
        JSON.stringify({ ok: true, skipped: "status not changed to completed" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const bookingId = record.id ?? record?.id;
    const paymentId = record.payment_id ?? record?.payment_id;
    if (!bookingId || !paymentId) {
      return new Response(
        JSON.stringify({ ok: false, error: "Missing booking id or payment_id" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Call RPC: returns dynamic split (driver_net_amount, platform_amount, platform_percent, driver_percent)
    // from calculate_net_earnings (tier + surge). Use these when calling Stripe/Iyzico split API.
    const { data, error } = await supabase.rpc("payment_capture_on_booking_complete", {
      p_booking_id: bookingId,
    });

    if (error) {
      console.error("payment_capture_on_booking_complete error:", error);
      return new Response(
        JSON.stringify({ ok: false, error: error.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    return new Response(
      JSON.stringify({ ok: true, data }),
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
