# Cafe Dünyam — bulut kurulumu

Flutter uygulamasında Supabase Auth ve bulut veri erişimi eklendi. Kafeler, kampanyalar, işletme başvuruları, NFC siparişleri ve müşteri sadakat bakiyeleri için aşağıdaki SQL şemasının projeye uygulanmış olması gerekir. Şema uygulanmadan bulut özellikleri çalışmaz.

## 1. Supabase projesi
1. Daha önce oluşturduğun `phsmojbrbszobpyeeipc` projesini aç; yeni proje oluşturma.
2. SQL Editor'de `supabase/schema.sql` dosyasının tamamını çalıştır.
3. Project Settings → API bölümündeki Project URL ve publishable key'in uygulamadaki değerlerle eşleştiğini kontrol et. **service_role key'i mobil uygulamaya veya depoya koyma.**

## 2. Şemaları uygulama

Canlı veritabanı açıldıktan sonra migration'ları sırayla uygula:
1. `supabase/migrations/20261014000000_initial_schema.sql`
2. `supabase/migrations/20261030210000_production_foundation.sql`

İkinci migration mevcut kafeleri ilk şubeleri olarak korur; işletme çalışanları, tekil işletme NFC etiketi kaydı, ödül hedefleri, paketler, abonelik kayıtları ve nakit/havale tahsilat kayıtlarını ekler. Bu migration tek başına NFC kriptografik doğrulama servisini kurmaz. NTAG doğrulaması yapan güvenli Edge Function kurulup gerçek etiketle test edilmeden damga üretimini canlıya açma.

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
Bu depo Supabase CLI yapısına hazırlandı: `supabase/config.toml` ve `supabase/migrations/20261014000000_initial_schema.sql` eklendi. Depo kökünde `supabase/` klasörü bulunduğu için çalışma dizini `.` olmalı.

1. [Supabase Dashboard](https://supabase.com/dashboard) üzerinden kendi hesabınla giriş yap ve projeni oluştur.
2. Projede **Project Settings → Integrations → GitHub Integration → Authorize GitHub** yolunu aç.
3. GitHub yetkilendirmesinde **Authorize Supabase** de ve `Gazinizx/Cafe` deposunu seç.
4. Working directory alanına `.` yaz ve entegrasyonu etkinleştir.
5. GitHub entegrasyonu sayfasında mevcut projeye ait otomatik dağıtım seçeneklerini gözden geçir. İlk kez bağlarken canlı veritabanına değişiklik uygulamadan önce migration ve RLS politikalarını kontrol et.

GitHub yetkilendirmesi, Supabase projesi oluşturma ve hesap onayı kullanıcı hesabında yapılmalıdır; bunları senin adına dışarıdan tamamlayamam. Bu işlem için GitHub şifreni veya Supabase gizli anahtarlarını bana gönderme. Mobil uygulamaya yalnızca Project URL ve publishable/anon anahtarı girilir; `service_role` anahtarı kesinlikle paylaşılmaz.

## 6. Yayına çıkmadan önce
- SQL şemasının gerçekten uygulandığını ve yeni bir müşteri/işletme hesabıyla tabloların oluştuğunu doğrula.
- Gerçek satın alma doğrulaması olmadan sadakat damgası üretme; doğrudan istemci yazma izni verme.
- Admin işlemlerini yalnızca güvenilir sunucu tarafı yönetim aracıyla yap.
- Android gerçek cihaz, iOS gerçek cihaz, çevrimdışı durum, hesap kurtarma ve RLS testlerini tamamla.
- iOS için Apple imzalama ve App Store Connect erişimi gerekir.

Uygulama kodu bulut veri erişimini kullanır; ancak veritabanı şeması Supabase projesinde çalıştırılmadan ve gerçek Android/iOS cihazlarda uçtan uca test edilmeden sistemin tamamen hazır olduğu söylenemez. NFC damgası verme bilerek istemciye açılmamıştır; gerçek satın alma doğrulaması yapan güvenilir bir sunucu/Edge Function eklenmelidir.
