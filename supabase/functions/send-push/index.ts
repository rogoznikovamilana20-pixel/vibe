// Edge Function: send-push — прокси FCM, не логирует plaintext (F-048)
// Запускается клиентом: supabase.functions.invoke('send-push', {body: {chat_id, sender_id, sender_name, message_id}})
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const { chat_id, sender_id, sender_name } = await req.json().catch(() => ({}));
  if (!chat_id || !sender_id) return new Response(JSON.stringify({error: "missing"}), {status: 400});
  // TODO: picks FCM tokens via service_role from profile_fcm_tokens where user_id in chat members
  // const { data } = await supabase.from('profile_fcm_tokens').select('fcm_token').in('user_id', members)
  // for (t of data) await fetch('https://fcm.googleapis.com/v1/...', {headers: {Authorization: `Bearer ${Deno.env.get("FCM_SERVICE_ACCOUNT")}`}, body: JSON.stringify({message: {token: t.fcm_token, notification: {title: sender_name ?? "Vibe", body: "Новое сообщение"}, data: {chat_id, sender_id}}})})
  console.log(`send-push chat=${chat_id} sender=${sender_id} name=${sender_name} (no text)`);
  return new Response(JSON.stringify({ok: true}), {headers: {"Content-Type": "application/json"}});
});
