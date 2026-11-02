import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "Method not allowed" });

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json(401, { error: "Giriş yapmalısın." });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json(503, { error: "QR damga servisi yapılandırılmadı." });

  const authClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user) return json(401, { error: "Oturum doğrulanamadı." });

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let payload: { action?: string; branchId?: string; token?: string; campaignId?: string };
  try {
    payload = await request.json();
  } catch {
    return json(400, { error: "İstek verisi okunamadı." });
  }

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("role,approval_status")
    .eq("id", authData.user.id)
    .maybeSingle();
  if (profileError || !profile || profile.approval_status !== "approved") {
    return json(403, { error: "Onaylı hesap gerekli." });
  }

  if (payload.action === "issue") {
    if (profile.role !== "business") return json(403, { error: "QR kodu yalnızca işletme hesabı oluşturabilir." });

    let branchQuery = admin.from("cafes")
      .select("id,business_id")
      .eq("business_id", authData.user.id)
      .eq("is_active", true);
    if (payload.branchId) branchQuery = branchQuery.eq("id", payload.branchId);
    const { data: branch, error: branchError } = await branchQuery
      .order("is_main_branch", { ascending: false })
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();
    if (branchError || !branch) return json(409, { error: "Aktif şube bulunamadı." });

    const token = randomToken();
    const tokenHash = await sha256Hex(token);
    const expiresAt = new Date(Date.now() + 90_000).toISOString();
    const { error: insertError } = await admin.from("campaign_qr_challenges").insert({
      token_hash: tokenHash,
      business_id: authData.user.id,
      branch_id: branch.id,
      issued_by: authData.user.id,
      expires_at: expiresAt,
    });
    if (insertError) return json(500, { error: "QR kodu üretilemedi." });

    // Remove old unused challenges without exposing token material to clients.
    await admin.from("campaign_qr_challenges")
      .delete()
      .lt("expires_at", new Date(Date.now() - 86_400_000).toISOString());

    return json(200, { success: true, token, expiresAt, branchId: branch.id });
  }

  if (payload.action === "redeem") {
    if (profile.role !== "customer") return json(403, { error: "QR damgası için müşteri hesabı gerekli." });
    if (typeof payload.token !== "string" || !/^[0-9a-f]{64}$/.test(payload.token)) {
      return json(400, { error: "Geçersiz QR kodu." });
    }
    if (typeof payload.campaignId !== "string" || !/^[0-9a-fA-F-]{36}$/.test(payload.campaignId)) {
      return json(400, { error: "Önce geçerli kampanya kartını seçmelisin." });
    }

    const tokenHash = await sha256Hex(payload.token);
    const { data, error } = await admin.rpc("issue_campaign_qr_stamp", {
      p_token_hash: tokenHash,
      p_campaign_id: payload.campaignId,
      p_customer_id: authData.user.id,
    });
    if (error) {
      const message = error.message.toLowerCase();
      if (message.includes("expired or already used")) return json(409, { error: "QR kodunun süresi dolmuş veya daha önce kullanılmış. İşletmeden yeni kod iste." });
      if (message.includes("has not joined")) return json(403, { error: "Önce bu kampanyayı Aktif Kampanyalarım alanına eklemelisin." });
      if (message.includes("different businesses")) return json(409, { error: "Bu QR kodu seçili kampanyanın işletmesine ait değil." });
      if (message.includes("not active")) return json(409, { error: "Seçili kampanya artık damga kabul etmiyor." });
      return json(400, { error: "QR damgası doğrulanamadı. İşletmeden yeni kod iste." });
    }
    const result = Array.isArray(data) ? data[0] : data;
    if (!result) return json(500, { error: "Damga sonucu alınamadı." });
    if (result.duplicate_blocked) {
      return json(200, {
        success: false,
        duplicate: true,
        stamps: result.new_stamp_count,
        message: "Bu kampanyada 10 dakika dolmadan tekrar damga alamazsın.",
      });
    }
    return json(200, {
      success: true,
      stamps: result.new_stamp_count,
      rewardReady: result.reward_ready === true,
      message: result.reward_ready === true
        ? "Kampanya kartın tamamlandı. Ödülünü talep edebilirsin."
        : "QR damgan başarıyla eklendi.",
    });
  }

  return json(400, { error: "Geçersiz QR işlem türü." });
});
