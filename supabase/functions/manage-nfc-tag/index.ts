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
  if (!url || !anon || !service) return reply(503, { error: "NFC yönetim servisi yapılandırılmadı." });

  const auth = createClient(url, anon, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await auth.auth.getUser();
  if (authError || !authData.user) return reply(401, { error: "Oturum doğrulanamadı." });

  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await admin.from("profiles")
    .select("role,approval_status").eq("id", authData.user.id).maybeSingle();
  if (profileError || profile?.role !== "admin" || profile?.approval_status !== "approved") {
    return reply(403, { error: "Bu işlem yalnızca sistem yöneticisine açıktır." });
  }

  let body: { action?: string; businessId?: string; branchId?: string; tagUid?: string; secretReference?: string; tagId?: string };
  try { body = await request.json(); } catch { return reply(400, { error: "Geçersiz istek." }); }

  if (body.action === "revoke") {
    if (typeof body.tagId !== "string" || !/^[0-9a-fA-F-]{36}$/.test(body.tagId)) return reply(400, { error: "Geçersiz NFC etiketi." });
    const { error } = await admin.from("nfc_tags").update({ status: "revoked" }).eq("id", body.tagId);
    if (error) return reply(400, { error: "NFC etiketi iptal edilemedi." });
    return reply(200, { success: true, message: "NFC etiketi iptal edildi." });
  }

  const businessId = body.businessId ?? "";
  const branchId = body.branchId ?? "";
  const tagUid = (body.tagUid ?? "").trim().toUpperCase();
  const secretReference = (body.secretReference ?? "").trim();
  if (!/^[0-9a-fA-F-]{36}$/.test(businessId) || !/^[0-9a-fA-F-]{36}$/.test(branchId)) {
    return reply(400, { error: "İşletme ve şube seçmelisin." });
  }
  if (!/^[0-9A-F]{14}$/.test(tagUid) || !/^[A-Za-z0-9_-]{3,80}$/.test(secretReference)) {
    return reply(400, { error: "7-byte NFC UID ve geçerli anahtar referansı gir." });
  }

  let keyMap: Record<string,string>;
  try { keyMap = JSON.parse(Deno.env.get("NFC_SDM_KEYS_JSON") ?? "{}"); }
  catch { return reply(503, { error: "NFC anahtar haritası okunamadı." }); }
  if (typeof keyMap[secretReference] !== "string" || !/^[0-9a-fA-F]{32}$/.test(keyMap[secretReference])) {
    return reply(409, { error: "Bu anahtar referansı için 16-byte AES anahtarı Edge Function Secrets içinde tanımlı değil." });
  }

  const { data: business, error: businessError } = await admin.from("profiles")
    .select("id,role,approval_status").eq("id", businessId).maybeSingle();
  if (businessError || business?.role !== "business" || business?.approval_status !== "approved") {
    return reply(404, { error: "Onaylı işletme bulunamadı." });
  }
  const { data: branch, error: branchError } = await admin.from("cafes")
    .select("id").eq("id", branchId).eq("business_id", businessId).eq("is_active", true).maybeSingle();
  if (branchError || !branch) return reply(404, { error: "Seçilen etkin şube bu işletmeye ait değil." });

  const { data: existing, error: existingError } = await admin.from("nfc_tags")
    .select("id,tag_uid").eq("business_id", businessId).maybeSingle();
  if (existingError) return reply(400, { error: "Mevcut NFC kaydı okunamadı." });

  const values = {
    business_id: businessId,
    branch_id: branchId,
    tag_uid: tagUid,
    secret_reference: secretReference,
    status: "active",
    provisioned_at: new Date().toISOString(),
    ...(existing && existing.tag_uid !== tagUid ? { last_read_counter: -1 } : {}),
  };
  const query = existing
    ? admin.from("nfc_tags").update(values).eq("id", existing.id)
    : admin.from("nfc_tags").insert(values);
  const { error: saveError } = await query;
  if (saveError) return reply(409, { error: "NFC etiketi kaydedilemedi. UID başka bir işletmeye atanmış olabilir." });
  return reply(200, { success: true, message: "NFC etiketi işletmeye bağlandı ve etkinleştirildi." });
});
