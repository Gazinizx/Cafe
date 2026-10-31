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
  if (!url || !anon || !service) return reply(503, { error: "Yönetici servisi yapılandırılmadı." });

  const auth = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await auth.auth.getUser();
  if (authError || !authData.user) return reply(401, { error: "Oturum doğrulanamadı." });

  let body: { userId?: string };
  try { body = await request.json(); } catch { return reply(400, { error: "Geçersiz istek." }); }
  const targetId = body.userId ?? "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(targetId)
      || targetId === authData.user.id) {
    return reply(400, { error: "Geçersiz hedef kullanıcı." });
  }

  const admin = createClient(url, service, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: profile, error: profileError } = await admin.from("profiles")
    .select("role,approval_status").eq("id", authData.user.id).maybeSingle();
  if (profileError || profile?.role !== "admin" || profile?.approval_status !== "approved") {
    return reply(403, { error: "Bu işlem yalnızca sistem yöneticisine açıktır." });
  }

  const { error } = await admin.rpc("admin_delete_user", {
    p_target_id: targetId,
    p_actor_id: authData.user.id,
  });
  if (error) {
    console.error("Atomic admin user deletion failed:", error);
    return reply(400, { error: error.message || "Kullanıcı hesabı silinemedi." });
  }
  return reply(200, { success: true, message: "Kullanıcı hesabı ve ilişkili kayıtları silindi." });
});
