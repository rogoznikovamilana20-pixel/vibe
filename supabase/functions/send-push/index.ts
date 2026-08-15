import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedToken: string | null = null;
let tokenExpiresAt = 0;

function base64url(data: ArrayBuffer): string {
  const bytes = new Uint8Array(data);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

async function getFirebaseToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && Date.now() < tokenExpiresAt) return cachedToken;

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const headerB64 = base64url(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64url(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(signingInput)
  );

  const jwt = `${signingInput}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firebase token error: ${res.status} ${err}`);
  }

  const data = await res.json();
  cachedToken = data.access_token;
  tokenExpiresAt = Date.now() + (data.expires_in - 60) * 1000;
  return cachedToken!;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { chat_id, sender_id, sender_name, text, message_id } =
      await req.json();

    if (!chat_id || !sender_id) {
      return new Response(JSON.stringify({ error: "missing fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // JWT verification — caller must be authenticated.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "no auth" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify caller is a member of the chat.
    const { data: chat } = await supabaseAdmin
      .from("chats")
      .select("members")
      .eq("id", chat_id)
      .single();

    if (!chat?.members || !(chat.members as string[]).includes(user.id)) {
      return new Response(JSON.stringify({ error: "not a chat member" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const saB64 = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
    const saJson = new TextDecoder().decode(
      Uint8Array.from(atob(saB64), (c) => c.charCodeAt(0))
    );
    const sa: ServiceAccount = JSON.parse(saJson);

    const supabase = supabaseAdmin;

    // 1. Get chat members.
    const { data: chat } = await supabase
      .from("chats")
      .select("members")
      .eq("id", chat_id)
      .single();

    if (!chat?.members) {
      return new Response(JSON.stringify({ error: "chat not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const recipients: string[] = (chat.members as string[]).filter(
      (m: string) => m !== sender_id
    );

    if (recipients.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Get FCM tokens.
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, fcm_token")
      .in("id", recipients);

    const tokens: { id: string; token: string }[] = (profiles ?? [])
      .map((p: any) => ({ id: p.id, token: p.fcm_token }))
      .filter((t) => !!t.token);

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, sent: 0, reason: "no tokens" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 3. Get Firebase access token.
    const fbToken = await getFirebaseToken(sa);

    // 4. Send FCM to all recipients (parallel).
    const title = sender_name || "Vibe";
    const preview =
      typeof text === "string" && text.length > 100
        ? text.substring(0, 100) + "..."
        : text || "Новое сообщение";

    const fcmData: Record<string, string> = {
      type: "chat",
      chatId: chat_id,
      senderId: sender_id,
      messageId: String(message_id ?? ""),
    };

    const projectId = sa.project_id;
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const results = await Promise.allSettled(
      tokens.map(async (t) => {
        const res = await fetch(url, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${fbToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: t.token,
              priority: "high",
              ttl: "0s",
              android: { priority: "high", ttl: "0s" },
              notification: { title, body: preview },
              data: fcmData,
            },
          }),
        });
        if (!res.ok) {
          const err = await res.text();
          return { ok: false, error: `${res.status}: ${err}` };
        }
        return { ok: true };
      })
    );

    const sent = results.filter(
      (r) => r.status === "fulfilled" && r.value.ok
    ).length;
    const failed = results.length - sent;

    // 5. Clean up invalid tokens.
    for (let i = 0; i < results.length; i++) {
      const r = results[i];
      if (r.status === "fulfilled" && !r.value.ok) {
        const err = (r.value as any).error ?? "";
        if (err.includes("NOT_FOUND") || err.includes("INVALID_ARGUMENT")) {
          await supabase
            .from("profiles")
            .update({ fcm_token: null })
            .eq("id", tokens[i].id);
        }
      }
    }

    return new Response(
      JSON.stringify({ ok: true, sent, failed, total: tokens.length }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
