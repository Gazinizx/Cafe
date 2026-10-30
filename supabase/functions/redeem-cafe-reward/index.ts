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

  let body: { claimId?: string };
  try { body = await request.json(); } catch { return reply(400, { error: "Geçersiz istek." }); }
  if (typeof body.claimId !== "string" || !/^[0-9a-fA-F-]{36}$/.test(body.claimId)) return reply(400, { error: "Geçersiz ödül kodu." });

  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await admin.from("profiles").select("role,approval_status").eq("id", authData.user.id).maybeSingle();
  if (profileError || !profile) return reply(403, { error: "İşletme hesabı bulunamadı." });

  if (profile.role !== "business") {
    const { data: membership, error: membershipError } = await admin
      .from("business_employees").select("id").eq("employee_id", authData.user.id).eq("is_active", true).limit(1).maybeSingle();
    if (membershipError || !membership) return reply(403, { error: "Ödül teslimini yalnızca işletme sahibi veya yetkili çalışan yapabilir." });
  } else if (profile.approval_status !== "approved") {
    return reply(403, { error: "İşletme hesabı henüz onaylanmadı." });
  }

  const { data, error } = await admin.rpc("redeem_cafe_reward", {
    p_claim_id: body.claimId,
    p_redeemed_by: authData.user.id,
  });
  if (error) {
    if (error.message.toLowerCase().includes("no longer available") || error.message.toLowerCase().includes("already redeemed")) {
      return reply(409, { error: "Bu ödül daha önce kullanılmış veya artık geçerli değil." });
    }
    return reply(403, { error: "Bu ödülü teslim etme yetkin yok veya kod geçersiz." });
  }
  return reply(200, { success: true, claimId: data, message: "Ödül teslim edildi olarak işaretlendi." });
});
