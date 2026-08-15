// Supabase Edge Function: send-otp
// Sends a 6-digit OTP code via SMS.
//
// Free SMS providers supported:
//   1. textbelt — 1 SMS/day free (key=textbelt), no signup
//   2. twilio — $15 trial credit (~1900 SMS), needs Account SID + Auth Token
//
// Environment variables:
//   SMS_PROVIDER  — "textbelt" | "twilio" | "console" (default: textbelt)
//   SMS_API_KEY   — Twilio Account SID (for twilio) or paid key (for textbelt)
//   SMS_API_SECRET — Twilio Auth Token (for twilio only)
//   SMS_FROM      — Twilio phone number (for twilio only)
//
// For development: SMS_PROVIDER=console just logs the code.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone } = await req.json();
    if (!phone) {
      return new Response(
        JSON.stringify({ error: "phone is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate 6-digit code
    const code = String(Math.floor(100000 + Math.random() * 900000));

    // Store in DB via service role
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    await supabase.from("phone_otps").insert({
      phone,
      code,
    });

    // Send SMS
    const provider = Deno.env.get("SMS_PROVIDER") ?? "textbelt";
    const msg = `Vibe: ${code} — код подтверждения`;

    if (provider === "console") {
      console.log(`[OTP] ${phone} → ${code}`);
    } else if (provider === "textbelt") {
      // Textbelt: 1 free SMS/day with key=textbelt
      const apiKey = Deno.env.get("SMS_API_KEY") ?? "textbelt";
      const res = await fetch("https://textbelt.com/text", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          phone: phone,
          message: msg,
          key: apiKey,
        }),
      });
      const data = await res.json();
      if (!data.success) {
        console.error(`[Textbelt] Failed: ${data.quotaRemaining ?? 0} SMS remaining`);
      }
    } else if (provider === "twilio") {
      const accountSid = Deno.env.get("SMS_API_KEY") ?? "";
      const authToken = Deno.env.get("SMS_API_SECRET") ?? "";
      const from = Deno.env.get("SMS_FROM") ?? "+1234567890";
      await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({
            To: phone,
            From: from,
            Body: msg,
          }),
        }
      );
    }

    return new Response(
      JSON.stringify({ ok: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
