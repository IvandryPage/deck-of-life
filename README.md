# Deck of Life

> *Your life, in your hands.*

Aplikasi Android pribadi (single-user, local-first, offline-first) untuk menyimpan
informasi, mengelola tugas/agenda/pengingat, memantau saldo & tagihan, dan rutinitas.
Spesifikasi lengkap: [`docs/PRD.md`](docs/PRD.md) dan [`docs/TDD.md`](docs/TDD.md).

## Toolchain

| Komponen | Versi |
|---|---|
| Dart SDK (minimal) | `^3.12.2` (`pubspec.yaml`) |
| Gradle | Kotlin DSL (`*.gradle.kts`), wrapper 8.14.3 |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.4.0 |
| JVM target | `JvmTarget.JVM_17` lewat `kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }`, Java source/target 17 |
| State / DI / routing | GetX |
| Database | SQLite (`sqflite`), skema v1 + migrasi berurutan |

## Menjalankan

```bash
# 1. Lengkapi berkas platform yang tidak ikut disertakan (gradlew, gradle-wrapper.jar,
#    local.properties). Perintah ini TIDAK menimpa berkas yang sudah ada.
flutter create --platforms=android --project-name deck_of_life .

# 2. Pastikan build.gradle.kts / settings.gradle.kts masih versi proyek ini
#    (Kotlin 2.4.0, JVM_17). Bila `flutter create` mengubahnya, kembalikan.
flutter pub get
flutter analyze
flutter test        # tes database memakai sqflite_common_ffi: butuh libsqlite3 di mesin dev
flutter run
```

## Struktur

```
lib/
├── app/        routing, binding awal (DI), tema
├── core/       database + migrasi, notifikasi, share intake, backup, pencarian, util
├── domain/     entity, kontrak repository, use case (Dart murni, tanpa Flutter/GetX/SQLite)
├── data/       mapper baris SQLite, implementasi repository
└── features/   home, inbox, search, tasks, agenda, finance, routines, settings, shell
android/        MainActivity.kt menerima Share Sheet (text/plain) via MethodChannel
test/           unit test logika + test repository/backup di SQLite nyata
```

## Cakupan MVP yang diimplementasikan

- **Beranda:** agenda hari ini, maksimal 3 deadline terdekat (overdue lebih dulu), ringkasan saldo
  (empty state "masukkan saldo", bukan Rp0), item perlu diperiksa, rutinitas.
- **Kotak masuk:** capture satu kolom, Android Share Sheet, status *perlu diperiksa*, arsip,
  hubungan ke tugas tanpa otomatis membuat tugas.
- **Pencarian:** `LIKE` berparameter (judul, isi, konteks, grup, sumber, URL, tugas) + filter.
- **Tugas & agenda:** hanya judul/waktu mulai yang wajib; pengingat dengan preset.
- **Pengingat:** disimpan di SQLite dulu, baru dijadwalkan ke OS; direkonsiliasi saat start & restore.
- **Keuangan:** saldo terkonfirmasi + riwayat koreksi (atomik), tagihan, uang bebas (estimasi),
  target pemasukan harian dengan asumsi yang ditampilkan; transaksi opsional tidak mengubah saldo.
- **Rutinitas:** harian / mingguan / interval, log pelaksanaan, jadwal berikutnya.
- **Backup:** ekspor JSON (+ checksum), restore tervalidasi, atomik (replace-all), dengan backup
  pengaman otomatis sebelum menimpa.

## Batasan yang disengaja

- Backup **tidak terenkripsi** dan tidak menyertakan berkas eksternal yang hanya direferensikan.
- Notifikasi memakai jadwal *inexact*; Android tidak menjamin tepat detik.
- Share Sheet: hanya teks/URL. Nama grup/pengirim tidak selalu dikirim aplikasi sumber.
- Tautan hanya disimpan sebagai referensi; isi file di baliknya tidak diunduh.
- Belum ada: FTS5, OCR, AI, cloud sync, kalender eksternal, pengulangan agenda, rekomendasi
  "pekerjaan berikutnya" (P1 di PRD).

## Status verifikasi

Kode ditulis tanpa Flutter/Dart SDK di lingkungan pembuatnya, sehingga **belum pernah dikompilasi
atau dijalankan**. Jalankan `flutter analyze` dan `flutter test` lebih dulu, lalu uji manual di
perangkat nyata: share dari WhatsApp/browser, izin notifikasi, restart perangkat, mode pesawat,
ekspor lalu restore.
