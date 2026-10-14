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

## 3. Yayına çıkmadan önce
- Supabase kimlik doğrulaması ve profil/kafe/kampanya verilerinin uygulama katmanına bağlandığını doğrula.
- Gerçek satın alma doğrulaması olmadan sadakat damgası üretme; doğrudan istemci yazma izni verme.
- Admin işlemlerini yalnızca güvenilir sunucu tarafı yönetim aracıyla yap.
- Android gerçek cihaz, iOS gerçek cihaz, çevrimdışı durum, hesap kurtarma ve RLS testlerini tamamla.
- iOS için Apple imzalama ve App Store Connect erişimi gerekir.

Bu şema güvenli başlangıç politikaları sağlar; tek başına mevcut yerel ekranları buluta bağlamaz. Uygulama kodundaki yerel veri erişimleri Supabase servisine geçirilmeden cihazlar arası senkronizasyon etkinleşmiş sayılmaz.
