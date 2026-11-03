# Growvia Mobile — Buka di Android Studio & Build APK

Panduan memasukkan proyek Flutter ini ke Android Studio, cara membangun APK, dan letak hasil build-nya.

Catatan: dokumen ini khusus langkah build. Informasi proyek yang sebelumnya ada di README ini — kontrak REST API `/api/v1`, status fitur, dan alur uji di HP via USB — masih tersimpan sebagai backup di `D:/Kuliah/SEMESTER 3/PBL/Tools/growvia-mobile/readme-mobile-lama.md`, dan ringkasan klien mobile tetap ada di `../Growvia/CONTEXT.md` bagian 13.

## Prasyarat (sudah ada di mesin ini)

| Alat | Lokasi | Catatan |
|---|---|---|
| Android Studio | `D:/Android Studio` | Gradle JDK memakai JBR bawaan: `D:/Android Studio/jbr` |
| Flutter SDK | `D:/Flutter` | Jangan dipindahkan ke folder berspasi |
| Android SDK | `D:/Android SDK` | Berisi platform-tools (adb) dan build-tools |
| Proyek | `D:/Kuliah/SEMESTER 3/PBL/Growvia Mobile` | Flutter 3.47.4 / Dart 3.13.3; Gradle 9.3.1 + AGP 9.1.0 |

Perhatian:

- `android/local.properties` sudah memuat `flutter.sdk=D:\Flutter` dan `sdk.dir=D:\Android SDK`. Bila proyek dipindah ke mesin lain, perbarui dua baris itu.
- Di terminal, path berspasi wajib dikutip.
- Jangan memakai drive virtual (`subst`), junction, atau alias partisi untuk menyiasati path. Path proyek valid tanpa trik apa pun.

## 1. Memasukkan proyek ke Android Studio

1. Buka Android Studio → **Open** (bukan New Project).
2. Pilih folder root proyek `D:/Kuliah/SEMESTER 3/PBL/Growvia Mobile` — folder yang berisi `pubspec.yaml`, **bukan** subfolder `android/`.
3. Pilih *Trust project* bila diminta, lalu tunggu indexing dan Gradle sync pertama selesai. Sync pertama dapat mengunduh Gradle wrapper; setelah itu tersimpan di cache.
4. Bila Android Studio belum mengenalinya sebagai proyek Flutter: `File > Settings > Plugins > Marketplace`, pasang plugin **Flutter** (plugin **Dart** ikut terpasang), restart IDE, lalu buka ulang folder proyek.
5. Periksa pengaturan di `File > Settings`:
   - **Languages & Frameworks > Flutter** → Flutter SDK path: `D:/Flutter`
   - **Languages & Frameworks > Android SDK** → Android SDK Location: `D:/Android SDK`
   - **Build, Execution, Deployment > Build Tools > Gradle** → Gradle JDK: **Embedded JDK** (JBR Android Studio)
6. Buka `pubspec.yaml`, klik **Pub get** (atau `File > Sync Project with Gradle Files`) agar dependency proyek terpasang di cache pub lokal.

Alternatif tanpa plugin Flutter: Open → pilih folder `D:/Kuliah/SEMESTER 3/PBL/Growvia Mobile/android`. Android Studio membacanya sebagai proyek Gradle Android biasa, dan build lewat Gradle di bagian 3 tetap jalan. Namun tombol **Run**, Hot Reload, dan analisis Dart membutuhkan plugin Flutter dengan folder root terbuka.

## 2. Mode build

- `debug` — default; dipakai untuk menjalankan aplikasi ke device/emulator.
- `release` — build produksi; lihat catatan penandatanganan di bagian 3.

Variant aktif bisa dilihat di panel **Build Variants** (sisi kiri bawah IDE).

## 3. Membangun APK

### Dari Android Studio

1. Pastikan variant di panel **Build Variants** (debug default; pilih release untuk APK produksi).
2. Menu **Build > Flutter > Build APK** (atau **Build > Flutter > Build App Bundle** untuk file `.aab`).
3. Tunggu build selesai; hasilnya di lokasi pada bagian 4, dan Event Log menampilkan path lengkapnya.

### Dari terminal

Path berspasi wajib dikutip:

