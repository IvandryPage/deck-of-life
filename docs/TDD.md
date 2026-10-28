# Personal Life Hub — Technical Design Document (TDD)

**Versi:** 1.0  
**Tanggal:** 26 Oktober 2026  
**Status:** Rancangan awal untuk implementasi MVP  
**Platform:** Android  
**Stack utama:** Flutter, Dart, GetX, SQLite

---

## 1. Tujuan dokumen

TDD ini menerjemahkan PRD Personal Life Hub menjadi rancangan implementasi yang dapat langsung dijadikan acuan coding. Prioritasnya adalah penyimpanan informasi dan pencarian yang cepat, lalu tugas, agenda, pengingat, keuangan sederhana, rutinitas, dan backup lokal.

### Keputusan arsitektur utama

1. **Local-first:** operasi inti tidak membutuhkan koneksi internet.
2. **SQLite sebagai sumber data utama:** data tugas, item tersimpan, agenda, pengingat, dan keuangan disimpan secara relasional.
3. **GetX hanya untuk dependency injection, routing, dan state management.** Jangan mencampur logika bisnis ke widget atau controller.
4. **Repository sebagai batas akses data:** controller tidak menjalankan SQL secara langsung.
5. **SavedItem dan Task terpisah:** informasi yang disimpan tidak otomatis menjadi tugas.
6. **Nominal uang disimpan sebagai integer rupiah**, bukan `double`, agar tidak ada error pembulatan.
7. **Tanggal disimpan dalam ISO 8601**; waktu pengingat harus menyimpan zona/waktu lokal yang diperlukan untuk menjadwalkan notifikasi.
8. **Backup/restore harus transaksional dan tervalidasi.** Jangan menimpa database aktif sebelum backup berhasil diperiksa.

## 2. Ruang lingkup teknis MVP

### Termasuk

- Dashboard: agenda hari ini, tiga deadline terdekat, ringkasan saldo dan tagihan.
- Inbox item tersimpan: teks, pesan salinan, tautan, catatan sumber, konteks kuliah/kelompok, status review.
- Pencarian lokal lintas judul, isi teks, konteks, dan sumber.
- Tugas dan statusnya.
- Agenda dan pengingat lokal.
- Akun/saldo manual, penyesuaian saldo, transaksi opsional, tagihan, target pendapatan harian.
- Rutinitas dengan catatan penyelesaian terakhir dan jadwal berikutnya.
- Ekspor dan impor backup manual.
- Penanganan data offline, izin notifikasi, dan error database.

### Tidak termasuk dalam MVP

- Akun pengguna, server, cloud sync, dan multi-device.
- Membaca seluruh riwayat WhatsApp atau memulihkan pesan yang telah dihapus.
- OCR otomatis, AI yang memutuskan sendiri, dan semantic search.
- Integrasi bank otomatis.
- Prediksi pendapatan driver yang mengklaim akurat.
- Sinkronisasi kalender eksternal.

## 3. Struktur modul dan folder

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── routes/app_pages.dart
│   ├── routes/app_routes.dart
│   └── bindings/initial_binding.dart
├── core/
│   ├── database/app_database.dart
│   ├── database/migrations/
│   ├── notifications/notification_service.dart
│   ├── sharing/share_intake_service.dart
│   ├── backup/backup_service.dart
│   ├── search/search_service.dart
│   ├── errors/app_exception.dart
│   └── utils/date_time_utils.dart
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── data/
│   ├── models/
│   ├── datasources/local/
│   └── repositories/
└── features/
    ├── home/
    ├── inbox/
    ├── search/
    ├── tasks/
    ├── agenda/
    ├── finance/
    ├── routines/
    └── settings/
