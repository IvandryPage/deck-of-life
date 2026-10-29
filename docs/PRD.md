# Product Requirements Document (PRD)

## Personal Life Hub --- Versi 1.0

  Metadata            Nilai
  ------------------- ------------------------------------------
  Status              Draft untuk dijadikan basis utama proyek
  Versi dokumen       1.0
  Tanggal             25 Oktober 2026
  Platform target     Android
  Bahasa utama        Indonesia
  Model penggunaan    Personal / single-user
  Pendekatan teknis   Local-first, offline-first
  Nama produk         Personal Life Hub (nama sementara)

------------------------------------------------------------------------

## 1. Ringkasan Eksekutif

Personal Life Hub adalah aplikasi Android pribadi yang membantu pengguna
menyimpan dan menemukan kembali informasi penting, mengelola tanggung
jawab, mengingat deadline dan kewajiban, serta memahami kondisi keuangan
sehari-hari dari satu tempat.

Aplikasi ini ditujukan untuk seseorang dengan beberapa peran yang
berjalan bersamaan---mahasiswa, pekerja gig, asisten dosen, asisten
laboratorium, penghuni kost, dan individu dengan tanggung jawab pribadi.
Informasi berasal dari berbagai kanal seperti WhatsApp, grup, sistem
akademik, dokumen PDF, tautan Google Drive, dan percakapan langsung.
Pencatatan manual yang panjang membuat informasi sering hanya dibaca dan
ditunda untuk dicatat, dengan asumsi bahwa informasi dapat ditemukan
lagi nanti.

Produk ini tidak dimaksudkan untuk menggantikan WhatsApp, Google Drive,
kalender, atau seluruh aplikasi produktivitas. Peran utamanya adalah
menjadi **pusat informasi dan tanggung jawab**: menangkap informasi
dengan friksi rendah, menghubungkannya dengan tugas atau agenda jika
diperlukan, menyediakan pencarian lintas informasi, serta memberi
pengingat dan rekomendasi yang dapat dijelaskan.

Versi MVP harus mengutamakan keandalan alur inti, penggunaan offline,
dan kemudahan penggunaan dibandingkan banyaknya fitur. Aplikasi tidak
membutuhkan akun, backend, sinkronisasi cloud, atau layanan AI berbayar
untuk mulai berguna.

## 2. Latar Belakang dan Pernyataan Masalah

### 2.1 Konteks pengguna

Pengguna menjalankan beberapa tanggung jawab secara bersamaan: -
Mahasiswa. - Pengemudi ShopeeFood dengan pemasukan yang berubah-ubah. -
Asisten dosen untuk satu kelas. - Asisten laboratorium untuk empat
kelas. - Asisten dosen yang membantu koreksi esai untuk tujuh kelas. -
Penghuni kost. - Memiliki janji dan tanggung jawab pribadi lainnya.

Pengguna memeriksa jadwal harian, kemudian memilih pekerjaan berdasarkan
deadline, tingkat kesulitan, dan pertimbangan lain. Informasi yang
diperlukan untuk menentukan prioritas tersebar di sistem akademik,
WhatsApp, teman, dan catatan.

### 2.2 Masalah inti

1.  **Informasi tersebar dan sulit ditemukan kembali.** Pesan, tautan,
    PDF, foto, dan instruksi tersimpan di banyak percakapan dan sumber.
    Pesan bisa tenggelam; pengirim juga dapat menghapus file sebelum
    pengguna menyimpannya.
2.  **Capture terlalu merepotkan.** Pengguna enggan mengisi banyak kolom
    atau tabel melalui ponsel. Akibatnya, informasi dibaca tetapi tidak
    dicatat.
3.  **Daftar tugas tidak memiliki konteks yang cukup.** Daftar yang
    hanya berisi nama tugas tidak cukup membantu pengguna mengingat
    deadline, mata kuliah, sumber instruksi, atau status informasi.
4.  **Tanggung jawab saling bersaing.** Saat kebutuhan finansial
    mendesak, waktu dialihkan untuk bekerja dan tugas lain terabaikan.
    Ketika pengguna kembali mengerjakan tugas, pekerjaan dapat menumpuk.
5.  **Kondisi keuangan kurang terukur.** Pengguna biasanya mengecek
    saldo bank, tidak mencatat transaksi secara rutin, dan memperkirakan
    uang tunai. Tagihan dan kebutuhan mendatang perlu dibandingkan
    dengan saldo yang tersedia.
6.  **Informasi yang belum lengkap mudah terlupakan.** Pengguna
    memerlukan cara menyimpan informasi sekarang dan memeriksanya nanti,
    tanpa dipaksa melengkapi seluruh detail saat menyimpan.

### 2.3 Siklus masalah

Kebutuhan finansial mendesak → waktu dialihkan untuk mencari pemasukan →
tugas dan informasi akademik kurang diperhatikan → pekerjaan menumpuk →
pengguna harus mengalihkan waktu dari tanggung jawab lain → siklus
berulang.

