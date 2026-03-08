// Manual dispatch: Admin assigns a pending job to a specific driver.
// POST body: { jobId: number, driverId: number }
// Authorization: Bearer <admin JWT> (optional; used for admin_logs)
// 1. Update booking: driver_id, status = 'assigned'
// 2. Insert admin_logs: Admin X assigned Job Y to Driver Z
// 3. Send high-priority FCM to the driver

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
    const jobId = Number(body?.jobId ?? body?.job_id);
    const driverId = Number(body?.driverId ?? body?.driver_id);

    if (!jobId || !driverId) {
      return new Response(
        JSON.stringify({ ok: false, error: "jobId and driverId required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? serviceKey;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Resolve admin identity for audit log (optional)
    let adminEmail = "system";
    let adminUserId: string | null = null;
    const authHeader = req.headers.get("Authorization");
    const token = authHeader?.replace(/^Bearer\s+/i, "");
    if (token) {
      try {
        const authClient = createClient(supabaseUrl, anonKey);
        const { data: { user } } = await authClient.auth.getUser(token);
        if (user?.email) adminEmail = user.email;
        if (user?.id) adminUserId = user.id;
      } catch (_) {
        // ignore
      }
    }

    // 1. Ensure booking is pending and update to assigned
    const { data: booking, error: fetchErr } = await supabase
      .from("bookings")
      .select("id, status, pickup_address")
      .eq("id", jobId)
      .single();

    if (fetchErr || !booking) {
      return new Response(
        JSON.stringify({ ok: false, error: "Booking not found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 404 }
      );
    }

    if (booking.status !== "pending") {
      return new Response(
        JSON.stringify({ ok: false, error: "Booking is not pending" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const { error: updateErr } = await supabase
      .from("bookings")
      .update({
        driver_id: driverId,
        status: "assigned",
        updated_at: new Date().toISOString(),
      })
      .eq("id", jobId);

    if (updateErr) {
      return new Response(
        JSON.stringify({ ok: false, error: updateErr.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    // 2. Log to admin_logs
    await supabase.from("admin_logs").insert({
      admin_user_id: adminUserId,
      admin_email: adminEmail,
      action: "manual_assign",
      job_id: jobId,
      driver_id: driverId,
      metadata: { pickup_address: booking.pickup_address },
    });

    // 3. Send FCM to driver (high-priority)
    const { data: driver } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", driverId)
      .single();

    const fcmToken = driver?.fcm_token;
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
    if (fcmToken && fcmServerKey) {
      await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify({
          to: fcmToken,
          priority: "high",
          notification: {
            title: "İş atandı",
            body: "Operatör tarafından size bir iş atandı. Uygulamayı açın.",
          },
          data: {
            type: "admin_assigned",
            booking_id: String(jobId),
          },
        }),
      });
    }

    return new Response(
      JSON.stringify({ ok: true, jobId, driverId }),
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
