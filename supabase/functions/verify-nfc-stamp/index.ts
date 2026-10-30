import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  hexToBytes,
  verifyPlainUidCounterSdm,
} from "../_shared/ntag424.js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "Method not allowed" });

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json(401, { error: "Giriş yapmalısın." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const keyMapRaw = Deno.env.get("NFC_SDM_KEYS_JSON");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !keyMapRaw) {
    return json(503, { error: "NFC doğrulama servisi henüz yapılandırılmadı." });
  }

  let keyMap: Record<string, string>;
  try {
    keyMap = JSON.parse(keyMapRaw);
  } catch {
    return json(503, { error: "NFC anahtar yapılandırması okunamadı." });
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user) return json(401, { error: "Oturum doğrulanamadı." });

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("role,approval_status")
    .eq("id", authData.user.id)
    .maybeSingle();
  if (profileError || profile?.role !== "customer" || profile?.approval_status !== "approved") {
    return json(403, { error: "Bu işlem için onaylı müşteri hesabı gerekli." });
  }

  let payload: { url?: string };
  try {
    payload = await request.json();
  } catch {
    return json(400, { error: "NFC verisi okunamadı." });
  }
  if (typeof payload.url !== "string" || payload.url.length > 2048) {
    return json(400, { error: "Geçersiz NFC bağlantısı." });
  }

  let url: URL;
  try {
    url = new URL(payload.url);
  } catch {
    return json(400, { error: "NFC etiketi geçerli bir bağlantı döndürmedi." });
  }

  const uid = (url.searchParams.get("uid") ?? "").toUpperCase();
  const counterHex = (url.searchParams.get("ctr") ?? url.searchParams.get("counter") ?? "").toUpperCase();
  const cmac = (url.searchParams.get("cmac") ?? url.searchParams.get("c") ?? "").toUpperCase();
  if (!/^[0-9A-F]{14}$/.test(uid) || !/^[0-9A-F]{6}$/.test(counterHex) || !/^[0-9A-F]{16}$/.test(cmac)) {
    return json(400, { error: "NFC etiketi beklenen güvenli veri biçiminde değil." });
  }

  const { data: tag, error: tagError } = await admin
    .from("nfc_tags")
    .select("id,business_id,branch_id,tag_uid,secret_reference,status")
    .eq("tag_uid", uid)
    .eq("status", "active")
    .maybeSingle();
  if (tagError || !tag) return json(404, { error: "Bu NFC etiketi Cafe Dünyam'da kayıtlı veya aktif değil." });

  const keyHex = keyMap[tag.secret_reference] ?? keyMap[uid];
  if (typeof keyHex !== "string" || !/^[0-9a-fA-F]{32}$/.test(keyHex)) {
    return json(503, { error: "Bu NFC etiketi için sunucu anahtarı tanımlanmamış." });
  }

  let isValid = false;
  try {
    isValid = await verifyPlainUidCounterSdm({
      key: hexToBytes(keyHex),
      uidHex: uid,
      counterHex,
      cmacHex: cmac,
    });
  } catch {
    return json(400, { error: "NFC güvenlik verisi doğrulanamadı." });
  }
  if (!isValid) return json(401, { error: "NFC etiketi doğrulanamadı." });

  const readCounter = Number.parseInt(counterHex, 16);
  let branchId = tag.branch_id as string | null;
  if (!branchId) {
    const { data: branch, error: branchError } = await admin
      .from("cafes")
      .select("id")
      .eq("business_id", tag.business_id)
      .eq("is_active", true)
      .order("is_main_branch", { ascending: false })
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();
    if (branchError || !branch) return json(409, { error: "İşletmenin etkin bir şubesi bulunamadı." });
    branchId = branch.id;
  }

  const receiptReference = `${uid}:${counterHex}`;
  const { data: stampData, error: stampError } = await admin.rpc("issue_verified_stamp", {
    p_customer_id: authData.user.id,
    p_cafe_id: branchId,
    p_issued_by: tag.business_id,
    p_receipt_reference: receiptReference,
    p_nfc_tag_id: tag.id,
    p_verification_reference: `sdm:${uid}:${counterHex}`,
    p_read_counter: readCounter,
  });

  if (stampError) {
    if (stampError.message.toLowerCase().includes("replay")) {
      return json(409, { error: "Bu NFC okutması daha önce kullanılmış." });
    }
    return json(400, { error: "Damga işlemi tamamlanamadı. Lütfen kasiyerden yardım iste." });
  }

  const result = Array.isArray(stampData) ? stampData[0] : stampData;
  if (!result) return json(500, { error: "Damga sonucu alınamadı." });
  if (result.duplicate_blocked) {
    return json(429, {
      duplicate: true,
      stamps: result.new_stamp_count,
      error: "Aynı işletmede 10 dakika dolmadan tekrar damga alamazsın.",
    });
  }

  return json(200, {
    success: true,
    duplicate: false,
    stamps: result.new_stamp_count,
    message: "Damgan başarıyla eklendi.",
  });
});