Aplikasi tidak dapat menciptakan waktu tambahan atau menyelesaikan
kekurangan dana dengan sendirinya. Aplikasi harus membantu pengguna
melihat kewajiban, mengurangi kehilangan informasi, dan membuat
keputusan berdasarkan kondisi yang diketahui.

## 3. Visi Produk

**Membuat kehidupan sehari-hari lebih tertata dengan mengurangi usaha
untuk menyimpan, menemukan, mengingat, dan menindaklanjuti informasi.**

### 3.1 Pernyataan nilai

> Simpan dengan cepat, temukan kembali tanpa membongkar banyak aplikasi,
> dan pahami apa yang perlu diperhatikan berikutnya.

### 3.2 Sasaran jangka panjang

-   Menjadi tempat utama untuk mencari informasi penting yang sebelumnya
    tersebar.
-   Membantu pengguna mempertahankan kesadaran terhadap deadline,
    agenda, rutinitas, dan tagihan.
-   Membantu pengguna memahami saldo terkonfirmasi, kewajiban, dan
    target pendapatan yang dibutuhkan.
-   Memberikan rekomendasi yang realistis dan transparan berdasarkan
    data yang tersedia.

## 4. Tujuan Produk dan Non-Goals

### 4.1 Tujuan MVP

1.  Memungkinkan pengguna menyimpan teks dan tautan dengan sedikit
    langkah.
2.  Menyimpan konteks sumber, seperti nama grup atau mata kuliah.
3.  Menemukan kembali informasi melalui pencarian kata kunci dan
    metadata.
4.  Menghubungkan informasi dengan tugas tanpa menciptakan duplikasi
    secara otomatis.
5.  Menampilkan agenda hari ini dan maksimal tiga deadline terdekat.
6.  Mengingatkan deadline, tindak lanjut informasi, dan rutinitas.
7.  Menyediakan saldo terkonfirmasi, tagihan, uang bebas estimasi, dan
    target pendapatan harian.
8.  Tetap dapat digunakan untuk fungsi inti saat offline.
9.  Memungkinkan backup lokal dan pemulihan data pada tahap validasi
    MVP.

### 4.2 Non-goals MVP

-   Menggantikan WhatsApp atau membaca semua percakapan WhatsApp secara
    otomatis.
-   Mengambil isi file atau pesan yang sudah dihapus dari aplikasi
    sumber.
-   Mengunduh otomatis semua foto dan dokumen dari Google Drive.
-   Sinkronisasi cloud multi-perangkat.
-   Login, akun pengguna, kolaborasi tim, atau berbagi data antar
    pengguna.
-   Aplikasi akuntansi lengkap atau pencatatan transaksi wajib.
-   Prediksi pendapatan ShopeeFood yang dianggap pasti.
-   AI berbayar atau layanan AI eksternal sebagai ketergantungan wajib.
-   Integrasi otomatis dengan rekening bank atau e-wallet.
-   Sistem kalender penuh dengan fitur kolaborasi kompleks.
-   Dashboard statistik yang padat.
-   Monetisasi atau langganan untuk penggunaan pribadi.

## 5. Prinsip Produk dan UX

1.  **Capture first, organize later.** Informasi dapat disimpan walau
    belum lengkap.
2.  **Friction rendah.** Formulir tidak boleh panjang dan tidak ada
    kewajiban mengisi semua kolom untuk menyimpan informasi dasar.
3.  **Informasi bukan otomatis tugas.** Item yang disimpan tidak
    otomatis masuk ke daftar pekerjaan.
4.  **Search over navigation.** Pengguna dapat mencari tanpa harus
    mengingat lokasi penyimpanan.
5.  **Konteks dipertahankan.** Sumber, grup, mata kuliah, dan tautan
    asal dapat disimpan bila tersedia.
6.  **Offline-first.** Database lokal adalah sumber data utama MVP.
7.  **Dashboard tenang.** Beranda hanya menampilkan informasi yang
    membantu pengguna mengambil tindakan sekarang.
8.  **Rekomendasi transparan.** Sistem menjelaskan alasan sebuah tugas
    ditampilkan sebagai prioritas.
9.  **Tidak menghukum data yang tidak lengkap.** Pengguna boleh
    menyimpan informasi tanpa deadline dan melengkapinya nanti.
10. **Transaksi opsional.** Pengguna dapat memperbarui saldo aktual
    tanpa harus mencatat semua pengeluaran.
11. **Tidak mengarang kepastian.** Estimasi saldo, target pendapatan,
    dan rekomendasi harus dibedakan dari fakta terkonfirmasi.
12. **Tidak ada ketergantungan wajib pada layanan berbayar.**

## 6. Pengguna dan Skenario Utama

### 6.1 Persona utama

Pengguna tunggal dengan banyak peran dan tanggung jawab. Ia memakai
Android sebagai perangkat utama, menerima informasi dari banyak sumber,
dan membutuhkan aplikasi yang cepat, tidak penuh statistik, serta tidak
menuntut pencatatan manual yang rumit.

### 6.2 Skenario penggunaan

