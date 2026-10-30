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
  if (!url || !anon || !service) return reply(503, { error: "Çalışan doğrulama servisi yapılandırılmadı." });

  const auth = createClient(url, anon, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await auth.auth.getUser();
  if (authError || !authData.user) return reply(401, { error: "Oturum doğrulanamadı." });

  let body: { email?: string };
  try { body = await request.json(); } catch { return reply(400, { error: "Geçersiz istek." }); }
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply(400, { error: "Geçerli çalışan e-postası gir." });

  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: owner, error: ownerError } = await admin.from("profiles")
    .select("role,approval_status").eq("id", authData.user.id).maybeSingle();
  if (ownerError || owner?.role !== "business" || owner?.approval_status !== "approved") {
    return reply(403, { error: "Yalnızca onaylı işletme sahibi çalışan ekleyebilir." });
  }

  const { data: employee, error: employeeError } = await admin.from("profiles")
    .select("id,full_name,role,approval_status").ilike("email", email).maybeSingle();
  if (employeeError || !employee || employee.role !== "customer" || employee.approval_status !== "approved") {
    return reply(404, { error: "Bu e-postayla kayıtlı onaylı müşteri hesabı bulunamadı. Çalışan önce Cafe Dünyam'a kayıt olmalı." });
  }
  const { data: existing } = await admin.from("business_employees")
    .select("id").eq("business_id", authData.user.id).eq("employee_id", employee.id).maybeSingle();
  if (existing) return reply(409, { error: "Bu kullanıcı zaten işletme çalışanı." });

  return reply(200, { success: true, employeeId: employee.id, displayName: employee.full_name || email });
});
