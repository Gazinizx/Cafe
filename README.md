# Cafe Dünyam

Flutter tabanlı Android ve iOS uygulaması.

- `mobil/`: müşteri ve işletme akışları olan Flutter uygulaması.
- `yonetim/index.html`: tarayıcı içinde çalışan yerel örnek yönetim paneli.
- `.github/workflows/android-apk.yml`: Android release APK derlemesi ve artifact çıktısı.
- `.github/workflows/cross-platform.yml`: Android analiz/testleri ve iOS simülatör analiz/test/derlemesi.
- `supabase/schema.sql` ve `supabase/migrations/`: Supabase tabloları ve RLS politikaları. Üretim temeli migration'ı şube/çalışan, NFC kayıt defteri, ödül, paket/abonelik ve manuel tahsilat tablolarını ekler.
- `SUPABASE_SETUP.md`: bulut kurulumu ve güvenlik notları.

## Veri ve platform senkronizasyonu

- Kayıt/giriş Supabase Auth üzerinden yapılır. Android ve iOS cihazlarında **aynı Supabase projesi ve aynı kullanıcı hesabı** kullanıldığında, uygulamanın buluta bağladığı profil, kafe, kampanya, kayıtlı kampanya ve işletme başvurusu/sipariş verileri ortak veritabanından okunur.
- `SharedPreferences` cihaz içi tercih ve oturum saklama gibi yerel amaçlar içindir. Oturum açmış bir bulut hesabının bulut kaydı yapılamazsa veri artık sessizce cihaz belleğine yazılmaz; hata gösterilir.
- Oturum açılmadan gösterilen örnek kafe/kampanya verileri cihazlar arasında eşitlenmez.
- Müşteri damga bakiyesi `cafe_memberships` tablosundan okunur. Mobil istemcinin doğrudan damga yazmasına izin verilmez; NTAG doğrulamasını yapan güvenli Edge Function kurulup gerçek etiketle test edilmeden damga verme açılmaz.
- İşletme tahsilatları şu aşamada çevrim içi ödeme sağlayıcısı olmadan nakit veya banka havalesiyle yönetilir. Ödeme durumunu yalnızca yönetici doğrular.
- Bu depodaki SQL şeması ile migration dosyası aynıdır; ancak SQL'in canlı Supabase projesine gerçekten uygulandığı GitHub derlemesiyle kanıtlanamaz.

## Supabase kurulumu

`SUPABASE_SETUP.md` dosyasını izleyerek mevcut Supabase projesinde `supabase/schema.sql` dosyasının tamamını çalıştır. Project URL ve publishable/anon key Android ve iOS derlemelerinde aynı olmalı. **service_role key'i mobil uygulamaya veya depoya koyma.**

## Android APK

GitHub'da **Actions → Cafe Dunyam Android APK** iş akışının başarılı çalıştırmasının Artifacts bölümünde `cafe-dunyam-android-apk` bulunur. APK'nın telefonda açılması ve gerçek bulut hesabıyla test edilmesi derlemeden ayrı doğrulamalardır.

## iOS IPA

Bu depoda bir `.ipa` dosyası veya iOS imzalı IPA üretme iş akışı bulunmuyor. **Cross-platform Checks** yalnızca imzasız iOS simülatör uygulaması derler; gerçek iPhone'a kurulabilir IPA için Apple imzalama/provisioning yapılandırmasıyla ayrı bir iOS cihaz derlemesi gerekir. Eski IPA, yeni Android/iOS koduyla aynı sürüm değilse senkronizasyon davranışı da farklı olabilir.

## Yayına çıkmadan önce

- Supabase şemasının canlı projede uygulandığını ve RLS izinlerinin gerçek kullanıcılarla doğrulandığını test et.
- Android ve iOS'ta aynı hesapla giriş yaparak değişikliklerin diğer cihazda görünmesini uçtan uca doğrula.
- Gerçek satın alma doğrulaması olmadan sadakat damgası üretme.
- iOS imzalama, gerçek cihaz testi ve mağaza gönderimi ayrıca tamamlanmalıdır.