**Skenario A --- Menerima instruksi tugas** 1. Pengguna menerima pesan
atau tautan terkait tugas. 2. Pengguna membagikan teks/tautan ke
Personal Life Hub atau menempelkannya. 3. Aplikasi mengusulkan judul,
konteks, dan deadline jika dapat dikenali. 4. Pengguna memeriksa hasil
dan menyimpan. 5. Jika deadline tidak diketahui, pengguna menandai item
untuk diperiksa nanti dan dapat mengatur pengingat. 6. Pengguna dapat
menghubungkan item ke tugas yang sudah ada atau membuat tugas baru.

**Skenario B --- Mencari informasi lama** 1. Pengguna mengetik kata
kunci, nama mata kuliah, nama grup, atau judul. 2. Aplikasi menampilkan
item tersimpan yang cocok. 3. Pengguna membuka detail, menyalin tautan,
atau membuka sumber jika masih tersedia.

**Skenario C --- Kembali setelah bekerja** 1. Pengguna membuka aplikasi
setelah sesi kerja. 2. Aplikasi menampilkan agenda berikutnya, tiga
deadline terdekat, item yang perlu ditindaklanjuti, dan ringkasan
keuangan. 3. Pengguna memilih pekerjaan yang realistis untuk
dilanjutkan.

**Skenario D --- Memeriksa kondisi keuangan** 1. Pengguna melihat saldo
terakhir yang dikonfirmasi. 2. Pengguna mencatat tagihan yang belum
dibayar. 3. Aplikasi menghitung estimasi uang bebas setelah kewajiban
yang diketahui. 4. Aplikasi menghitung target pendapatan rata-rata
berdasarkan kekurangan dana dan hari kerja yang tersedia. 5. Pengguna
dapat mengoreksi saldo tanpa harus merekam seluruh transaksi.

**Skenario E --- Menjalankan rutinitas kost** 1. Pengguna membuat
rutinitas, misalnya bersih-bersih kost setiap tiga hari. 2. Aplikasi
mengingatkan ketika rutinitas jatuh tempo. 3. Ketika pengguna menandai
selesai, riwayat pelaksanaan disimpan dan tanggal berikutnya dihitung.

## 7. Ruang Lingkup Fungsional MVP

Prioritas: - **P0:** wajib untuk MVP. - **P1:** penting, tetapi dapat
diselesaikan setelah alur P0 stabil. - **P2:** ditunda sampai ada bukti
kebutuhan dan waktu pengembangan.

### 7.1 Beranda

**P0** - Menampilkan agenda hari ini. - Menampilkan maksimal tiga
deadline terdekat. - Menampilkan ringkasan saldo terakhir yang
dikonfirmasi. - Menampilkan estimasi uang bebas setelah kewajiban yang
tercatat. - Menyediakan akses cepat ke Tambah dan Cari. - Menampilkan
status atau jumlah item yang perlu diperiksa.

**P1** - Rekomendasi pekerjaan berikutnya dengan alasan yang terlihat. -
Pengingat untuk meninjau tugas setelah waktu kerja. - Ringkasan
rutinitas yang jatuh tempo.

**Aturan** - Jangan memenuhi beranda dengan semua tugas dan statistik. -
Deadline yang tidak diketahui tidak boleh diperlakukan seolah-olah
memiliki tanggal. - Tanggal saldo terakhir diperbarui harus terlihat.

### 7.2 Penyimpanan informasi (Saved Items / Inbox)

**P0** - Menambah catatan teks. - Menyimpan tautan. - Menerima teks atau
tautan melalui Android Share Intent/Share Sheet. - Menyimpan judul, isi
yang diterima, waktu penyimpanan, dan metadata sumber bila tersedia. -
Mendukung status `Perlu diperiksa`. - Menyunting dan menghapus item. -
Menghubungkan item dengan tugas yang ada. - Menyimpan informasi tanpa
memaksa pengguna membuat tugas.

**P1** - Deteksi judul dan tanggal dari teks. - Saran penggabungan
dengan tugas yang sudah ada. - Pengingat untuk memeriksa item. -
Dukungan lampiran lokal yang dipilih pengguna.

**Batasan** - Data yang diterima dari Share Sheet bergantung pada apa
yang disediakan aplikasi sumber. - Aplikasi tidak dapat menjamin
menerima teks lengkap dari sebuah bubble chat. - Menyimpan tautan bukan
berarti menyimpan isi file pada tautan tersebut.

### 7.3 Pencarian universal

**P0** - Mencari judul, isi teks tersimpan, konteks sumber, dan URL. -
Filter sederhana berdasarkan tipe item, mata kuliah/konteks, dan status
review jika metadata tersedia. - Membuka detail item dan menyalin
tautan.

**P1** - Pencarian yang mendukung ejaan tidak persis atau tokenisasi
yang lebih baik. - Filter berdasarkan rentang tanggal. - Pencarian isi
dokumen yang secara eksplisit diimpor dan disimpan lokal.

**Non-goal** - Pencarian semua riwayat WhatsApp atau file perangkat yang
tidak pernah diimpor ke aplikasi.

### 7.4 Tugas

