# Cafe Dünyam

Flutter mobil uygulaması ve tarayıcıda çalışan örnek yönetim paneli.

- `mobil/`: Android Flutter uygulaması.
- `yonetim/index.html`: kafeler ve kampanyalar için yerel yönetim paneli.
- `.github/workflows/android-apk.yml`: GitHub Actions APK derlemesi.

## Veritabanı olmadan yerel test

- Kafe ve kampanya içerikleri şu an örnek veridir.
- Damga kartları ve kaydedilen fırsatlar cihazdaki `SharedPreferences` içinde tutulur; uygulama yeniden açıldığında aynı cihazda korunur.
- Veriler başka telefona aktarılmaz ve yönetim paneliyle eşitlenmez.
- NFC okuma, örnek/sabit NDEF kodlarını tanır. Bu yöntem kopyalanabileceği için gerçek alışverişi veya işletmeyi güvenli biçimde doğrulamaz; gerçek sadakat programında sunucu tarafı doğrulama gerekir.
- Profil ekranı yerel test modunu belirtir; gerçek hesap/üyelik bağlantısı yoktur.

## Android APK

GitHub > Actions > Cafe Dunyam Android APK > Run workflow seç. Başarılı derlemenin Artifacts bölümünden `cafe-dunyam-android-apk` dosyasını indir.
