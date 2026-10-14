# Cafe Dünyam — bulut kurulumu

Uygulama şu anda yerel prototip davranışına sahip. Android ve iOS uygulamalarının aynı hesap ve verileri paylaşması için Supabase projesi gerekir; yalnızca APK derlemek senkronizasyon sağlamaz.

## 1. Supabase projesi
1. Supabase üzerinde yeni bir proje oluştur.
2. SQL Editor'de `supabase/schema.sql` dosyasının tamamını çalıştır.
3. Project Settings → API bölümünden Project URL ve publishable/anon client key değerlerini al.
4. Bu değerleri istemci yapılandırması olarak kullan. **service_role key'i mobil uygulamaya veya depoya koyma.**

## 2. Flutter yapılandırması
Derleme sırasında aşağıdaki dart-define değerlerini kullan:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Örnek:
```sh
cd mobil
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```


## 4. GitHub bağlantısı (bir kez senin hesabından)
Bu depo Supabase CLI yapısına hazırlandı: `supabase/config.toml` ve `supabase/migrations/20261014000000_initial_schema.sql` eklendi. Depo kökünde `supabase/` klasörü bulunduğu için çalışma dizini `.` olmalı.

1. [Supabase Dashboard](https://supabase.com/dashboard) üzerinden kendi hesabınla giriş yap ve projeni oluştur.
2. Projede **Project Settings → Integrations → GitHub Integration → Authorize GitHub** yolunu aç.
3. GitHub yetkilendirmesinde **Authorize Supabase** de ve `Gazinizx/Cafe` deposunu seç.
4. Working directory alanına `.` yaz ve entegrasyonu etkinleştir.
5. GitHub entegrasyonu sayfasında mevcut projeye ait otomatik dağıtım seçeneklerini gözden geçir. İlk kez bağlarken canlı veritabanına değişiklik uygulamadan önce migration ve RLS politikalarını kontrol et.

GitHub yetkilendirmesi, Supabase projesi oluşturma ve hesap onayı kullanıcı hesabında yapılmalıdır; bunları senin adına dışarıdan tamamlayamam. Bu işlem için GitHub şifreni veya Supabase gizli anahtarlarını bana gönderme. Mobil uygulamaya yalnızca Project URL ve publishable/anon anahtarı girilir; `service_role` anahtarı kesinlikle paylaşılmaz.

## 3. Yayına çıkmadan önce
- Supabase kimlik doğrulaması ve profil/kafe/kampanya verilerinin uygulama katmanına bağlandığını doğrula.
- Gerçek satın alma doğrulaması olmadan sadakat damgası üretme; doğrudan istemci yazma izni verme.
- Admin işlemlerini yalnızca güvenilir sunucu tarafı yönetim aracıyla yap.
- Android gerçek cihaz, iOS gerçek cihaz, çevrimdışı durum, hesap kurtarma ve RLS testlerini tamamla.
- iOS için Apple imzalama ve App Store Connect erişimi gerekir.

Bu şema güvenli başlangıç politikaları sağlar; tek başına mevcut yerel ekranları buluta bağlamaz. Uygulama kodundaki yerel veri erişimleri Supabase servisine geçirilmeden cihazlar arası senkronizasyon etkinleşmiş sayılmaz.
