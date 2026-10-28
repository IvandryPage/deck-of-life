# Deck of Life — Audit & Pengembangan

> **Catatan jujur:** lingkungan pembuat tidak memiliki Flutter/Dart SDK. Kode Dart
> **belum pernah dikompilasi atau dijalankan**, dan tes Dart **belum pernah dieksekusi**.
> Yang benar-benar diverifikasi: seluruh SQL migrasi (v1→v2 dengan data), serta kueri
> `pruneOrphans`, memakai `sqlite3` Python terhadap skema nyata. Jalankan
> `flutter analyze && flutter test` lebih dulu; perkirakan beberapa perbaikan kecil.

## 1. Audit (kondisi sebelum perubahan)

| Area | Temuan |
|---|---|
| Smart Inbox / Share Sheet | Ada (text/plain). **Kurang:** tidak ada deteksi duplikat; setelah simpan, pengguna tertinggal di aplikasi; pengingat "periksa" tidak dibersihkan saat item ditinjau. |
| Quick Capture & pencarian | Pencarian hanya item + tugas. **Kurang:** agenda & tagihan; tidak ada capture satu kolom di beranda. |
| Today View | Agenda, 3 deadline, hitungan overdue. **Kurang:** daftar terlambat, "tindakan berikutnya", pemulihan. |
| Konteks tugas | Kolom sumber/mata kuliah/grup ada; relasi ke item tersimpan ada. **Tidak ada** langkah pengerjaan terstruktur (ditunda, lihat §6). |
| Pengingat / berulang | Rutinitas konsisten. **Tidak ada** tugas & tagihan berulang; pengingat yatim bisa dijadwalkan ulang setelah restore. |
| Keuangan | Saldo, tagihan, estimasi. **Kurang:** target harian memakai *semua* tagihan (termasuk yang bulan depan) → target membengkak; tidak ada pemisahan terlambat/horizon/jauh dan kesenjangan dana. |
| Pemulihan | Backup JSON+checksum+restore atomik sudah ada. **Kurang:** tidak ada pengingat backup; tidak ada penanganan tugas terlewat. |

## 2. Perubahan

- **Migrasi v2** (additive, mempertahankan data): `tasks.recurrence_rule`, `bills.recurrence_rule`, indeks `reminders(target_type,target_id)`. Backup v1 tetap bisa dipulihkan (kolom diisi null).
- **Tugas & tagihan berulang** (`daily|weekly|monthly:<hari>`): saat selesai/dibayar, kemunculan berikutnya dibuat sekali (idempoten), konteks item tersimpan ikut, selisih pengingat dipertahankan; tidak pernah melahirkan tugas yang sudah terlambat. Jangkar bulanan (31 → 28 Feb → 31 Mar).
- **RealityCheck**: saldo terkonfirmasi (fakta) ≠ uang bebas (estimasi) ≠ tagihan belum dibayar; tagihan dipecah terlambat / dalam horizon (default 30 hari) / lebih jauh; kesenjangan dana & target harian hanya dari kewajiban dalam horizon. Tagihan lunas/batal tidak dihitung → tidak ada hitung ganda.
- **Today View**: kolom capture cepat (simpan ke Kotak Masuk, bukan tugas), "Lakukan berikutnya" (dengan alasan), tugas terlambat, banner backup, kartu keuangan baru.
- **Pemulihan tugas terlewat** (`OverduePage`): Selesai / Besok / Akhir pekan / Batalkan, pengingat ikut bergeser.
- **Pengingat konsisten**: `pruneOrphans` dijalankan di `reconcileAll` (start & setelah restore); meninjau item membatalkan pengingatnya; `SkipRoutine` menggeser jadwal tanpa mencatat pelaksanaan.
- **Share Sheet**: deteksi duplikat (URL/isi sama), tutup kembali ke aplikasi sumber setelah simpan (`close_after_share`, default aktif).
- **Pencarian global**: + agenda, + tagihan.
- **Backup**: waktu backup terakhir dicatat hanya bila pengguna benar-benar memilih tujuan berbagi.

## 3. File terdampak

Baru: `core/database/migrations/migration_v2.dart`, `domain/entities/recurrence.dart`, `features/tasks/pages/overdue_page.dart`, `tool/share_sheet_adb.sh`, tes (`logic_v2_test`, `recovery_db_test`, `share_intake_test`).
Diubah: `migrations.dart`, `entities.dart`, `logic.dart`, `row_mappers.dart`, `backup_validator.dart`, `repositories.dart`, `*_repository_impl.dart` (saved item, task, event, reminder, finance), `usecases.dart`, `reminder_coordinator.dart`, `initial_binding.dart`, `shell_binding.dart`, `home_controller/page`, `finance_controller/page`, `bill_sheet.dart`, `task_form_page.dart`, `search_page.dart`, `saved_item_form_page.dart`, `settings_controller.dart`, `app_routes/app_pages`, `backup_validator_test.dart`.
Tidak berubah: `applicationId` (`id.deckoflife.app`), teknologi, GetX sebagai satu-satunya state management.

## 4. Pengujian

| Cakupan | Berkas | Status |
|---|---|---|
| Unit: recurrence, RealityCheck, NextAction, reschedule | `logic_v2_test.dart` | ditulis, **belum dijalankan** |
| Database: berulang, prune, duplikat, pencarian, dashboard, migrasi v1→v2 | `recovery_db_test.dart` | ditulis, **belum dijalankan** (SQL setara diverifikasi di Python) |
| Backup/restore (v1 compat, v2) | `backup_validator_test.dart`, `database_test.dart` | diperbarui, belum dijalankan |
| Pengingat (scheduler palsu, reconcile) | `recovery_db_test.dart` | ditulis, belum dijalankan |
| Keuangan | `finance_calculator_test.dart`, `logic_v2_test.dart` | ditulis, belum dijalankan |
| Share Sheet: parsing + channel palsu | `share_intake_test.dart` | ditulis, belum dijalankan |
| Share Sheet di perangkat | `tool/share_sheet_adb.sh` | skrip manual, butuh perangkat |

Verifikasi nyata yang sudah dilakukan: migrasi v1→v2 dengan data (Python sqlite3) dan kueri `pruneOrphans` (mengembalikan tepat target yatim, mempertahankan tugas aktif).

## 5. Risiko tersisa

- Kode belum dikompilasi; kompatibilitas Kotlin 2.4.0 dengan AGP 8.11.1/plugin Flutter dan versi paket (`share_plus` 11, `flutter_local_notifications` 19) belum diuji.
- Gradle wrapper tidak ikut; jalankan `flutter create --platforms=android .` (lihat README).
- Notifikasi *inexact*; OEM agresif dapat menunda.
- Tugas berulang dibuat saat tugas diselesaikan (bukan terjadwal di belakang layar): bila tidak pernah diselesaikan, tidak ada kemunculan baru — disengaja agar tidak menumpuk.
- `SystemNavigator.pop()` setelah share menutup aktivitas; perilaku bergantung versi Android.

## 6. Sengaja ditunda

Share file/gambar (`EXTRA_STREAM`), FTS5, enkripsi backup, alarm eksak, daftar langkah tugas (butuh perubahan skema), pengurangan saldo otomatis saat tagihan dibayar (akan merusak prinsip "saldo = fakta terkonfirmasi"), antrean review khusus (Kotak Masuk + filter "perlu diperiksa" sudah cukup), serta AI/OCR/cloud sync/jaringan apa pun.