```

Setiap fitur menggunakan pola:

```text
feature/
├── bindings/
├── controllers/
├── pages/
├── widgets/
└── repositories/   # hanya jika repository khusus fitur; kontrak tetap di domain/
```

Aturan dependency:
- `pages/widgets -> controllers`
- `controllers -> use cases`
- `use cases -> repository interfaces`
- `data repositories -> local data sources`
- `core` tidak boleh bergantung pada `features`
- `domain` tidak boleh mengimpor Flutter/GetX/SQLite

Untuk MVP kecil, use case dapat tetap sederhana. Namun SQL tetap berada di datasource/repository, bukan di controller.

## 4. Paket yang dibutuhkan

Pilih versi stabil yang kompatibel dengan versi Flutter yang dipakai saat mulai implementasi. Periksa status pemeliharaan dan kompatibilitas Android sebelum mengunci versi di `pubspec.yaml`.

- `get`: state management, routing, dependency injection.
- `sqflite`: database SQLite.
- `path`: membentuk path file database.
- `path_provider`: direktori aplikasi dan lokasi ekspor.
- `flutter_local_notifications`: notifikasi lokal.
- `timezone`: penjadwalan notifikasi berbasis zona waktu bila diperlukan plugin.
- `share_plus`: menerima/menangani alur berbagi sesuai kemampuan platform; validasi API paket saat implementasi.
- `file_picker`: memilih file backup untuk restore.
- `share_plus` atau mekanisme berbagi file yang kompatibel untuk mengekspor backup.
- `uuid`: ID stabil untuk entitas.
- `intl`: format tanggal dan rupiah.
- `crypto`: checksum backup bila diperlukan.

Jangan menambahkan paket hanya untuk menghindari sedikit kode manual. Hindari menyimpan objek kompleks di `GetStorage`/`SharedPreferences`; gunakan itu hanya untuk preferensi kecil seperti tema dan pengaturan tampilan.

## 5. Skema database SQLite

Gunakan foreign key dan aktifkan dengan `PRAGMA foreign_keys = ON` pada koneksi database. Gunakan transaksi untuk operasi yang menyentuh lebih dari satu tabel. ID berupa UUID string agar backup/import lebih mudah dan ID tidak bergantung pada urutan row.

> Skema berikut adalah baseline. Implementasikan melalui migration berurutan, bukan dengan mengubah schema lama tanpa migrasi.

```sql
CREATE TABLE saved_items (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content_text TEXT NOT NULL DEFAULT '',
  item_type TEXT NOT NULL CHECK (
    item_type IN ('note','message','link','file_reference','image_reference','other')
  ),
  source_app TEXT,
  source_label TEXT,
  source_url TEXT,
  source_location TEXT,
  course_name TEXT,
  group_name TEXT,
  context_note TEXT,
  review_status TEXT NOT NULL DEFAULT 'needs_review' CHECK (
    review_status IN ('needs_review','reviewed','archived')
  ),
  is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT
);

CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'todo' CHECK (
    status IN ('needs_review','todo','in_progress','done','cancelled')
  ),
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (
    priority IN ('low','normal','high','urgent')
  ),
  due_at TEXT,
  estimated_minutes INTEGER,
  course_name TEXT,
  group_name TEXT,
  task_kind TEXT NOT NULL DEFAULT 'individual' CHECK (
    task_kind IN ('individual','group','shared_responsibility','unknown')
  ),
  instruction_source TEXT,
  instruction_location TEXT,
  initiated_by TEXT,
  next_action TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT,
  archived_at TEXT
);

CREATE TABLE task_saved_items (
  task_id TEXT NOT NULL,
  saved_item_id TEXT NOT NULL,
  relation_note TEXT,
  PRIMARY KEY (task_id, saved_item_id),
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (saved_item_id) REFERENCES saved_items(id) ON DELETE CASCADE
);

CREATE TABLE events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  starts_at TEXT NOT NULL,
  ends_at TEXT,
  location TEXT,
  event_type TEXT NOT NULL DEFAULT 'other' CHECK (
    event_type IN ('lecture','work','meeting','appointment','personal','other')
  ),
  linked_task_id TEXT,
  linked_saved_item_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (linked_task_id) REFERENCES tasks(id) ON DELETE SET NULL,
  FOREIGN KEY (linked_saved_item_id) REFERENCES saved_items(id) ON DELETE SET NULL
);