**P0** - Membuat, menyunting, menyelesaikan, membatalkan, dan melihat
tugas. - Field minimal: judul dan status. - Field opsional: deadline,
kategori, estimasi durasi, catatan, prioritas, sumber instruksi. -
Menghubungkan satu atau lebih Saved Items. - Menandai informasi sebagai
belum lengkap atau perlu diperiksa. - Mengurutkan tugas berdasarkan
deadline dan status.

**Status tugas** - `needs_review` - `todo` - `in_progress` - `done` -
`cancelled`

**P1** - Deteksi kemungkinan duplikat saat menghubungkan informasi. -
Estimasi beban kerja berdasarkan durasi yang diisi pengguna. -
Rekomendasi urutan pekerjaan.

### 7.5 Agenda

**P0** - Menyimpan kegiatan dengan tanggal dan waktu mulai. - Mendukung
waktu selesai opsional. - Menampilkan agenda hari ini. - Menghubungkan
event dengan sumber informasi jika relevan.

**P1** - Pengulangan jadwal. - Tampilan mingguan sederhana.

**Non-goal** - Sinkronisasi kalender eksternal pada MVP.

### 7.6 Pengingat dan notifikasi

**P0** - Pengingat deadline. - Pengingat item yang perlu diperiksa. -
Pengingat tagihan. - Pengingat rutinitas. - Pengingat untuk kembali
meninjau daftar tugas setelah kerja, pada waktu yang dipilih pengguna. -
Pengingat dapat diaktifkan/dinonaktifkan dan dijadwalkan ulang. -
Menangani izin notifikasi Android dengan jelas.

**P1** - Preset pengingat berdasarkan jenis item. - Pengulangan yang
lebih fleksibel.

**Aturan** - Jadwal pengingat harus disimpan di database, lalu
disinkronkan dengan penjadwal notifikasi OS. - Ketika item diubah atau
dihapus, pengingat terkait harus diperbarui atau dibatalkan. - Saat
aplikasi dibuka kembali, status tugas dan pengingat yang lewat harus
tetap terlihat. - Notifikasi tidak boleh terlalu agresif secara default.

### 7.7 Keuangan

#### Akun dan saldo

**P0** - Membuat akun seperti rekening bank dan uang tunai. - Menyimpan
saldo awal atau saldo terakhir yang dikonfirmasi. - Memperbarui saldo
secara manual kapan pun diperlukan. - Menampilkan waktu pembaruan
saldo. - Mencatat penyesuaian saldo agar perubahan dapat ditelusuri. -
Memungkinkan transaksi dicatat secara opsional.

#### Tagihan

**P0** - Membuat tagihan dengan nama, nominal, dan tanggal jatuh
tempo. - Menandai tagihan sebagai dibayar. - Menampilkan tagihan
mendatang dan terlambat. - Mendukung pembayaran berulang sederhana jika
waktu memungkinkan.

#### Uang bebas dan target pendapatan

**P0** - Menghitung saldo terkonfirmasi gabungan dari akun. - Mengurangi
kewajiban yang belum dibayar untuk memperkirakan uang bebas. -
Menghitung target pendapatan rata-rata berdasarkan kekurangan dana dan
hari kerja yang tersedia. - Menunjukkan asumsi dan data yang
digunakan. - Memungkinkan pengguna mengatur jumlah hari kerja yang
tersedia.

**Aturan perhitungan** -
`confirmed_total = sum(latest_confirmed_balance_per_account)` -
`known_unpaid_bills = sum(amount of bills that are not paid)` -
`estimated_free_money = confirmed_total - known_unpaid_bills` -
`funding_gap = max(0, upcoming_obligations - available_funds - confirmed_income_before_due_date)` -
`daily_income_target = funding_gap / available_workdays_before_due_date`

Keterangan: - Perhitungan harus menghindari pengurangan tagihan yang
sama dua kali. - Pemasukan yang belum pasti tidak boleh dianggap
terkonfirmasi. - Jika hari kerja tersedia nol atau tidak diketahui,
aplikasi harus meminta input atau menyatakan target belum bisa dihitung,
bukan membagi dengan nol. - Estimasi uang bebas bukan saldo bank
aktual. - Transaksi opsional dan koreksi saldo harus memiliki aturan
yang jelas agar tidak terjadi penghitungan ganda.

**P1** - Riwayat ringkas penyesuaian saldo. - Kategori pengeluaran
opsional. - Dukungan tagihan berulang yang lebih fleksibel.

**Non-goal** - Integrasi bank/e-wallet otomatis. - Wajib mencatat setiap
transaksi. - Grafik statistik keuangan yang padat.

### 7.8 Rutinitas

**P0** - Membuat rutinitas. - Menentukan interval atau jadwal. -
Menandai pelaksanaan selesai. - Menyimpan riwayat pelaksanaan. -
Menampilkan waktu terakhir dilakukan dan waktu berikutnya. -
Menjadwalkan pengingat.

**P1** - Pola jadwal mingguan tertentu, misalnya Senin dan Kamis. -
Menunda satu kejadian tanpa mengubah pola rutinitas utama.

### 7.9 Backup dan pemulihan

