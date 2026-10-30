# Cafe Dünyam — bulut kurulumu

Flutter uygulamasında Supabase Auth ve bulut veri erişimi eklendi. Kafeler, kampanyalar, işletme başvuruları, NFC siparişleri ve müşteri sadakat bakiyeleri için aşağıdaki SQL şemasının projeye uygulanmış olması gerekir. Şema uygulanmadan bulut özellikleri çalışmaz.

## 1. Supabase projesi
1. Daha önce oluşturduğun `phsmojbrbszobpyeeipc` projesini aç; yeni proje oluşturma.
2. Proje URL ve publishable key bilgilerini not et. Şema uygulamasını aşağıdaki 2. bölümdeki migration sırasına göre yap.
3. Project Settings → API bölümündeki Project URL ve publishable key'in uygulamadaki değerlerle eşleştiğini kontrol et. **service_role key'i mobil uygulamaya veya depoya koyma.**

Not: Bu proje `eu-west-3` (Paris) bölgesindedir. Supabase'in yayımladığı güncel bölgeler listesinde Türkiye bölgesi bulunmuyor; bu yüzden mevcut veritabanını korudum ve veritabanı işlemi yapan Edge Function çağrılarını aynı bölgeye yönlendirdim.

## 2. Şemaları uygulama

Önemli: Mevcut `phsmojbrbszobpyeeipc` Cafe Dünyam projesinde migration'lar zaten uygulanmıştır. Supabase migration geçmişinde 19 kayıt bulunuyor; 15 adet `public` tablonun tamamı mevcut ve RLS etkin. **Bu mevcut projede aşağıdaki SQL dosyalarını yeniden çalıştırma.** Aşağıdaki liste depodaki kaynak dosyaların sırasını gösterir. Canlı veritabanındaki ilk üç tarihli bootstrap kaydı (`cafe_dunyam_initial_schema`, `restrict_internal_function_execution`, `restore_policy_helper_permissions`) depodaki migration dosyalarıyla birebir aynı dosya adlarına sahip değildir; bu nedenle bu liste tek başına yeni bir Supabase projesini sıfırdan kurmak için kullanılmamalıdır. Yeni proje kurulumu gerekirse önce bu tarihsel bootstrap SQL'leri de kaynak koda eklenip temiz kurulum testi yapılmalıdır.
1. `supabase/migrations/20261014000000_initial_schema.sql`
2. `supabase/migrations/20261030210000_production_foundation.sql`
3. `supabase/migrations/20261030214000_security_hardening.sql`
4. `supabase/migrations/20261030220000_rls_policy_fixups.sql`
5. `supabase/migrations/20261030223000_nfc_counter_replay_protection.sql`
6. `supabase/migrations/20261030224000_reward_redemption.sql`
7. `supabase/migrations/20261030225000_private_access_helper.sql`
8. `supabase/migrations/20261030230000_manual_package_billing.sql`
9. `supabase/migrations/20261030232000_business_limits.sql`
10. `supabase/migrations/20261030233000_business_limits_fix.sql`
11. `supabase/migrations/20261030234000_business_uniqueness.sql`
12. `supabase/migrations/20261030235000_nfc_branch_metadata_access.sql`
13. `supabase/migrations/20261030240000_main_branch_default.sql`
14. `supabase/migrations/20261030241000_private_admin_authorization.sql`
15. `supabase/migrations/20261030242000_rls_auth_uid_cache.sql`
16. `supabase/migrations/20261030243000_rls_policy_consolidation.sql`
17. `supabase/migrations/20261030244000_single_tag_delivery_order.sql`

İkinci migration mevcut kafeleri ilk şubeleri olarak korur; işletme çalışanları, tekil işletme NFC etiketi kaydı, ödül hedefleri, paketler, abonelik kayıtları ve nakit/havale tahsilat kayıtlarını ekler. Üçüncü ve dördüncü migration'lar RLS yetkilerini daraltır, şube/çalışan erişimini düzeltir ve indeksleri ekler. Sonraki migration'lar NFC sayaç tekrar korumasını, ödül teslimini, özel erişim yardımcısını, nakit/havale abonelik tahsilatını ve paket şube/çalışan limitlerini ekler. NTAG doğrulaması yapan `verify-nfc-stamp` Edge Function dağıtıldı ve JWT zorunlu. Gerçek etiketle test etmeden damga üretimini canlıya açma.

Ödeme sağlayıcısı şu aşamada entegre edilmeyecek. İşletmelerden nakit veya banka havalesi alınabilir; tahsilat, yalnızca yönetici tarafından doğrulandıktan sonra onaylanmalıdır. Müşteri/işletme istemcisi kendi ödeme kaydını "ödendi" durumuna getirememelidir.

## 3. Yönetici hesabını hazırlama
1. Uygulamada yönetici olarak kullanacağın e-posta ile normal bir hesap oluştur.
2. Supabase SQL Editor'de aşağıdaki sorguda e-posta adresini kendi yönetici hesabınla değiştirip çalıştır:
```sql
update public.profiles
set role = 'admin', approval_status = 'approved'
where email = 'yonetici@ornek.com';
```
3. Uygulamada bu e-posta ve şifreyle giriş yap. `admin@cafedunyam.local` / `CafeAdmin123!` yalnızca cihaz içi demo hesabıdır; bulut yönetim hesabı değildir.

## 4. Flutter yapılandırması
Derleme sırasında aşağıdaki dart-define değerlerini kullan:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Örnek:
```sh
cd mobil
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```


