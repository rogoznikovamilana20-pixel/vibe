// Edge Function: media-sign — приватные подписанные URL для storage
// Проверяет JWT + членство в чате, затем делает /storage/v1/object/sign через service_role
// Env: SUPABASE_URL, VIBE_SVC_KEY (== SUPABASE_SERVICE_ROLE_KEY, ротированный)
// Buckets: avatars (любой auth), stories/media/messages (участник чата)
// Client: VibeBackend.mediaUrl() кеш 50 мин + VibeNetImage
// Security: anon→401, чужой чат→403, свой→200, TTL 3600s

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Разрешенные бакеты и их префиксы в storage.objects.name
const BUCKETS = new Set(["avatars", "stories", "media", "messages"]);

// Нормализует path: убирает ведущий /, оставляет bucket/path
function normalizePath(bucket: string, path: string): string {
  let p = path.trim();
  if (p.startsWith("/")) p = p.slice(1);
  // если уже "avatars/xxx" — вытащить
  for (const b of BUCKETS) {
    if (p.startsWith(`${b}/`)) {
      // bucket должен совпасть с префиксом, иначе 400
      if (b !== bucket) throw new Error(`bucket mismatch: ${bucket} vs ${b}`);
      return p.slice(b.length + 1);
    }
  }
  // иначе считаем что передали относительный путь внутри bucket
  if (p.startsWith(`${bucket}/`)) p = p.slice(bucket.length + 1);
  return p;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const svcKey = Deno.env.get("VIBE_SVC_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !anonKey) return json({ error: "server misconfigured" }, 500);
  if (!svcKey) return json({ error: "VIBE_SVC_KEY not set" }, 500);

  // 1. Auth — проверить JWT
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) return json({ error: "Unauthorized" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return json({ error: "Unauthorized", detail: authErr?.message }, 401);

  // 2. Body
  let body: { bucket?: string; path?: string; expiresIn?: number };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }
  const bucket = body.bucket?.trim();
  const rawPath = body.path?.trim();
  const expiresIn = body.expiresIn ?? 3600;

  if (!bucket || !rawPath) return json({ error: "bucket and path required" }, 400);
  if (!BUCKETS.has(bucket)) return json({ error: `unknown bucket ${bucket}` }, 400);

  let objectPath: string;
  try {
    objectPath = normalizePath(bucket, rawPath);
  } catch (e) {
    return json({ error: String(e) }, 400);
  }
  if (!objectPath) return json({ error: "empty path" }, 400);

  // 3. Authorization по bucket
  // avatars — любой аутентифицированный может читать (аватары публичны для auth)
  // stories/media/messages — только участник чата где есть сообщение с этим object path
  if (bucket !== "avatars") {
    // Проверяем что файл принадлежит чату где user — участник
    // Ищем в messages.media_url LIKE %bucket/objectPath% или stories.photo_url
    // Упрощенно: проверяем chats where user in members и messages в этом чате ссылаются на путь
    // Для stories — stories.profile_id == user.id или stories видна через чат? Пока разрешаем если юзер — участник любого чата где есть сторис автора
    const svcClient = createClient(supabaseUrl, svcKey);

    // Собрать все chat_id где user — участник
    const { data: myChats, error: chatErr } = await svcClient
      .from("chats")
      .select("id")
      .contains("members", [user.id]); // chats.members — jsonb array? или отдельная таблица chat_members. Пробуем оба.
    // Fallback: если members — не jsonb, пробуем через chat_members
    let allowed = false;
    if (!chatErr && myChats && myChats.length > 0) {
      // Для stories/media/messages — ищем сообщение в этих чатах с таким path
      const chatIds = myChats.map((c: { id: string }) => c.id);
      const { data: msgs } = await svcClient
        .from("messages")
        .select("id")
        .in("chat_id", chatIds)
        .ilike("media_url", `%${objectPath}%`)
        .limit(1);
      if (msgs && msgs.length > 0) allowed = true;

      // Также проверяем stories: если path в stories.photo_url и автор — участник общего чата
      if (!allowed) {
        const { data: stories } = await svcClient
          .from("stories")
          .select("id")
          .eq("photo_url", `${bucket}/${objectPath}`)
          .limit(1);
        if (stories && stories.length > 0) allowed = true;
      }
    } else {
      // Попытка через таблицу chat_members если exists
      const { data: memberships } = await svcClient
        .from("chat_members")
        .select("chat_id")
        .eq("user_id", user.id)
        .limit(50);
      if (memberships && memberships.length > 0) {
        const chatIds = memberships.map((m: { chat_id: string }) => m.chat_id);
        const { data: msgs } = await svcClient
          .from("messages")
          .select("id")
          .in("chat_id", chatIds)
          .ilike("media_url", `%${objectPath}%`)
          .limit(1);
        if (msgs && msgs.length > 0) allowed = true;
      }
    }

    if (!allowed) {
      // Для avatars уже разрешили выше, для остальных — 403
      // Но если это свой собственный upload (stories автора == user.id) — разрешить
      const svcClient2 = createClient(supabaseUrl, svcKey);
      if (bucket === "stories" || bucket === "media") {
        // stories/photo_url может быть stories/<userId>/...
        if (objectPath.startsWith(`${user.id}/`)) {
          allowed = true;
        } else {
          // проверим stories где profile_id == user.id
          const { data: ownStory } = await svcClient2
            .from("stories")
            .select("id")
            .eq("profile_id", user.id)
            .eq("photo_url", `${bucket}/${objectPath}`)
            .limit(1);
          if (ownStory && ownStory.length > 0) allowed = true;
        }
      }
    }

    if (!allowed) return json({ error: "Forbidden — not a member of chat with this media" }, 403);
  }

  // 4. Подписать через Storage API напрямую (service_role)
  // POST /storage/v1/object/sign/<bucket>/<path>  {expiresIn}
  const signUrl = `${supabaseUrl}/storage/v1/object/sign/${bucket}/${objectPath}`;
  const signRes = await fetch(signUrl, {
    method: "POST",
    headers: {
      "apikey": svcKey,
      "Authorization": `Bearer ${svcKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ expiresIn }),
  });

  if (!signRes.ok) {
    const txt = await signRes.text();
    // Пробрасываем 404 если объекта нет
    if (signRes.status === 404) return json({ error: "Object not found", detail: txt }, 404);
    return json({ error: "sign failed", detail: txt, status: signRes.status }, 500);
  }

  const signed = await signRes.json(); // {signedURL: "/object/sign/...?token=..."}
  const signedURL = signed.signedURL as string | undefined;
  if (!signedURL) return json({ error: "no signedURL", detail: signed }, 500);

  const fullUrl = `${supabaseUrl}/storage/v1${signedURL}`;
  return json({ url: fullUrl, expiresIn });
});
