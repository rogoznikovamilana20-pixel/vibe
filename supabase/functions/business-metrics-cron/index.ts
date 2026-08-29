// Cron: business-metrics-cron — ежесуточный rollup business_metrics_daily
// Расписание: supabase functions deploy business-metrics-cron --project-ref rgdwfoicidnamejluxfx && supabase cron create ...
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (_req) => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: businesses } = await supabase.from("businesses").select("id").limit(100);
  const today = new Date().toISOString().slice(0,10);
  for (const b of businesses ?? []) {
    await supabase.from("business_metrics_daily").upsert({business_id: b.id, date: today, views: 0, clicks: 0, orders: 0, revenue: 0, unique_chats: 0}, {onConflict: "business_id,date", ignoreDuplicates: false});
  }
  return new Response(JSON.stringify({ok: true, count: businesses?.length ?? 0}));
});