**P0 sebelum rilis stabil** - Mengekspor data lokal ke file backup. -
Memulihkan backup dari file yang dibuat aplikasi. - Memvalidasi struktur
file dan versi skema. - Memberi peringatan sebelum proses restore
menimpa data yang ada.

**P1** - Backup terjadwal manual dengan pengingat. - Ekspor data
teks/CSV untuk jenis data yang sesuai.

**Aturan** - Backup harus menyertakan data relasional dan metadata yang
diperlukan. - Jika ada file lokal yang dikelola aplikasi, backup harus
menyertakan file tersebut atau menjelaskan bahwa file tidak
disertakan. - Proses restore harus diuji dengan database kosong dan
database yang sudah berisi data.

## 8. Rekomendasi Prioritas Tugas

Versi awal harus menggunakan aturan deterministik, bukan model AI yang
tidak transparan.

### 8.1 Sinyal yang digunakan

-   Kedekatan deadline.
-   Status tugas dan apakah informasi sudah lengkap.
-   Waktu yang dibutuhkan jika pengguna mengisinya.
-   Jadwal/agenda yang diketahui.
-   Tagihan dan kebutuhan finansial yang mendesak.
-   Apakah tugas menghambat pekerjaan atau anggota kelompok lain.
-   Preferensi pengguna.

### 8.2 Perilaku rekomendasi

-   Deadline yang dekat meningkatkan urgensi.
-   Tagihan yang mendekat dan belum dibayar harus terlihat jelas.
-   Jika informasi tugas belum lengkap, rekomendasikan tindakan
    memeriksa informasi.
-   Jika durasi tugas tidak diketahui, jangan mengarang estimasi.
-   Jika jadwal pengguna tidak lengkap, jangan menyatakan bahwa pengguna
    memiliki waktu luang yang pasti.
-   Rekomendasi harus disertai alasan singkat, misalnya: "Deadline
    besok" atau "Tagihan jatuh tempo dua hari lagi".
-   Pengguna tetap menentukan keputusan akhir.

### 8.3 Batasan

Aplikasi tidak dapat menyelesaikan konflik antara semua tanggung jawab
jika waktu atau uang memang tidak mencukupi. Tujuan rekomendasi adalah
membantu melihat trade-off dan langkah berikutnya, bukan menjamin semua
pekerjaan selesai.

## 9. Model Data Konseptual

### 9.1 Entitas inti

**SavedItem** - `id` - `title` - `content` - `item_type` (note, link,
message, reference, attachment) - `source_name` - `source_context` -
`source_url` - `created_at` - `updated_at` - `review_status` -
`deleted_at` opsional untuk soft delete

**Task** - `id` - `title` - `category` - `deadline` - `status` -
`priority` - `estimated_minutes` - `notes` - `created_at` - `updated_at`

**TaskSavedItem** - `task_id` - `saved_item_id` - `relation_type`

**Event** - `id` - `title` - `start_at` - `end_at` - `location` -
`source_item_id` - `created_at` - `updated_at`

**Account** - `id` - `name` - `account_type` - `opening_balance` -
`created_at` - `updated_at`

**Transaction** - `id` - `account_id` - `amount` - `type` -
`occurred_at` - `note` - `created_at`

**BalanceAdjustment** - `id` - `account_id` - `confirmed_balance` -
`confirmed_at` - `note`

**Bill** - `id` - `title` - `amount` - `due_date` - `status` -
`paid_at` - `recurrence_rule` - `created_at` - `updated_at`

**Routine** - `id` - `title` - `schedule_rule` atau `interval_days` -
`last_completed_at` - `next_due_at` - `is_active`

**RoutineLog** - `id` - `routine_id` - `completed_at` - `note`

**Reminder** - `id` - `target_type` - `target_id` - `scheduled_at` -
`notification_id` - `is_enabled` - `status`

**AppSettings** - Preferensi UI, pola pengingat default, dan konfigurasi
lokal.

### 9.2 Prinsip skema

-   Gunakan ID stabil, misalnya UUID.
-   Simpan waktu dalam format ISO 8601 yang konsisten dan perlakukan
    zona waktu dengan sengaja.
-   Gunakan integer untuk nominal rupiah.
-   Aktifkan foreign key SQLite.
-   Gunakan transaksi database untuk operasi multi-tabel.
-   Gunakan migrasi versi skema.
-   Hindari duplikasi data sumber di banyak tempat; gunakan relasi.
-   Hitung saldo wallet dari saldo terakhir yang dikonfirmasi dan transaksi ledger setelah waktu konfirmasi; pertahankan transaksi lama tanpa menghitungnya ulang.
-   Simpan transfer sebagai dua entri bertaut dan pembayaran bill sebagai expense tertaut agar saldo konsisten.
-   Tetapkan aturan yang jelas untuk menghindari tagihan dihitung dua
    kali.
-   Jangan menyimpan kredensial sensitif karena integrasi akun eksternal
    bukan bagian dari MVP.

## 10. Arsitektur Teknis