CREATE TABLE reminders (
  id TEXT PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (
    target_type IN ('task','event','bill','routine','saved_item')
  ),
  target_id TEXT NOT NULL,
  remind_at TEXT NOT NULL,
  repeat_rule TEXT,
  notification_id INTEGER NOT NULL UNIQUE,
  is_enabled INTEGER NOT NULL DEFAULT 1 CHECK (is_enabled IN (0,1)),
  last_scheduled_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  account_type TEXT NOT NULL DEFAULT 'cash' CHECK (
    account_type IN ('cash','bank','e_wallet','other')
  ),
  confirmed_balance INTEGER NOT NULL DEFAULT 0 CHECK (confirmed_balance >= 0),
  balance_confirmed_at TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  direction TEXT NOT NULL CHECK (direction IN ('income','expense')),
  category TEXT NOT NULL,
  note TEXT,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
);

CREATE TABLE balance_adjustments (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  previous_balance INTEGER NOT NULL,
  corrected_balance INTEGER NOT NULL CHECK (corrected_balance >= 0),
  reason TEXT,
  adjusted_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
);

CREATE TABLE bills (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  due_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unpaid' CHECK (
    status IN ('unpaid','paid','cancelled')
  ),
  paid_at TEXT,
  account_id TEXT,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL
);

