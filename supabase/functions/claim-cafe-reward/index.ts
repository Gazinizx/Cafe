import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return reply(405, { error: "Method not allowed" });
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return reply(401, { error: "Giriş yapmalısın." });

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return reply(503, { error: "Ödül servisi yapılandırılmadı." });

  const auth = createClient(url, anon, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await auth.auth.getUser();
  if (authError || !authData.user) return reply(401, { error: "Oturum doğrulanamadı." });

  let body: { cafeId?: string };
  try { body = await request.json(); } catch { return reply(400, { error: "Geçersiz istek." }); }
  if (typeof body.cafeId !== "string" || !/^[0-9a-fA-F-]{36}$/.test(body.cafeId)) return reply(400, { error: "Geçersiz kafe." });

  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await admin.from("profiles").select("role,approval_status").eq("id", authData.user.id).maybeSingle();
  if (profileError || profile?.role !== "customer" || profile?.approval_status !== "approved") {
    return reply(403, { error: "Ödül talebi için onaylı müşteri hesabı gerekli." });
  }

  const { data, error } = await admin.rpc("claim_cafe_reward", {
    p_customer_id: authData.user.id,
    p_cafe_id: body.cafeId,
  });
  if (error) {
    const message = error.message.toLowerCase();
    if (message.includes("not enough stamps")) return reply(409, { error: "Ödül için yeterli damgan yok." });
    if (message.includes("no active reward")) return reply(409, { error: "Bu işletmede aktif ödül bulunmuyor." });
    return reply(400, { error: "Ödül talebi oluşturulamadı." });
  }
  return reply(200, { success: true, claimId: data, message: "Ödül talebin oluşturuldu. Kodu kasiyere göster." });
});