### 10.1 Stack yang direkomendasikan

  -----------------------------------------------------------------------
  Komponen                            Pilihan
  ----------------------------------- -----------------------------------
  Framework                           Flutter

  Bahasa                              Dart

  State management                    GetX

  Database lokal                      SQLite melalui paket seperti
                                      `sqflite`

  Preferensi ringan                   `shared_preferences` atau
                                      GetStorage

  Notifikasi                          Plugin notifikasi lokal yang
                                      terpelihara

  Integrasi Share Sheet               Plugin Flutter yang menerima
                                      Android share intents

  Search                              SQL LIKE untuk awal; FTS5 jika
                                      tersedia dan kompatibel

  Backup                              Arsip lokal yang memuat database
                                      dan metadata versi

  Backend                             Tidak diperlukan untuk MVP
  -----------------------------------------------------------------------

Pemilihan versi paket, dukungan Android, kompatibilitas plugin, dan
status pemeliharaan harus diverifikasi pada saat implementasi.

### 10.2 Lapisan aplikasi

1.  **Presentation:** layar Flutter dan GetX controllers.
2.  **Application/use cases:** alur capture, pencarian, pembuatan tugas,
    kalkulasi saldo, penjadwalan pengingat, dan rekomendasi.
3.  **Domain:** entitas dan aturan bisnis yang tidak bergantung pada UI
    atau database.
4.  **Data:** repository, datasource SQLite, dan adapter platform.

Jangan membuat abstraksi berlebihan. Lapisan harus membantu pengujian
dan pemeliharaan, bukan menambah boilerplate tanpa manfaat.

### 10.3 Struktur folder yang disarankan

