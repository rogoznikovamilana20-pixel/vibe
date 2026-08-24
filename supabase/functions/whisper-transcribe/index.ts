// Edge Function: whisper-transcribe
// Транскрибирует голосовое сообщение через OpenAI Whisper API.
// Env: OPENAI_API_KEY (sk-...), SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
//
// Request: { message_id: string, storage_path: string }
// - storage_path: путь в Supabase Storage (bucket "voice" или "messages")
// - message_id: uuid сообщения в public.messages
//
// Auth: Bearer JWT текущего пользователя, sender_id должен совпасть с auth.user.id

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const WHISPER_URL = "https://api.openai.com/v1/audio/transcriptions";
const MAX_BYTES = 25 * 1024 * 1024;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { message_id, storage_path } = await req.json();
    if (!message_id || !storage_path) {
      return new Response(
        JSON.stringify({ error: "message_id and storage_path required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
    if (!openaiKey) {
      return new Response(
        JSON.stringify({ error: "OPENAI_API_KEY not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Auth
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const serviceClient = createClient(supabaseUrl, serviceKey);

    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Проверить что сообщение принадлежит вызывающему
    const { data: msg, error: msgErr } = await serviceClient
      .from("messages")
      .select("id, sender_id, transcript_status")
      .eq("id", message_id)
      .single();

    if (msgErr || !msg) {
      return new Response(JSON.stringify({ error: "Message not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (msg.sender_id !== user.id) {
      return new Response(JSON.stringify({ error: "Only sender can transcribe" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Уже готово — отдать кеш
    if (msg.transcript_status === "completed") {
      const { data: cached } = await serviceClient
        .from("messages")
        .select("transcript, transcript_language, transcript_status")
        .eq("id", message_id)
        .single();
      return new Response(JSON.stringify({ ok: true, cached: true, ...cached }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Пометить processing
    await serviceClient.from("messages").update({ transcript_status: "processing" }).eq("id", message_id);

    // Скачать аудио из Storage (bucket может быть voice / messages / avatars — пробуем по префиксу)
    // storage_path ожидается как "bucket/path/to/file.ogg" или "path/to/file.ogg" (bucket=voice по умолчанию)
    let bucket = "voice";
    let objectPath = storage_path;
    if (storage_path.includes("/")) {
      const parts = storage_path.split("/");
      // если первый сегмент — известный бакет
      if (["voice", "messages", "avatars", "media"].includes(parts[0])) {
        bucket = parts[0];
        objectPath = parts.slice(1).join("/");
      }
    }

    const { data: fileData, error: dlErr } = await serviceClient.storage
      .from(bucket)
      .download(objectPath);

    if (dlErr || !fileData) {
      await serviceClient.from("messages").update({ transcript_status: "failed" }).eq("id", message_id);
      return new Response(
        JSON.stringify({ error: "Failed to download audio", detail: String(dlErr) }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const bytes = new Uint8Array(await fileData.arrayBuffer());
    if (bytes.length > MAX_BYTES) {
      await serviceClient.from("messages").update({ transcript_status: "failed" }).eq("id", message_id);
      return new Response(JSON.stringify({ error: "Audio too large (>25MB)" }), {
        status: 413,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Отправить в Whisper
    const form = new FormData();
    const blob = new Blob([bytes], { type: "audio/ogg" });
    // Whisper принимает ogg/opus, mp3, m4a, wav и т.д.
    const ext = objectPath.split(".").pop() ?? "ogg";
    form.append("file", blob, `audio.${ext}`);
    form.append("model", "whisper-1");
    // Автоязык — Whisper сам определит; язык вернётся в ответе
    form.append("response_format", "verbose_json");

    const whisperRes = await fetch(WHISPER_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${openaiKey}` },
      body: form,
    });

    if (!whisperRes.ok) {
      const errText = await whisperRes.text();
      await serviceClient.from("messages").update({ transcript_status: "failed" }).eq("id", message_id);
      return new Response(
        JSON.stringify({ error: "Whisper API error", detail: errText }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const whisperData = await whisperRes.json();
    const transcript: string = whisperData.text ?? "";
    const language: string = whisperData.language ?? "";

    await serviceClient.from("messages").update({
      transcript,
      transcript_language: language || null,
      transcript_status: "completed",
    }).eq("id", message_id);

    return new Response(
      JSON.stringify({ ok: true, transcript, language, status: "completed" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
