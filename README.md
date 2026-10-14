# Cafe Dünyam

Flutter mobil uygulaması ve tarayıcıda çalışan örnek yönetim paneli.

- `mobil/`: Android Flutter uygulaması.
- `yonetim/index.html`: kafeler ve kampanyalar için yerel yönetim paneli.
- `.github/workflows/android-apk.yml`: GitHub Actions APK derlemesi.

Veritabanı olmadan kullanım: mobil uygulama örnek kafeleri ve kampanyaları içerir; damga sayacı bellekte tutulur. Yönetim paneli localStorage kullanır ve mobil uygulamayla eşitlenmez. Gerçek hesaplar, yetkilendirme, cihazlar arası eşitleme ve güvenli damga doğrulaması için ileride sunucu/API gerekir. QR kod okutmak tek başına damga vermez.

APK için GitHub > Actions > Cafe Dunyam Android APK > Run workflow seç. Başarılı derlemenin Artifacts bölümünden cafe-dunyam-android-apk dosyasını indir.