CREATE TABLE routines (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  recurrence_type TEXT NOT NULL CHECK (
    recurrence_type IN ('daily','weekly','interval')
  ),
  interval_days INTEGER,
  weekdays_json TEXT,
  preferred_time TEXT,
  next_due_at TEXT,
  last_completed_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE routine_logs (
  id TEXT PRIMARY KEY,
  routine_id TEXT NOT NULL,
  completed_at TEXT NOT NULL,
  note TEXT,
  FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
);

CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_saved_items_updated ON saved_items(updated_at DESC);
CREATE INDEX idx_saved_items_review ON saved_items(review_status, created_at DESC);
CREATE INDEX idx_tasks_due ON tasks(due_at, status);
CREATE INDEX idx_tasks_status ON tasks(status, priority);
CREATE INDEX idx_events_start ON events(starts_at);
CREATE INDEX idx_reminders_time ON reminders(is_enabled, remind_at);
CREATE INDEX idx_bills_due ON bills(status, due_at);
CREATE INDEX idx_transactions_date ON transactions(occurred_at DESC);
CREATE INDEX idx_routine_logs_date ON routine_logs(routine_id, completed_at DESC);
```

### Catatan schema yang wajib dipahami

- `accounts.confirmed_balance` adalah saldo terakhir yang dikonfirmasi manual, bukan saldo yang dihitung dari seluruh transaksi.
- `transactions` adalah catatan opsional. Pada MVP, transaksi tidak otomatis mengubah `confirmed_balance`, untuk mencegah saldo berubah ganda atau menyimpang dari saldo aktual.
- Saat pengguna melakukan koreksi saldo, update `accounts.confirmed_balance` dan insert `balance_adjustments` dalam satu transaksi SQLite.
- `bills` mengurangi estimasi uang bebas hanya selama statusnya `unpaid`. Ketika bill ditandai `paid`, bill tidak lagi mengurangi estimasi. Jangan mengurangi saldo akun secara otomatis sekaligus mengurangi bill tanpa alur pembayaran yang jelas.
- `reminders.target_id` sengaja tidak memakai foreign key polimorfik. Saat target dihapus, service/use case wajib membatalkan reminder terkait. Ini harus diuji.
- `source_url` menyimpan URL jika memang tersedia. `source_location` adalah petunjuk seperti nama grup atau konteks pesan, bukan klaim bahwa aplikasi memiliki akses langsung ke lokasi pesan di WhatsApp.
- Referensi file eksternal tidak menjamin file tersebut tetap ada. Untuk MVP, simpan label/path/URL dan teks yang diberikan melalui share intent; jangan menyalin file besar tanpa persetujuan yang jelas.

## 6. Aturan bisnis

### 6.1 Saved item

- Saat capture, simpan secepat mungkin dengan nilai minimum: `id`, `title` atau judul sementara, `content_text`, `item_type`, `created_at`, `updated_at`.
- Jika judul belum dapat ditentukan, buat judul sementara seperti `Item baru — 26 Okt 2026` dan tandai `needs_review`.
- Kegagalan ekstraksi metadata tidak boleh menggagalkan penyimpanan konten dasar.
- Saat mengubah judul/isi/konteks, update `updated_at`.
- Archive adalah pilihan default untuk item yang ingin disembunyikan; jangan langsung menghapus permanen.

### 6.2 Tugas dan prioritas

Status:
- `needs_review`: informasi tugas belum lengkap atau perlu dikonfirmasi.
- `todo`: siap dikerjakan.
- `in_progress`: sedang dikerjakan.
- `done`: selesai.
- `cancelled`: tidak jadi dikerjakan.

Urutan tampilan dashboard:
1. Tugas overdue yang belum selesai.
2. Tugas urgent/high dengan deadline terdekat.
3. Deadline terdekat lainnya.
4. Tugas tanpa deadline yang belum selesai.

Urutan ini adalah aturan tampilan, bukan skor ilmiah. Jangan otomatis mengubah status atau deadline. Pengguna tetap dapat mengurutkan berdasarkan deadline atau prioritas.

Saat status menjadi `done`, isi `completed_at`. Jika dibuka kembali, kosongkan `completed_at`. Update ini dilakukan dalam transaksi bersama perubahan reminder jika ada.

### 6.3 Agenda

- Simpan waktu dalam ISO 8601 dengan offset, misalnya `2026-10-26T09:00:00+07:00`.
- Event tanpa `ends_at` tetap valid.
- Dashboard harian memakai rentang hari lokal perangkat, bukan UTC date mentah.
- Event yang sudah lewat tidak dihapus otomatis.

### 6.4 Pengingat

- Simpan reminder di SQLite terlebih dahulu, baru jadwalkan notifikasi OS.
- Jika penjadwalan OS gagal, data reminder tetap tersimpan dan UI menampilkan status bahwa notifikasi perlu diperiksa.
- Perubahan waktu, status selesai, penghapusan target, atau penonaktifan reminder harus membatalkan notifikasi lama sebelum menjadwalkan ulang.
- `notification_id` harus stabil dan unik. Jangan memakai `hashCode` runtime sebagai ID.
- Saat aplikasi mulai, rekonsiliasi reminder aktif dengan penjadwal notifikasi jika API plugin memungkinkan.
- Jelaskan izin notifikasi dengan konteks yang tepat; jangan meminta izin sebelum pengguna memahami manfaatnya.
- Android dapat membatasi ketepatan notifikasi karena battery optimization dan kebijakan OS. Jangan menjanjikan notifikasi selalu tepat detik.

### 6.5 Keuangan

Semua nominal berupa integer rupiah.

Definisi:
- `confirmed_total` = jumlah `confirmed_balance` dari semua akun aktif.
- `known_unpaid_bills` = jumlah tagihan berstatus `unpaid`.
- `estimated_free_money` = `confirmed_total - known_unpaid_bills`.
- Nilai estimasi boleh negatif; UI menampilkan kekurangan, bukan memaksa menjadi nol.
- `funding_gap` = `max(0, upcoming_obligations - available_funds - confirmed_income_before_due_date)`.
- `daily_income_target` = `funding_gap / remaining_workdays`, dibulatkan ke atas. Jika jumlah hari kerja tidak diketahui atau nol, tampilkan “tentukan hari kerja” atau “belum bisa dihitung”, bukan membagi dengan nol.
- Pendapatan yang belum diterima tidak dihitung sebagai uang tersedia. Perkiraan pendapatan boleh ditampilkan terpisah dengan label estimasi.
- Jika transaksi dicatat, itu hanya histori sampai pengguna mengonfirmasi saldo terbaru. Jangan menjumlahkan transaksi lagi ke saldo yang sudah dikonfirmasi.
- Penyesuaian saldo wajib meminta nilai saldo aktual dan boleh menerima alasan opsional.

MVP tidak membutuhkan sistem pembukuan penuh. Kejelasan dan koreksi saldo lebih penting daripada pencatatan semua pengeluaran.

### 6.6 Rutinitas

- Saat rutin diselesaikan, insert ke `routine_logs`, set `last_completed_at`, dan hitung `next_due_at`.
- `daily`: jadwal berikutnya pada hari lokal berikutnya dengan waktu pilihan jika tersedia.
- `weekly`: hitung berdasarkan daftar hari yang dipilih.
- `interval`: tambah `interval_days` dari waktu penyelesaian terakhir.
- Jangan mengubah jadwal berdasarkan notifikasi yang sekadar dibaca. Hanya aksi eksplisit “Selesai” yang mencatat rutinitas selesai.
- Perhitungan recurrence perlu unit test untuk pergantian bulan/tahun dan perubahan zona waktu.

## 7. Pencarian

MVP dimulai dengan query SQLite `LIKE` untuk mengurangi kompleksitas. Pencarian mencakup:
- `saved_items.title`
- `saved_items.content_text`
- `course_name`
- `group_name`
- `context_note`
- `source_label`
- `source_location`
- URL/domain bila tersedia
- judul/deskripsi tugas

Gunakan parameter binding SQL, jangan menyisipkan input pencarian langsung ke string SQL. Batasi hasil awal dan tambahkan pagination jika koleksi bertambah.

Jika jumlah data dan hasil pengujian menunjukkan `LIKE` tidak cukup cepat, evaluasi FTS5 pada versi SQLite yang benar-benar tersedia di perangkat target. Jangan menganggap FTS5 pasti aktif di semua build. FTS5 adalah peningkatan berikutnya, bukan prasyarat MVP.

## 8. Alur capture Android Share

Alur yang dituju:

1. Pengguna memilih teks/tautan/file di aplikasi lain lalu menekan Share.
2. Android mengirim data yang didukung oleh intent.
3. `ShareIntakeService` memvalidasi MIME type, teks, dan URI yang diterima.
4. Aplikasi menampilkan halaman capture ringkas dengan isi sudah terisi.
5. Aplikasi boleh menyarankan judul, tipe, sumber, dan konteks; semua saran dapat diedit.
6. Pengguna menekan “Simpan”.
7. Data disimpan ke SQLite, lalu pengguna mendapat konfirmasi.
8. Jika metadata gagal diproses, konten mentah tetap dapat disimpan.

Implementasi perlu memeriksa kontrak share intent Android dan kompatibilitas plugin. Tidak semua aplikasi mengirim metadata sumber atau konten yang sama. URI file yang dibagikan bisa berupa URI sementara dengan izin terbatas; jangan menyimpan URI tersebut seolah-olah aksesnya permanen. Untuk MVP, dukung teks dan URL lebih dahulu; referensi file ditambahkan setelah alur izin dan persistensi URI diuji di perangkat nyata.

## 9. Arsitektur GetX

Contoh pola controller:

```dart
class InboxController extends GetxController {
  InboxController(this.searchSavedItems, this.createSavedItem);

  final SearchSavedItems searchSavedItems;
  final CreateSavedItem createSavedItem;

  final items = <SavedItem>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final query = ''.obs;

  Future<void> search(String value) async {
    query.value = value;
    isLoading.value = true;
    errorMessage.value = null;

    try {
      items.assignAll(await searchSavedItems(value));
    } catch (error) {
      errorMessage.value = 'Pencarian gagal. Coba lagi.';
    } finally {
      isLoading.value = false;
    }
  }
}
```

Pedoman:
- Controller hanya mengelola state layar dan memanggil use case.
- Jangan expose exception SQL mentah ke pengguna.
- Gunakan `Obx` untuk area UI yang benar-benar reaktif; hindari satu `Obx` besar untuk seluruh layar.
- Gunakan binding untuk mendaftarkan controller dan dependency.
- Gunakan `Get.lazyPut` untuk dependency yang sesuai siklus hidup fitur; jangan membuat database berulang kali.
- Database dan service notifikasi dibuat sebagai dependency aplikasi yang hidup sepanjang aplikasi.
- Semua operasi async harus punya state loading/error/empty yang jelas.

## 10. Kontrak repository dan entity

Contoh kontrak domain:

```dart
abstract interface class SavedItemRepository {
  Future<SavedItem> create(SavedItem item);
  Future<SavedItem?> getById(String id);
  Future<List<SavedItem>> search(String query, {int limit = 50});
  Future<void> update(SavedItem item);
  Future<void> archive(String id, DateTime archivedAt);
}
```

Entity domain sebaiknya tidak bergantung pada widget atau model SQLite. Model data bertugas mengubah row SQLite ke entity dan sebaliknya.

Untuk setiap fitur, tetapkan kontrak yang setara:
- `TaskRepository`
- `EventRepository`
- `ReminderRepository`
- `FinanceRepository`
- `RoutineRepository`
- `BackupRepository` bila diperlukan

Hindari membuat interface generik yang terlalu abstrak untuk semua tabel. Kontrak spesifik fitur lebih mudah dipahami dan diuji.

## 11. Database versioning dan migrasi

- Mulai dengan `version: 1` pada pembukaan SQLite.
- Tambahkan perubahan berikutnya sebagai migration eksplisit: `onUpgrade` atau sistem migrasi sendiri.
- Jangan menghapus dan membuat ulang database pada update aplikasi.
- Setiap migration harus diuji terhadap database versi sebelumnya yang berisi data contoh.
- Backup harus menyertakan `schema_version` dan `app_version`.
- Restore menolak file dengan format tidak dikenal atau versi skema yang lebih baru daripada aplikasi, dengan pesan yang dapat dipahami.
- Sebelum restore, tawarkan/hasilkan backup database aktif agar data lama dapat dipulihkan jika pengguna salah memilih file.

## 12. Backup dan restore

Format backup MVP yang disarankan: satu file JSON UTF-8 dengan metadata dan array data tabel. File backup harus menyimpan `schema_version`, `exported_at`, dan versi aplikasi.

Contoh struktur konseptual:

```json
{
  "format": "personal-life-hub-backup",
  "schema_version": 1,
  "app_version": "1.0.0",
  "exported_at": "2026-10-26T10:00:00+07:00",
  "data": {
    "saved_items": [],
    "tasks": [],
    "task_saved_items": [],
    "events": [],
    "reminders": [],
    "accounts": [],
    "transactions": [],
    "balance_adjustments": [],
    "bills": [],
    "routines": [],
    "routine_logs": [],
    "app_settings": []
  }
}
```

Aturan:
- Validasi format, tipe data, ID, nilai nominal, status, dan referensi sebelum mengimpor.
- Restore harus berjalan dalam satu transaksi database; jika satu bagian gagal, rollback seluruh impor.
- MVP paling aman memakai mode **replace all** setelah pengguna mengonfirmasi, dengan backup otomatis database aktif sebelum penggantian.
- Jangan gabungkan data secara diam-diam berdasarkan judul karena bisa menciptakan duplikat atau kehilangan relasi.
- File JSON backup dapat berisi informasi pribadi. Tampilkan peringatan sebelum pengguna membagikan file.
- Backup database tidak otomatis mencakup berkas eksternal yang hanya direferensikan oleh URL/URI.

## 13. Dashboard: definisi data

Dashboard sebaiknya mengambil data dari query/repository khusus, bukan melakukan banyak query di widget.

Bagian:
1. **Agenda hari ini:** event yang mulai pada rentang hari lokal; urutkan waktu mulai.
2. **Tiga deadline terdekat:** tugas yang belum `done`/`cancelled`, urutkan overdue lebih dahulu lalu `due_at`.
3. **Ringkasan keuangan:** total saldo terkonfirmasi, tagihan belum dibayar, estimasi uang bebas, dan target pendapatan jika dapat dihitung.
4. **Perlu diperiksa:** saved items dan tugas dengan status `needs_review`.
5. **Rutinitas berikutnya:** rutin aktif dengan `next_due_at` terdekat.

Semua kartu harus memiliki empty state. Jika saldo belum pernah dimasukkan, tampilkan ajakan memasukkan saldo, bukan angka Rp0 yang seolah-olah pasti benar.

## 14. Error handling

Buat tipe error yang dapat dibedakan, misalnya:
- `DatabaseException`
- `ValidationException`
- `NotificationSchedulingException`
- `BackupFormatException`
- `ImportValidationException`
- `SharePayloadException`

Prinsip:
- Simpan data terlebih dahulu bila memungkinkan.
- Jangan menghilangkan konten pengguna hanya karena metadata atau notifikasi gagal.
- Tampilkan pesan singkat yang menjelaskan langkah pemulihan.
- Simpan detail teknis untuk debug lokal tanpa menyimpan konten pribadi ke log secara default.
- Jangan menelan exception tanpa logging/debug signal.

## 15. Privasi dan keamanan

- Semua data MVP tersimpan lokal.
- Jangan menambahkan analytics atau pengiriman konten ke server tanpa keputusan produk dan persetujuan terpisah.
- Hindari menulis isi pesan, catatan, atau data keuangan ke log.
- Gunakan storage aplikasi privat untuk database.
- Jangan menyimpan token atau kredensial karena MVP tidak membutuhkan akun/server.
- Backup tidak terenkripsi pada rancangan dasar; beri peringatan. Jika risiko perangkat bersama dianggap tinggi, prioritaskan enkripsi backup sebagai peningkatan terencana.
- Hapus permanen dan restore adalah tindakan destruktif: minta konfirmasi eksplisit.

## 16. Pengujian

### Unit test
- Perhitungan estimasi uang bebas dan funding gap.
- Pengurutan deadline termasuk overdue.
- Transisi status tugas dan `completed_at`.
- Penjadwalan recurrence rutin.
- Validasi backup dan schema version.
- Pemetaan row SQLite ke entity.
- Pencarian berdasarkan kata, konteks, dan URL.

### Database/integration test
- Migration dari versi lama ke baru tanpa kehilangan data.
- Koreksi saldo memperbarui akun dan mencatat adjustment secara atomik.
- Penghapusan task/event membatalkan reminder terkait.
- Restore gagal di tengah proses melakukan rollback.
- Relasi task-saved item tetap valid.
- Query dashboard menggunakan batas tanggal lokal yang benar.

### Uji perangkat Android
- Share teks dan URL dari setidaknya beberapa aplikasi sumber.
- Permission notifikasi diterima dan ditolak.
- Ubah waktu reminder, tandai tugas selesai, dan hapus target.
- Restart perangkat dan pastikan reminder masih tersimpan/terjadwal sesuai kemampuan plugin.
- Gunakan aplikasi dalam mode pesawat.
- Ekspor backup, hapus data uji, lalu restore.
- Uji layar kecil dan perangkat dengan RAM terbatas.

## 17. Urutan implementasi

### Sprint 0 — Fondasi
- Buat struktur folder, routing, theme dasar, error model.
- Konfigurasi SQLite, migration v1, repository pattern.
- Buat entity dan model untuk `SavedItem`.
- Pastikan insert/read/update/delete lolos test.

### Sprint 1 — Inbox dan pencarian
- Capture manual cepat.
- Daftar item tersimpan dan detail.
- Search lokal.
- Status `needs_review` dan archive.

### Sprint 2 — Tugas dan agenda
- CRUD task dan event.
- Hubungkan task ke saved item.
- Dashboard deadline dan agenda hari ini.
- Pengujian tanggal/waktu.

### Sprint 3 — Pengingat
- Reminder CRUD.
- Integrasi local notification.
- Rekonsiliasi jadwal dan pembatalan saat target berubah.
- Uji izin dan perilaku Android nyata.

### Sprint 4 — Keuangan
- Akun dan saldo terkonfirmasi.
- Koreksi saldo dengan riwayat.
- Tagihan dan status pembayaran.
- Target pendapatan harian dengan label estimasi.

### Sprint 5 — Rutinitas dan dashboard final
- Routine logs, last completed, next due.
- Ringkasan dashboard dan empty states.
- Penyempurnaan urutan tugas.

### Sprint 6 — Backup dan hardening
- Ekspor/restore JSON.
- Validasi dan rollback.
- Uji offline, migrasi, dan regresi.
- Perbaikan UX dan dokumentasi.

Jangan mulai dengan semua layar sekaligus. Pastikan alur **simpan informasi → temukan kembali** benar-benar cepat sebelum menambahkan modul lain.

## 18. Definition of Done MVP

MVP dianggap siap untuk penggunaan pribadi ketika:
- Pengguna dapat menyimpan item penting tanpa harus melengkapi banyak field.
- Item dapat dicari kembali melalui judul, teks, konteks, atau sumber.
- Item tersimpan tidak otomatis berubah menjadi tugas.
- Tugas dan event dapat dibuat, diedit, diselesaikan, dan dihapus/diarsipkan dengan konsisten.
- Reminder berubah sesuai perubahan data dan kegagalannya tidak menghapus data.
- Saldo terkonfirmasi dapat dikoreksi dengan histori penyesuaian.
- Tagihan unpaid tidak terhitung ganda pada estimasi uang bebas.
- Rutin mencatat waktu selesai dan waktu berikutnya.
- Backup dapat dipulihkan tanpa korupsi data atau relasi.
- Fitur inti bekerja tanpa internet.
- Tidak ada crash yang diketahui pada alur inti dan tidak ada konten pribadi yang ditulis ke log secara default.

## 19. Risiko teknis yang harus diuji sejak awal

1. **Share intent:** setiap aplikasi sumber dapat mengirim payload berbeda. Mulai dari teks/URL dan uji nyata.
2. **Notifikasi Android:** izin, battery optimization, dan versi Android memengaruhi delivery. Jangan mengasumsikan semua pengingat exact.
3. **Zona waktu:** event lintas hari dan perubahan zona waktu dapat memengaruhi dashboard. Gunakan helper terpusat dan unit test.
4. **Restore:** proses import yang tidak atomik dapat merusak data. Gunakan transaksi dan backup sebelum replace.
5. **Keuangan:** saldo terkonfirmasi dan histori transaksi memiliki makna berbeda. UI harus menjelaskannya secara eksplisit.
6. **Overengineering:** jangan membangun AI, cloud, sinkronisasi, atau FTS5 sebelum kebutuhan MVP teruji.

---

## Lampiran A — Checklist awal repository

- [ ] Buat `docs/PRD.md` dari PRD produk.
- [ ] Simpan dokumen ini sebagai `docs/TDD.md`.
- [ ] Buat `README.md` berisi tujuan, stack, cara menjalankan, dan batasan MVP.
- [ ] Buat migration SQLite v1 dan test.
- [ ] Tambahkan formatter/analyzer dan jalankan `flutter analyze`.
- [ ] Buat test database untuk insert/read/update/delete.
- [ ] Implementasikan Inbox sebelum fitur lain.
- [ ] Catat versi paket yang benar-benar digunakan di `pubspec.lock`.

## Lampiran B — Prinsip implementasi

**Simpan cepat, cari mudah, data tidak hilang, dan saldo tidak menyesatkan.** Setiap fitur baru harus memperkuat salah satu tujuan itu tanpa membuat pengguna mengisi form panjang atau mengurus sistem yang lebih rumit daripada masalahnya.
