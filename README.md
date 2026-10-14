# Cafe Dünyam

Flutter Android uygulaması ve tarayıcıda çalışan yerel yönetim paneli.

- `mobil/`: müşteri ve işletme akışları olan Flutter uygulaması.
- `yonetim/index.html`: tarayıcı içinde çalışan örnek kafe/kampanya paneli.
- `.github/workflows/android-apk.yml`: Android APK derleme iş akışı.

## Bu sürümde uygulamadaki yerel akışlar

- Müşteri ve işletme rolüyle hesap oluşturma, giriş ve çıkış.
- Müşteri ana sayfası, kafe arama/şehir filtresi, kafe detayları, sadakat kartı görünümü, kampanya kaydetme ve profil.
- İşletme paneli, yerel kampanya taslağı oluşturma, kampanyayı aktif/pasif yapma ve silme.
- Kafe/kampanya listeleri, profil ve oturum bilgileri cihazdaki SharedPreferences içinde tutulur.

## Önemli sınırlar

Bu bir **yerel prototiptir**, yayın için hazır üretim sistemi değildir. Hesaplar ve veriler yalnızca aynı cihazda saklanır; başka telefonla, tarayıcı paneliyle veya başka kullanıcıyla senkronize olmaz. Yerel parola saklama yöntemi gerçek kullanıcı hesapları için güvenli değildir; gerçek sürümden önce sunucu tabanlı kimlik doğrulama gerekir.

İşletme hesabı/şube sahipliği doğrulaması, güvenli yetkilendirme, gerçek alışverişi doğrulayan sunucu işlemi, sahteciliğe dayanıklı damga verme, kampanyaların cihazlar arası dağıtımı ve gerçek müşteri-işletme bağlantısı bu sürümde yoktur. Sadakat kartı ekranı yalnızca yerel örnek durumu gösterir; gerçek alışverişe karşılık damga verildiğini garanti etmez. Örnek kafe ve kampanya verileri gerçek işletme ortaklığı anlamına gelmez.

## APK oluşturma

GitHub deposunda **Actions → Cafe Dunyam Android APK** bölümünden derleme çalıştırmasını açın. Başarılı iş akışının Artifacts bölümünde `cafe-dunyam-android-apk` dosyası görünür. Derleme sonucu doğrulanmadan APK'nın başarıyla üretildiği varsayılmamalıdır.
