# Deck of Life — Audit & Redesign UX/UI

> **Belum dijalankan.** Lingkungan pembuat tidak punya Flutter/Dart SDK: `flutter analyze`, `flutter test`,
> build, dan uji layar/overflow **tidak pernah dijalankan**. Yang dilakukan: pemeriksaan statis
> (kurung seimbang, semua import relatif ada, tidak ada rujukan ke berkas yang dihapus). Perkirakan beberapa
> perbaikan kecil saat pertama kali dikompilasi.

## 1. Temuan awal

| Prioritas | Temuan |
|---|---|
| P0 | Kalender tidak ada sebagai menu; agenda hanya daftar "mendatang" di rute terpisah. |
| P0 | Catat transaksi memakai dialog berisi 5 kolom generik; nominal bukan fokus. |
| P1 | Tema hanya `ColorScheme.fromSeed`, tanpa token; warna/angka tersebar di halaman. |
| P1 | Tugas: satu daftar datar; tidak ada kelompok Terlambat/Hari ini/Mendatang, tidak ada Urungkan. |
| P1 | Loading = spinner kosong; kartu bersarang dengan border dan bayangan seragam. |
| P2 | Tanpa animasi bermakna; tanpa riwayat/filter/cari transaksi; tanpa lencana informasi di navigasi. |

## 2. Keputusan arsitektur informasi

Permintaan awal: empat menu (Home, Financial, Task, Calendar). Pesan lanjutan Anda meminta **informasi juga masuk
ke bottom nav**. Saya menafsirkannya dua arah dan memenuhi keduanya:

1. **Informasi (Kotak masuk / item tersimpan) menjadi tab kelima**: Beranda · Keuangan · Tugas · Kalender · Informasi.
   Ini menyimpang dari aturan "jangan menambah menu kelima"; bila ingin tepat empat, tab Informasi bisa
   dipindah menjadi halaman dari Beranda (`ShellPage` + `ShellController.tabInfo`, perubahan kecil).
2. **Lencana angka pada ikon navigasi**: Keuangan = tagihan terlambat, Tugas = tugas terlambat, Kalender = agenda
   hari ini, Informasi = item perlu diperiksa. Angka juga masuk label aksesibilitas (bukan hanya warna).

Label tetap berbahasa Indonesia (Beranda/Keuangan/Tugas/Kalender/Informasi) agar konsisten dengan seluruh aplikasi.

## 3. Design system

- `lib/app/design/tokens.dart`: spacing (4–32), radius, ukuran komponen (tap 48dp), ikon, elevasi (nyaris datar),
  motion (micro 140 ms / standard 220 ms / emphasized 300 ms + kurva), tipografi (font sistem, minimum 12sp, angka tabular),
  warna semantik (masuk, keluar, peringatan, sukses, mendesak) untuk light & dark.
- `lib/app/theme.dart`: seluruh `ThemeData` dari token (kartu datar bergaris tipis, input terisi, tombol ≥48dp, bottom sheet 28dp,
  navigasi M3 dengan indikator, transisi halaman fade).
- Tanpa dependensi baru. Font sistem dipilih (offline-first, tanpa unduhan); hierarki dibuat lewat ukuran/bobot.
- Hormati "reduce motion" lewat `AppMotion.of(context, …)` (durasi 0 bila animasi sistem dimatikan).

## 4. Perubahan per menu

- **Beranda**: header kontekstual (salam + tanggal), simpan cepat, 4 aksi cepat (Transaksi/Tugas/Agenda/Tagihan; form ringkas),
  kartu "Lakukan berikutnya", snapshot keuangan (saldo terkonfirmasi, tagihan belum dibayar, uang bebas estimasi, kesenjangan),
  agenda hari ini, maks 3 tugas prioritas dengan selesai satu ketuk + Urungkan, rutinitas, pengingat backup. Skeleton saat memuat.
- **Keuangan**: saldo terkonfirmasi sebagai angka utama, rincian terlambat/horizon/lebih jauh, FAB "Transaksi" (sheet dengan nominal
  sebagai fokus, kategori sekali ketuk, tanggal, akun, catatan opsional), riwayat dengan **cari + filter jenis**, ringkasan
  masuk/keluar bulan ini (berlabel "dari transaksi yang dicatat"), distribusi kategori berlabel + persen, baris transaksi bertanda +/− dan ikon.
- **Tugas**: tambah cepat satu kolom, kelompok Terlambat / Hari ini / Mendatang / Tanpa deadline, filter Aktif/Selesai/Semua,
  Urungkan penyelesaian (juga membatalkan kemunculan berikutnya pada tugas berulang), baris dengan tag teks "Terlambat"/"Berulang".
