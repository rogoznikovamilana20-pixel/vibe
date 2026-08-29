// translate — Edge Function (Deno) — прокси к провайдеру перевода
// body: {text: string, target_lang: string, source_lang?: string}
// кэш на клиенте (Hive), здесь — без кэша, прямой прокси
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, {headers: {"Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"}});
  try {
    const { text, target_lang = "en", source_lang } = await req.json();
    if (!text) return new Response(JSON.stringify({error: "no text"}), {status: 400, headers: {"Content-Type": "application/json"}});
    // TODO: заменить на реальный провайдер (LibreTranslate / DeepL / Google)
    // Пример: const r = await fetch("https://libretranslate.com/translate", {method:"POST", headers:{"Content-Type":"application/json"}, body: JSON.stringify({q: text, source: source_lang ?? "auto", target: target_lang, format: "text"})});
    // const j = await r.json(); return j.translatedText
    // Mock: просто префикс для теста E2E (чтобы не требовать ключ)
    const translated = `[${target_lang.toUpperCase()}] ${text}`;
    return new Response(JSON.stringify({translated, source_lang: source_lang ?? "auto"}), {headers: {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"}});
  } catch (e) {
    return new Response(JSON.stringify({error: String(e)}), {status: 500});
  }
});
