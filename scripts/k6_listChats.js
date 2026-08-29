import http from 'k6/http';
import { check, sleep } from 'k6';
export const options = { vus: 20, duration: '30s', thresholds: { http_req_duration: ['p(95)<500'], http_req_failed: ['rate<0.01'] } };
const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://rgdwfoicidnamejluxfx.supabase.co';
const ANON_KEY = __ENV.SUPABASE_ANON_KEY;
export default function () {
  // listChats via REST: GET /rest/v1/chats?select=*
  const res = http.get(`${SUPABASE_URL}/rest/v1/chats?select=id&limit=100`, { headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}` } });
  check(res, { '200': (r) => r.status === 200, 'p95 <500ms': (r) => r.timings.duration < 500 });
  sleep(0.5);
}
// Run: k6 run -e SUPABASE_URL=https://... -e SUPABASE_ANON_KEY=... scripts/k6_listChats.js