## 5. GitHub bağlantısı (bir kez senin hesabından)
Bu depo Supabase CLI yapısına hazırlandı: `supabase/config.toml` ve `supabase/migrations/` klasörü mevcut. Depo kökünde `supabase/` klasörü bulunduğu için çalışma dizini `.` olmalı.

1. [Supabase Dashboard](https://supabase.com/dashboard) üzerinden kendi hesabınla giriş yap ve mevcut Cafe Dünyam projesini aç.
2. Projede **Project Settings → Integrations → GitHub Integration → Authorize GitHub** yolunu aç.
3. GitHub yetkilendirmesinde **Authorize Supabase** de ve `Gazinizx/Cafe` deposunu seç.
4. Working directory alanına `.` yaz ve entegrasyonu etkinleştir.
5. GitHub entegrasyonu sayfasında mevcut projeye ait otomatik dağıtım seçeneklerini gözden geçir. İlk kez bağlarken canlı veritabanına değişiklik uygulamadan önce migration ve RLS politikalarını kontrol et.

GitHub yetkilendirmesi, Supabase projesi oluşturma ve hesap onayı kullanıcı hesabında yapılmalıdır; bunları senin adına dışarıdan tamamlayamam. Bu işlem için GitHub şifreni veya Supabase gizli anahtarlarını bana gönderme. Mobil uygulamaya yalnızca Project URL ve publishable/anon anahtarı girilir; `service_role` anahtarı kesinlikle paylaşılmaz.

## Web yönetim paneli
`yonetim/index.html` artık yerel tarayıcı hafızası yerine Supabase Auth ve RLS ile çalışır. Yönetici hesabıyla giriş yapıldığında işletme başvuruları, paketler, nakit/havale tahsilatları, NFC etiketleri ve kampanyalar yönetilebilir. Statik dosya olarak GitHub Pages veya başka bir statik barındırma hizmetine yayınlanabilir.

## 6. Yayına çıkmadan önce
- SQL şemasının gerçekten uygulandığını ve yeni bir müşteri/işletme hesabıyla tabloların oluştuğunu doğrula.
- Gerçek NTAG 424 DNA etiketi, AES anahtarı ve Edge Function secret ayarlanmadan NFC damgası üretme; doğrudan istemci yazma izni verme.
- Yönetim işlemlerini yalnızca `admin` rolüne sahip hesapla yap; kullanıcı rolü istemci metadata'sından alınmaz.
- Android gerçek cihaz, iOS gerçek cihaz, çevrimdışı durum, hesap kurtarma ve RLS testlerini tamamla.
- iOS için Apple imzalama ve App Store Connect erişimi gerekir.

Uygulama kodu ve sunucu uç noktaları bulut veri erişimini kullanır; ancak gerçek Android/iOS cihazlarda, fiziksel NTAG 424 DNA etiketiyle ve Apple imzalı iOS derlemesiyle uçtan uca test edilmeden sistemin tamamen hazır olduğu söylenemez.


## NFC etiketi ve ödül güvenli kurulumu

- Edge Function'lar: `verify-nfc-stamp`, `claim-cafe-reward`, `redeem-cafe-reward`, `find-business-employee`, `manage-nfc-tag`, `admin-delete-user`.
- NFC doğrulama kodu: `supabase/functions/verify-nfc-stamp/index.ts`
- Kriptografi: `supabase/functions/_shared/ntag424.js`
- Testler: `supabase/functions/_shared/ntag424_test.ts`
- Sunucu anahtarları istemciye veya GitHub deposuna konulmaz. Supabase Edge Function Secrets alanında `NFC_SDM_KEYS_JSON` tanımla. JSON anahtarları, veritabanındaki `nfc_tags.secret_reference` değerleriyle eşleşmelidir; değerler 16 baytlık AES anahtarlarının 32 karakterlik hex karşılığıdır.
- NTAG 424 DNA, AES SDM modunda UID + sayaç + CMAC aynalama yapacak şekilde programlanmalıdır. URL parametreleri `uid`, `ctr` ve `c` olmalı; SDM MAC input başlangıç ofseti ile CMAC ofseti aynı ayarlanmalıdır. Sunucu sayaç değerini veritabanında saklar ve eski sayaçları reddeder.
- Etiket kaydı yalnızca sunucu tarafında yapılır. Her işletme için tek satır `nfc_tags` kaydı oluştur; `tag_uid` büyük harfli 7-byte UID, `secret_reference` gizli anahtar haritasındaki anahtar adı, `branch_id` ise etiketi kullanacak etkin şubedir.
- Dağıtılmış Edge Function'lar: `verify-nfc-stamp`, `claim-cafe-reward`, `redeem-cafe-reward`, `find-business-employee`, `manage-nfc-tag`, `admin-delete-user`. Bunlar JWT doğrulaması ister.
- Sunucu anahtarını ayarlama örneği: `supabase secrets set NFC_SDM_KEYS_JSON='{"<secret_reference>":"<32_HEX_AES_KEY>"}'`
- Etiket gerçek cihazda okutulmadan, sayaç tekrar testi ve 10 dakika kuralı doğrulanmadan NFC özelliğini üretimde kullanıma açma.

Müşteri ödül talebi `claim-cafe-reward` Edge Function üzerinden oluşturulur; işletme sahibi veya yetkili çalışan `redeem-cafe-reward` üzerinden tek kullanımlık talebi teslim edildi olarak işaretler. İki uç nokta da JWT doğrulaması ister ve damga/ödül bakiyesini doğrudan istemciye yazdırmaz.