```sh
cd "D:/Kuliah/SEMESTER 3/PBL/Growvia Mobile"

"D:/Flutter/bin/flutter.bat" pub get
"D:/Flutter/bin/flutter.bat" build apk --debug --target-platform android-arm64
"D:/Flutter/bin/flutter.bat" build apk --release --target-platform android-arm64
"D:/Flutter/bin/flutter.bat" build apk --split-per-abi

# App bundle untuk Play Store
"D:/Flutter/bin/flutter.bat" build appbundle
```

Bila Gradle gagal menemukan Java:

```sh
export JAVA_HOME="D:/Android Studio/jbr"
```

Alternatif Gradle murni (tanpa CLI Flutter), dari folder `android/`:

```sh
cd "D:/Kuliah/SEMESTER 3/PBL/Growvia Mobile/android"
export JAVA_HOME="D:/Android Studio/jbr"
./gradlew assembleDebug
./gradlew assembleRelease
```

### Bila muncul `No Android SDK found`

Pesan ini muncul ketika `flutter.bat` dijalankan langsung tanpa variabel `ANDROID_HOME`. Solusinya sekali saja dan permanen — tersimpan di konfigurasi Flutter, berlaku di semua shell (PowerShell, cmd, bash); cukup restart editor setelahnya:

```sh
"D:/Flutter/bin/flutter.bat" config --android-sdk "D:/Android SDK"
"D:/Flutter/bin/flutter.bat" config --jdk-dir "D:/Android Studio/jbr"
```

Cek dengan `flutter doctor --no-color`. Catatan `cmdline-tools component is missing` di doctor tidak memblokir build APK.

### Penandatanganan APK rilis

Saat ini `android/key.properties` **belum ada** (yang tersedia hanya template `android/key.properties.example`). Konsekuensinya:

- APK debug tidak pernah memakai keystore rilis — aman untuk uji lokal.
- APK rilis otomatis memakai **debug signing** agar tetap bisa dibangun lokal; build seperti ini **tidak boleh diunggah** ke Play Store.

Untuk rilis beneran:

```sh
keytool -genkeypair -v -keystore android/growvia-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias growvia
```

Lalu salin `android/key.properties.example` menjadi `android/key.properties` dan isi `storePassword`, `keyPassword`, `keyAlias`, `storeFile`. Berkas ini serta `*.jks`/`*.keystore` tidak boleh di-commit; simpan keystore dan kata sandinya di luar proyek — hilang berarti aplikasi tidak bisa diperbarui lagi di Play Store.

Verifikasi sertifikat APK rilis:

```sh
"D:/Android SDK/build-tools/<versi>/apksigner.bat" verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Sertifikatnya harus milik Anda, bukan `Android Debug`.

## 4. Letak output build

Path di bawah relatif terhadap folder proyek:

| Perintah | File hasil |
|---|---|
| `flutter build apk --debug` | `build/app/outputs/flutter-apk/app-debug.apk` (beserta `.sha1`) |
| `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` (beserta `.sha1`) |
| `flutter build apk --split-per-abi` | `build/app/outputs/flutter-apk/app-<abi>-release.apk`, mis. `app-arm64-v8a-release.apk` |
| `flutter build appbundle` | `build/app/outputs/bundle/release/app-release.aab` |
| `./gradlew assembleDebug` (dari `android/`) | `build/app/outputs/apk/debug/app-debug.apk` |
| `./gradlew assembleRelease` (dari `android/`) | `build/app/outputs/apk/release/app-release.apk` |

Path absolut contoh: `D:/Kuliah/SEMESTER 3/PBL/Growvia Mobile/build/app/outputs/flutter-apk/app-debug.apk`.

`flutter clean` menghapus seluruh folder `build/`; jalankan `flutter pub get` kembali sebelum build berikutnya.

Pasang APK ke HP:

```sh
"D:/Android SDK/platform-tools/adb.exe" install -r "build/app/outputs/flutter-apk/app-debug.apk"
```

## Catatan

- ID aplikasi sudah final dan seragam di kedua platform: **`com.growvia.mobile`** — jangan diubah setelah rilis store.
- Sebelum mengklaim build siap diuji: jalankan `flutter test` dan `flutter analyze` terlebih dahulu.
- iOS memerlukan macOS serta peninjauan entitlement secure storage.
