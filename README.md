# Cafe Dünyam

Flutter tabanlı Android ve iOS uygulaması.

- `mobil/`: müşteri ve işletme akışları olan Flutter uygulaması.
- `yonetim/index.html`: tarayıcı içinde çalışan yerel örnek yönetim paneli.
- `.github/workflows/android-apk.yml`: Android release APK derlemesi ve artifact çıktısı.
- `.github/workflows/cross-platform.yml`: Android analiz/testleri ve iOS simülatör analiz/test/derlemesi; APK paketlemesi yalnızca ayrı Android iş akışında yapılır.
- `supabase/schema.sql`: Supabase veritabanı tabloları ve başlangıç RLS politikaları.
- `SUPABASE_SETUP.md`: bulut kurulumu ve güvenlik notları.

## Mevcut uygulama durumu

Uygulamada müşteri/işletme kayıt ekranları, kafe keşfi, kampanyalar, yerel sadakat kartları ve işletme/yönetim ekranları bulunur. NFC eklentisi projede tutulmuştur.

**Önemli:** Mevcut mobil ekranların veri katmanı halen cihazdaki SharedPreferences'a dayanır. Bu nedenle hesaplar, damgalar ve kampanyalar cihazlar arasında henüz otomatik senkronize olmaz. Supabase şeması ve kurulum dokümanı eklendi; mevcut ekranların Supabase Auth ve bulut tablolarına bağlanması, RLS testleri ve gerçek cihaz testleri tamamlanmadan uygulama üretim/yayın için hazır sayılmaz.

## Supabase kurulumu

`SUPABASE_SETUP.md` dosyasını izleyerek bir Supabase projesi oluştur, `supabase/schema.sql` dosyasını SQL Editor'de çalıştır ve proje URL'si ile public anon/publishable key'i derleme yapılandırmasına ekle. **service_role key'i mobil uygulamaya koyma.**

## Android APK

GitHub deposunda **Actions → Cafe Dunyam Android APK** iş akışını çalıştır. Başarılı çalıştırmanın Artifacts bölümünde `cafe-dunyam-android-apk` görünür. Derleme sonucu doğrulanmadan APK'nın üretildiği varsayılmamalıdır.

## Platform kontrolleri

**Actions → Cafe Dunyam Cross-platform Checks** Android tarafında analiz, test ve release APK derlemesi; iOS tarafında analiz, test ve imzasız simülatör derlemesi çalıştırır. iOS simülatör derlemesi, imzalı gerçek cihaz uygulaması veya App Store yayını anlamına gelmez.
