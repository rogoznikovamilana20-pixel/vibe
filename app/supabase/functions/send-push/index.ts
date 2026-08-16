// Vibe — Edge Function: доставка FCM-пушей.
//
// Умеет принимать:
//   1) Запрос самого приложения: POST /send-push { recipientId, title, body, data? }
//   2) Payload pg_net/http-вебхука: { record: <строка из messages|stories> }
//      - messages: record.chat_id, sender_id, text | photo_url | voice_url, e2ee_version
//      - stories : record.profile_id, photo_url
//
// Деплой:  supabase functions deploy send-push
// Секрет:  supabase secrets set FIREBASE_SERVICE_ACCOUNT "<base64 service-account.json>"
// Вызов будет публичным (verify_jwt=false) — триггер pg_net и приложение шлют без токена.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { JWT } from "npm:google-auth-library@9.15.1";
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

type VibeRecord = {
  type: "chat" | "story";
  chat_id?: string;
  sender_id?: string;
  profile_id?: string;
  text?: string;
  photo_url?: string;
  voice_url?: string;
  e2ee_version?: number | null;
};

interface Payload {
  recipientId?: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
  record?: VibeRecord;
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const BRAND_COLOR = "#8B5CF6";
const SMALL_ICON = "ic_stat_vibe";

/**
 * Builds notification preview text.
 *
 * SECURITY: For E2EE V2 (e2ee_version >= 2), NEVER use `body` (plaintext).
 * V2 plaintext must never appear in push notifications, even if present
 * in the database due to a bug. This is fail-closed defense-in-depth.
 */
function previews(
  body: string | undefined,
  photo: string | undefined,
  voice: string | undefined,
  e2eeVersion?: number | null,
): string {
  // V2 fail-closed: never use plaintext for notification content
  if (e2eeVersion != null && e2eeVersion >= 2) {
    if (photo) return "[Фото]";
    if (voice) return "[Голосовое]";
    return "Новое сообщение";
  }

  // V1 / plaintext: existing behavior
  if (body && body.trim().length > 0) return body.trim().slice(0, 80);
  if (photo) return "[Фото]";
  if (voice) return "[Голосовое]";
  return "Новое сообщение";
}

function fcmMessage(
  token: string,
  title: string,
  body: string,
  channelId: "messages" | "stories",
  data: Record<string, string>,
  priority: "high" | "normal" = "high",
) {
  return {
    message: {
      token,
      notification: { title, body },
      data,
      android: {
        priority,
        notification: {
          channel_id: channelId,
          icon: SMALL_ICON,
          color: BRAND_COLOR,
          sound: channelId === "messages" ? "default" : undefined,
        },
      },
      apns: {
        payload: {
          aps: {
            "thread-id": data["chatId"] ?? data["type"] ?? "vibe",
          },
        },
      },
    },
  };
}

function decodeBase64(json: string): any {
  return JSON.parse(
    new TextDecoder().decode(Uint8Array.from(atob(json), (c) => c.charCodeAt(0))),
  );
}

async function accessToken(): Promise<string> {
  const b64 = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
  if (!b64) throw new Error("FIREBASE_SERVICE_ACCOUNT env is not set");
  const client = new JWT({
    email: decodeBase64(b64).client_email,
    key: decodeBase64(b64).private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const token = await client.getAccessToken();
  return token.token ?? "";
}

async function fcmProjectId(): Promise<string> {
  return decodeBase64(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "").project_id;
}

async function sendToToken(
  access: string,
  projectId: string,
  payload: ReturnType<typeof fcmMessage>,
): Promise<void> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    },
  );
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`FCM ${res.status}: ${text.slice(0, 300)}`);
  }
}

async function tokensOf(userIds: string[]): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  for (const id of userIds) {
    const { data: p } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", id)
      .maybeSingle();
    if (p?.fcm_token) map.set(id, p.fcm_token);
  }
  return map;
}

/** Получатели стори: те, кто состоит с автором в хотя бы одном общем чате. */
async function storyRecipients(profileId: string): Promise<string[]> {
  const { data: chats, error } = await supabase
    .from("chats")
    .select("members")
    .contains("members", [profileId]);
  if (error) throw new Error(`chats lookup: ${error.message}`);
  const ids = new Set<string>();
  for (const c of chats ?? []) {
    for (const m of (c.members ?? []) as string[]) {
      if (m !== profileId) ids.add(m);
    }
  }
  return [...ids];
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const raw = (await req.json()) as Payload;

    // ---- 1. Ручной вызов от приложения ----
    if (!raw.record) {
      const { recipientId, title, body, data } = raw;
      if (!recipientId || !title) {
        return new Response("recipientId и title обязательны", { status: 400 });
      }
      const token = (await tokensOf([recipientId])).get(recipientId);
      if (!token) return new Response("no token", { status: 200 });
      const access = await accessToken();
      await sendToToken(access, await fcmProjectId(),
        fcmMessage(token, title, body ?? "", "messages", data ?? {}, "high"));
      return new Response("sent", { status: 200 });
    }

    const rec = raw.record;

    // ---- 2. Новая стори ----
    if (rec.type === "story" && rec.profile_id) {
      const { data: author } = await supabase
        .from("profiles")
        .select("display_name, username")
        .eq("id", rec.profile_id)
        .maybeSingle();
      const name = author?.display_name || author?.username || "Кто-то";
      const title = "Новая стори";
      const body = `У ${name} появилась новая стори`;
      const recipients = await storyRecipients(rec.profile_id);
      const access = await accessToken();
      const project = await fcmProjectId();
      let sent = 0;
      for (const [, token] of await tokensOf(recipients)) {
        try {
          await sendToToken(access, project, fcmMessage(
            token, title, body, "stories",
            { type: "story", profileId: rec.profile_id }, "normal",
          ));
          sent++;
        } catch (_) { /* тихо */ }
      }
      return new Response(`sent ${sent}`, { status: 200 });
    }

    // ---- 3. Сообщение ----
    if (rec.type === "chat" && rec.chat_id) {
      const { data: chat, error } = await supabase
        .from("chats")
        .select("members")
        .eq("id", rec.chat_id)
        .maybeSingle();
      if (error) throw error;
      const members = (chat?.members ?? []) as string[];
      const recipientId = members.find((m) => m !== rec.sender_id);
      if (!recipientId) return new Response("no recipient", { status: 200 });

      const { data: sender } = await supabase
        .from("profiles")
        .select("display_name, username")
        .eq("id", rec.sender_id ?? "")
        .maybeSingle();
      const title = sender?.display_name || sender?.username || "Vibe";
      const body = previews(rec.text, rec.photo_url, rec.voice_url, rec.e2ee_version);

      const token = (await tokensOf([recipientId])).get(recipientId);
      if (!token) return new Response("no token", { status: 200 });
      const access = await accessToken();
      await sendToToken(access, await fcmProjectId(), fcmMessage(
        token, title, body, "messages",
        { type: "chat", chatId: rec.chat_id, senderId: rec.sender_id ?? "" }, "high",
      ));
      return new Response("sent", { status: 200 });
    }

    return new Response("unhandled record", { status: 400 });
  } catch (err) {
    return new Response(
      `internal error: ${err instanceof Error ? err.message : err}`,
      { status: 500 },
    );
  }
});