// Vibe — Edge Function: подписанные URL для приватных медиа.
//
// Проверяет, имеет ли вызывающий (Bearer JWT) доступ к объекту:
//   avatars/<uid>.png                     — любой аутентифицированный
//   stories/<uid>/<файл>                  — участник взаимного pm-чата с автором
//   media/<chatId>/<type>_<uid>/<файл>    — участник чата <chatId>
// и возвращает подписанный URL (TTL 1 час).
//
// Деплой:  supabase functions deploy media-sign
// Вызов:   POST { bucket, path }  с Authorization: Bearer <access_token>
//
// Подпись делается прямым HTTP-запросом к Storage API (createSignedUrl из
// supabase-js дублирует префикс бакета в пути, из-за чего объект не находится).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const BUCKET = "avatars";
const TTL = 3600; // 1 час

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("VIBE_SVC_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

function uuid(s: string | undefined | null): string | null {
  if (!s) return null;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
    ? s.toLowerCase()
    : null;
}

async function canRead(userId: string, path: string): Promise<boolean> {
  const parts = path.split("/").filter(Boolean);
  const top = parts[0];
  if (!top) return false;

  if (top === "avatars") return true;

  if (top === "stories" && parts.length >= 2) {
    const authorId = uuid(parts[1]);
    if (!authorId || authorId === userId) return true;
    const { data, error } = await supabase
      .from("chats")
      .select("id")
      .eq("kind", "pm")
      .contains("members", [userId, authorId])
      .limit(1);
    if (error) return false;
    return (data?.length ?? 0) > 0;
  }

  if (top === "media" && parts.length >= 2) {
    const chatId = uuid(parts[1]);
    if (!chatId) return false;
    const { data: chat, error } = await supabase
      .from("chats")
      .select("members")
      .eq("id", chatId)
      .maybeSingle();
    if (error || !chat) return false;
    const members = (chat.members ?? []) as string[];
    return members.includes(userId);
  }

  return false;
}

async function signObject(bucket: string, path: string): Promise<string | { status: number; text: string }> {
  const url = `${Deno.env.get("SUPABASE_URL")}/storage/v1/object/sign/${bucket}/${path}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("VIBE_SVC_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ expiresIn: TTL }),
  });
  if (!res.ok) return { status: res.status, text: (await res.text()).slice(0, 200) };
  const data = await res.json() as { signedURL?: string };
  if (!data.signedURL) return { status: 200, text: "no signedURL in body" };
  return `${Deno.env.get("SUPABASE_URL")}/storage/v1${data.signedURL}`;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return new Response("missing token", { status: 401 });
    }

    const { data: { user }, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !user) {
      return new Response("invalid token", { status: 401 });
    }

    const { bucket, path } = await req.json().catch(() => ({}));
    const p: string = typeof path === "string" ? path.trim().replace(/^\/+/, "") : "";
    const b: string = typeof bucket === "string" ? bucket : BUCKET;
    if (!p || b !== BUCKET) {
      return new Response("invalid path or bucket", { status: 400 });
    }

    if (!(await canRead(user.id, p))) {
      return new Response("forbidden", { status: 403 });
    }

    const signed = await signObject(b, p);
    if (typeof signed !== "string") {
      return Response.json({ error: "sign failed", status: signed?.status, text: signed?.text }, { status: 500 });
    }

    return Response.json({ url: signed });
  } catch (err) {
    return new Response(
      `internal error: ${err instanceof Error ? err.message : err}`,
      { status: 500 },
    );
  }
});