- **Kalender** (baru): grid bulan (Senin pertama), penanda titik, hari ini bercincin, geser antarbulan beranimasi, daftar hari terpilih
  berisi agenda (status Berlangsung/Selesai), deadline tugas, dan tagihan jatuh tempo; tambah agenda pada hari terpilih.
- **Informasi**: tetap Kotak masuk (filter, arsip), kini dengan skeleton dan lencana.
- Rute `/agenda` lama dihapus (digantikan tab Kalender; tidak ada fitur yang hilang).

## 5. Komponen & motion

`SectionCard` (datar), `SectionHeader`, `StatusTag` (nada neutral/urgent/warning/success), `AmountText` (tabular, mengecil bila panjang),
`EmptyState` (ringkas/penuh), `SkeletonBox`/`SkeletonList`, `FadeSlideIn`, `AppToast.undoable`, `TaskTile` baru, `TransactionSheet`.
Motion: transisi halaman, geser bulan, ganti filter (AnimatedSwitcher), expand riwayat (AnimatedSize), bar kategori, indikator navigasi, pemilihan tanggal.
Tidak ada animasi tak terbatas selain denyut skeleton (dimatikan bila reduce-motion).

## 6. Berkas penting

Baru: `app/design/tokens.dart`, `features/calendar/*`, `features/finance/widgets/transaction_sheet.dart`, `…/account_dialog.dart`, `test/ui_components_test.dart`.
Diubah: `app/theme.dart`, `app/app.dart`, `core/widgets/common_widgets.dart`, `features/shell/*`, `features/home/*`, `features/tasks/*`,
`features/finance/*`, `features/search/pages/search_page.dart`, `features/agenda/pages/event_form_page.dart` (menerima hari terpilih),
`usecases.dart` (`undoDone`), `date_time_utils.dart`. Dihapus: `features/agenda/{pages/agenda_page,controllers,bindings}`.
Logika bisnis, skema, dan backup tidak berubah.

## 7. Pengujian

Ditulis, **belum dijalankan**: `ui_components_test.dart` (tema/token, EmptyState, AmountText, StatusTag, skeleton + reduce-motion, TaskTile
terlambat/centang/teks 2×/judul panjang, pengelompokan tugas), tes `CalendarController` di `recovery_db_test.dart`. Tes lama tetap berlaku.

## 8. Keterbatasan & prioritas berikutnya

- Belum ada: pemasukan/pengeluaran **hari ini** di Beranda (transaksi bersifat opsional/pencatatan, bukan sumber saldo); tampilan minggu;
  grafik tren; animasi hitung angka (sengaja tidak dipakai).
- Layout belum diuji di perangkat: periksa overflow pada layar kecil/teks besar, keyboard di sheet transaksi, dan perilaku tab Informasi.
- Tata letak form sudah dirapikan (lihat §9) tetapi belum pernah dilihat di layar nyata.
- Dark mode memakai token yang sama tetapi belum dicek kontrasnya dengan alat ukur.

## 9. Perapihan form (iterasi lanjutan)

Pola seragam di semua form: **field utama terlihat, sisanya di balik tombol teks kecil "Opsi lanjutan"** (`AdvancedOptions`),
dan tombol Simpan selalu di dasar halaman tepat di atas keyboard (`FormPage`). Opsi lanjutan terbuka otomatis bila sudah ada isian
lanjutan (mis. saat mengubah).

| Form | Terlihat | Di "Opsi lanjutan" |
|---|---|---|
| Tugas | judul, deadline, pengingat (bila ada deadline) | prioritas, status, ulangi, catatan, mata kuliah, grup, jenis, durasi, langkah berikutnya, sumber & lokasi instruksi |
| Agenda | judul, mulai, pengingat | selesai, jenis, lokasi, catatan |
| Informasi | isi/tautan | perlu diperiksa, judul, jenis, tautan, sumber, mata kuliah, grup, konteks, pengingat periksa |
| Tagihan | nominal (besar), nama, jatuh tempo | ulangi, pengingat, catatan |
| Rutinitas | nama, pola, interval/hari, ingatkan | jam, aktif, catatan |
| Dialog isian (saldo, dll.) | field wajib | field bertanda `advanced` (mis. alasan koreksi) |

Garis luar field kini hanya dari tema (tidak ada lagi `OutlineInputBorder` yang menimpa), dan jarak antar-field memakai token.
Tes widget `AdvancedOptions`/`FormPage` ditulis, belum dijalankan.