``` text
lib/
├── app/
│   ├── app.dart
│   ├── routes/
│   └── bindings/
├── core/
│   ├── database/
│   ├── notifications/
│   ├── sharing/
│   ├── search/
│   ├── errors/
│   └── utils/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── data/
│   ├── models/
│   ├── datasources/
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

### 10.4 Prinsip offline-first

-   Database lokal adalah sumber data utama.
-   Fitur inti tidak membutuhkan koneksi internet.
-   Pengingat menggunakan penjadwal lokal OS.
-   Tautan eksternal hanya dapat dibuka jika sumbernya tersedia.
-   Data yang diimpor ke aplikasi harus dapat dicari offline.
-   Tidak ada backend wajib.
-   Backup manual harus tersedia sebelum data pengguna dianggap cukup
    aman untuk pemakaian jangka panjang.

## 11. UX dan Navigasi

### 11.1 Navigasi utama

Struktur yang disarankan: - **Home:** agenda, deadline terdekat,
ringkasan keuangan, tindak lanjut. - **Search:** pencarian universal. -
**Inbox:** item baru dan item yang perlu diperiksa. - **Tasks:** daftar
tugas dan status. - **Finance:** saldo, tagihan, dan target
pendapatan. - **Routines:** aktivitas berulang. - **Settings:**
pengingat, backup, preferensi, dan informasi aplikasi.

Navigasi akhir boleh menggunakan bottom navigation dengan jumlah tab
yang terbatas; fitur yang jarang digunakan ditempatkan di menu atau
halaman sekunder. Jangan menampilkan seluruh modul sebagai kartu besar
di beranda.

### 11.2 Target friksi

Target awal untuk diuji, bukan klaim performa: - Menyimpan teks/tautan
sederhana dalam beberapa detik. - Menemukan informasi melalui satu kolom
pencarian. - Menandai tugas selesai dengan satu tindakan utama. -
Memperbarui saldo melalui satu alur singkat. - Membuat tugas dasar tanpa
mengisi semua field opsional.

### 11.3 Aksesibilitas dan kegunaan

-   Kontrol cukup besar untuk digunakan satu tangan.
-   Kontras teks memadai.
-   Label tombol jelas, tidak hanya ikon.
-   State kosong menjelaskan tindakan berikutnya.
-   Kesalahan input memberikan pesan yang dapat dipahami.
-   Tidak mengandalkan warna saja untuk menunjukkan status.
-   Formulir dapat diselesaikan sebagian dan disimpan.

## 12. Privasi dan Keamanan

-   Data utama disimpan lokal di perangkat.
-   Tidak ada pengiriman data ke server pada MVP.
-   Jangan mencatat data sensitif yang tidak dibutuhkan.
-   Backup lokal dapat berisi informasi pribadi; pengguna harus diberi
    tahu sebelum mengekspor atau memulihkan.
-   Pertimbangkan enkripsi backup pada iterasi berikutnya jika data yang
    disimpan menjadi sensitif.
-   Gunakan penyimpanan aplikasi yang sesuai untuk file lokal.
-   Jangan mengklaim data sepenuhnya aman hanya karena disimpan lokal;
    akses perangkat, backup, dan sistem operasi tetap berpengaruh.
-   Sediakan penghapusan item dan mekanisme backup yang jelas.
-   Jika suatu saat menambah cloud, persyaratan privasi, autentikasi,
    enkripsi, dan kebijakan retensi harus ditinjau ulang.

## 13. Risiko dan Mitigasi

  -----------------------------------------------------------------------
  Risiko                  Dampak                  Mitigasi
  ----------------------- ----------------------- -----------------------
  Capture tetap terlalu   Pengguna tidak          Uji alur Share dan teks
  rumit                   menyimpan informasi     secara langsung;
                                                  minimalkan field wajib

  Share Sheet memberikan  Konteks pesan hilang    Tampilkan data yang
  data terbatas                                   diterima, sediakan edit
                                                  manual dan fallback
                                                  copy-paste

  Pengguna mengira link   Kehilangan akses ke     Bedakan referensi
  berarti file tersimpan  file                    sumber dengan file yang
                                                  benar-benar disimpan
                                                  lokal

  Data saldo tidak akurat Target keuangan         Tampilkan waktu
                          menyesatkan             konfirmasi saldo dan
                                                  status estimasi

  Tagihan dihitung dua    Uang bebas salah        Definisikan aturan
  kali                                            sumber saldo dan
                                                  kewajiban; uji
                                                  kalkulasi

  Notifikasi tidak muncul Deadline terlewat       Uji izin dan perilaku
                                                  OS; tampilkan daftar
                                                  overdue saat aplikasi
                                                  dibuka

  Database rusak atau HP  Data hilang             Ekspor/impor backup
  hilang                                          lokal dan uji restore

  Rekomendasi terlalu     Prioritas tidak         Tampilkan alasan,
  sederhana               realistis               sediakan penyesuaian
                                                  manual, jangan
                                                  mengklaim kepastian

  Fitur berkembang        MVP terlambat dan rumit Pertahankan prioritas
  terlalu luas                                    P0; tunda AI, cloud,
                                                  OCR, dan integrasi
                                                  eksternal

  Pengingat terlalu       Pengguna mengabaikan    Default konservatif dan
  banyak                  notifikasi              kontrol frekuensi
  -----------------------------------------------------------------------

## 14. Metrik Keberhasilan

Karena aplikasi awalnya untuk penggunaan pribadi, metrik dapat diuji
melalui penggunaan nyata dan review mingguan.

### 14.1 Metrik perilaku

-   Waktu rata-rata menyimpan informasi sederhana.
-   Proporsi informasi penting yang berhasil disimpan saat pertama kali
    ditemukan.
-   Waktu yang dibutuhkan untuk menemukan informasi lama.
-   Jumlah informasi yang tersimpan tetapi belum ditinjau.
-   Jumlah deadline terlewat yang disebabkan informasi tidak tercatat.
-   Proporsi tagihan yang diketahui dan ditandai statusnya.
-   Frekuensi pengguna memperbarui saldo terkonfirmasi.
-   Jumlah rutinitas yang dicatat sesuai pelaksanaan.
-   Frekuensi pengguna membuka kembali agenda setelah bekerja.

### 14.2 Kriteria keberhasilan kualitatif

Setelah penggunaan rutin selama beberapa minggu, pengguna dapat menjawab
"ya" untuk: - Saya lebih jarang kehilangan informasi penting. - Saya
bisa menemukan link atau instruksi tanpa membongkar banyak chat. - Saya
lebih jarang lupa deadline. - Saya bisa melihat kewajiban finansial dan
uang yang tersedia. - Aplikasi tidak terasa seperti pekerjaan
administrasi tambahan. - Saya tetap dapat menggunakan informasi inti
tanpa internet.

Jangan menilai keberhasilan hanya berdasarkan banyaknya item yang
dimasukkan atau jumlah layar yang selesai dibuat.

## 15. Rencana Implementasi

### Fase 1 --- Fondasi

-   Buat proyek Flutter dan konfigurasi GetX.
-   Buat navigasi, tema, dan struktur folder.
-   Implementasikan database SQLite, migrasi, repository, dan model.
-   Uji persistensi setelah aplikasi ditutup.

### Fase 2 --- Capture dan pencarian

-   Tambah teks dan tautan.
-   Terima Android Share Intent.
-   Simpan sumber dan konteks.
-   Buat inbox dan status perlu diperiksa.
-   Implementasikan pencarian lokal.
-   Uji alur capture pada aplikasi sumber yang benar-benar digunakan.

### Fase 3 --- Tugas, agenda, dan pengingat

-   CRUD tugas dan agenda.
-   Relasi SavedItem--Task.
-   Pengingat lokal.
-   Tampilan deadline dan item tertunda.
-   Uji pembaruan, penghapusan, dan penjadwalan ulang pengingat.

### Fase 4 --- Keuangan

-   Akun dan saldo terkonfirmasi.
-   Koreksi saldo.
-   Transaksi opsional.
-   Tagihan dan status pembayaran.
-   Uang bebas estimasi.
-   Target pendapatan harian dengan penanganan kasus batas.

### Fase 5 --- Rutinitas dan dashboard terintegrasi

-   Rutinitas dan log pelaksanaan.
-   Beranda dengan agenda, tiga deadline, dan ringkasan keuangan.
-   Rekomendasi berbasis aturan dan alasan yang transparan.
-   Pengingat setelah kerja.

### Fase 6 --- Backup dan validasi

-   Ekspor/impor backup lokal.
-   Pengujian restore.
-   Pengujian offline.
-   Pengujian notifikasi di perangkat target.
-   Perbaikan friksi berdasarkan penggunaan nyata.

### Fase lanjutan --- hanya jika dibutuhkan

-   OCR atau parsing dokumen.
-   Pencarian semantik.
-   Penyimpanan file lokal yang lebih lengkap.
-   Integrasi kalender eksternal.
-   Sinkronisasi cloud.
-   AI untuk ekstraksi informasi yang lebih canggih.

## 16. Rencana Pengujian

### 16.1 Unit tests

-   Perhitungan uang bebas.
-   Target pendapatan dengan jumlah hari kerja berbeda.
-   Status tugas dan perubahan status.
-   Perhitungan tanggal rutinitas berikutnya.
-   Aturan rekomendasi deadline.
-   Validasi data dan aturan duplikasi.

### 16.2 Integration tests

-   Simpan, baca, edit, hapus SavedItem.
-   Hubungkan SavedItem ke Task.
-   Cari berdasarkan judul, isi, dan konteks.
-   Koreksi saldo dan hitung ulang ringkasan.
-   Bayar tagihan dan pastikan tidak lagi dihitung sebagai kewajiban
    belum dibayar.
-   Jadwalkan ulang dan batalkan notifikasi.
-   Ekspor lalu impor backup dan verifikasi relasi.

### 16.3 Manual tests

-   Share teks dari WhatsApp.
-   Share URL dari browser.
-   Paste pesan panjang.
-   Simpan item tanpa deadline.
-   Cari item berdasarkan nama grup dan kata kunci.
-   Gunakan aplikasi dalam mode pesawat.
-   Uji notifikasi setelah perangkat restart jika didukung implementasi.
-   Uji restore di database kosong dan database yang sudah berisi data.

## 17. Asumsi dan Keputusan yang Masih Terbuka

### Asumsi saat ini

-   Android adalah platform utama dan satu-satunya target MVP.
-   Pengguna tunggal.
-   Bahasa utama Indonesia.
-   Data disimpan lokal.
-   Saldo diperbarui secara manual atau melalui koreksi; transaksi
    bersifat opsional.
-   Target pendapatan dihitung dari kewajiban, dana yang tersedia,
    pemasukan terkonfirmasi, dan hari kerja yang tersedia.
-   Tautan dan metadata sumber disimpan; file sumber tidak otomatis
    disalin.
-   Backup lokal menjadi strategi pemulihan awal.

### Keputusan yang perlu divalidasi selama implementasi

-   Apakah target pendapatan menggunakan seluruh kewajiban mendatang
    atau hanya kewajiban dalam rentang tertentu.
-   Cara pengguna menentukan hari kerja yang tersedia.
-   Format dan lokasi backup, termasuk apakah backup perlu dienkripsi.
-   Dukungan file lokal dan batas ukuran.
-   Kualitas parsing deadline dari teks berbahasa Indonesia.
-   Kebutuhan pola rutinitas selain interval harian.
-   Apakah pencarian SQL awal cukup atau perlu FTS5.
-   Jumlah pengingat default yang paling berguna tanpa menimbulkan
    notification fatigue.

Keputusan yang belum terbukti tidak boleh diubah menjadi fitur wajib
hanya karena mudah diimplementasikan.

## 18. Definisi Selesai (Definition of Done)

Sebuah fitur dianggap selesai jika: 1. Kebutuhan dan perilakunya
terdokumentasi. 2. UI memiliki loading, empty, success, dan error states
yang sesuai. 3. Data tersimpan dengan benar dan bertahan setelah
aplikasi ditutup. 4. Validasi dilakukan di lapisan yang tepat. 5. Kasus
offline ditangani. 6. Pengingat dan relasi terkait diperbarui saat data
berubah. 7. Ada pengujian untuk aturan bisnis penting. 8. Tidak ada
field wajib yang tidak diperlukan untuk alur inti. 9. Fitur dapat
digunakan dengan nyaman di perangkat Android target. 10. Tidak ada klaim
bahwa data tersimpan, tersinkron, atau dibackup jika proses tersebut
belum berhasil.

## 19. Ringkasan Keputusan Produk

Personal Life Hub harus dimulai sebagai aplikasi Android lokal-first
yang memecahkan tiga masalah utama: 1. Informasi penting tersebar dan
sulit ditemukan kembali. 2. Tugas, agenda, dan rutinitas kehilangan
visibilitas ketika tanggung jawab saling bersaing. 3. Saldo dan
kewajiban finansial belum terlihat dalam satu ringkasan yang mudah
dipahami.

MVP memprioritaskan capture cepat, pencarian, tugas, agenda, pengingat,
saldo, tagihan, target pendapatan, dan rutinitas. Semua fitur harus
mempertahankan prinsip friksi rendah, data lokal, formulir opsional, dan
rekomendasi transparan.

**Ukuran keberhasilan utamanya adalah berkurangnya informasi yang
hilang, deadline yang terlupakan, dan usaha manual untuk mengelola
kehidupan---bukan jumlah fitur.**
