// Supabase Edge Function: send-call-invite
// Sends push notification about incoming call to chat members.
//
// Request body:
//   chat_id   — UUID of the chat
//   call_id   — unique call identifier (same as chat_id or generated)
//   caller_id — UUID of the caller
//   caller_name — display name of the caller
//   call_type — "voice" | "video"

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Firebase Admin SDK helper
async function getAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (o: object) =>
    btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const toSign = `${enc(header)}.${enc(payload)}`;

  // Import private key
  const pem = sa.private_key;
  const binaryDer = Uint8Array.from(
    pem.replace(/-----.*?-----/g, "").replace(/\s/g, ""),
    (c) => c.charCodeAt(0)
  );

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(toSign));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${toSign}.${sigB64}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { chat_id, call_id, caller_id, caller_name, call_type } = await req.json();

    if (!chat_id || !caller_id || !call_id) {
      return new Response(
        JSON.stringify({ error: "chat_id, call_id, and caller_id are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Authenticate
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    // User-scoped client (enforces RLS)
    const userSupabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    );

    // Service-role client (admin operations only)
    const serviceSupabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Verify authenticated user
    const { data: { user }, error: authError } = await userSupabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify caller_id matches authenticated user
    if (caller_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "caller_id must match authenticated user" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get chat members (using user client to enforce RLS)
    const { data: chat } = await userSupabase
      .from("chats")
      .select("members")
      .eq("id", chat_id)
      .single();

    if (!chat) {
      return new Response(
        JSON.stringify({ error: "Chat not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify caller is a member of the chat
    const allMembers = chat.members as string[];
    if (!allMembers.includes(user.id)) {
      return new Response(
        JSON.stringify({ error: "Not a chat member" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const members = allMembers.filter((id) => id !== caller_id);
    if (members.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, sent: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get FCM tokens for recipients
    const { data: profiles } = await userSupabase
      .from("profiles")
      .select("id, fcm_token")
      .in("id", members);

    const tokens = (profiles ?? [])
      .map((p) => p.fcm_token)
      .filter((t) => t && t.length > 0) as string[];

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, sent: 0, total: members.length }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Send FCM push
    const serviceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
    if (!serviceAccount) {
      return new Response(
        JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const accessToken = await getAccessToken(serviceAccount);

    const results = await Promise.allSettled(
      tokens.map(async (token) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${JSON.parse(serviceAccount).project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                priority: "high",
                ttl: "30s",
                android: {
                  priority: "high",
                  ttl: "30s",
                },
                data: {
                  type: "call",
                  chatId: chat_id,
                  callId: call_id,
                  callerId: caller_id,
                  callerName: caller_name ?? "Пользователь",
                  callType: call_type ?? "voice",
                },
              },
            }),
          }
        );

        const data = await res.json();
        if (data.error) {
          if (data.error.code === 404 || data.error.code === 400) {
            // Token invalid — clean up
            await serviceSupabase
              .from("profiles")
              .update({ fcm_token: null })
              .eq("fcm_token", token);
          }
          throw new Error(data.error.message);
        }
        return data;
      })
    );

    const sent = results.filter((r) => r.status === "fulfilled").length;
    const failed = results.filter((r) => r.status === "rejected").length;

    return new Response(
      JSON.stringify({ ok: true, sent, failed, total: tokens.length }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
