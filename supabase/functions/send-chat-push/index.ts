// When a new message is inserted, send an FCM push to the recipient (if not on chat screen).
// Trigger via Database Webhook: table messages, event INSERT.
// Requires: FCM server key or service account in env (FCM_SERVER_KEY or GOOGLE_APPLICATION_CREDENTIALS).

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
    const record = payload?.record ?? payload?.new ?? payload;
    const table = payload?.table;
    const eventType = payload?.type ?? payload?.eventType;

    if (table !== "messages" || eventType !== "INSERT" || !record?.id) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "not a message insert" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const bookingId = record.booking_id;
    const senderId = record.sender_id;
    const content = (record.content || "").slice(0, 80);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: booking } = await supabase
      .from("bookings")
      .select("client_id, driver_id")
      .eq("id", bookingId)
      .single();

    if (!booking) {
      return new Response(
        JSON.stringify({ ok: false, error: "Booking not found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const recipientId = senderId === booking.client_id ? booking.driver_id : booking.client_id;
    if (recipientId == null) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "no recipient" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const { data: user } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", recipientId)
      .single();

    const fcmToken = user?.fcm_token;
    if (!fcmToken) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "no fcm_token for recipient" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
    if (!fcmServerKey) {
      console.warn("FCM_SERVER_KEY not set; skip sending push");
      return new Response(
        JSON.stringify({ ok: true, skipped: "FCM not configured" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${fcmServerKey}`,
      },
      body: JSON.stringify({
        to: fcmToken,
        notification: {
          title: "New message",
          body: content || "You have a new chat message",
        },
        data: { booking_id: String(bookingId), type: "chat" },
      }),
    });

    if (!res.ok) {
      const text = await res.text();
      console.error("FCM send failed:", res.status, text);
      return new Response(
        JSON.stringify({ ok: false, error: text }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    return new Response(
      JSON.stringify({ ok: true }),
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
