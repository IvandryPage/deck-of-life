# Deck of Life — UX Strategy

Oct 28, 2026 · @vnd

Deck of Life menjadi satu tempat harian untuk melihat jadwal, mengejar deadline, menyimpan catatan, dan tahu posisi uang, dengan lima tujuan yang jelas: Home, Calendar, Tasks, Money, Notes.

## 1. Strategy

App ini ada supaya kamu tidak perlu menebak harus membuka aplikasi apa: satu tempat untuk jadwal, deadline, catatan, tugas, dan uang.

- **Pengguna:** kamu sendiri sekarang; nanti mahasiswa yang mau alat yang simpel tapi berguna.
- **Pagi (07:00):** lihat agenda hari ini di paling atas, lalu deadline terdekat, lalu cari catatan.
- **Malam (22:00):** lihat kondisi uang, daftar tugas, lalu perbarui keuangan.
- **Ukuran berhasil:** tahu harus buka apa tanpa berpikir; menangkap sesuatu dalam maksimal dua ketukan; tidak ada yang hilang atau terselip.
- **Bukan tujuan:** dashboard ala admin, kategori/folder untuk catatan, chatbot AI, OCR, cloud sync.

## 2. Scope

Setiap fitur ditentukan nasibnya dari seberapa sering kamu memakainya. Rutinitas dilebur karena isinya (jadwal kuliah, ganti oli, bersih-bersih kost) sebenarnya agenda atau tugas yang berulang.

| Fitur | Dipakai | Keputusan |
| --- | --- | --- |
| Notes (simpan informasi) | Tiap hari | Tetap. Berdiri sendiri, bisa ditautkan ke tugas. Cari kata kunci, terbaru dulu. Tanpa kategori. |
| Tasks | Tiap hari | Tetap. Overdue, Today, Upcoming; ada tugas berulang. |
| Calendar & events | Tiap hari | Tetap (kamu suka). Tambah event berulang untuk jadwal kuliah. |
| Money: wallet & transaksi | Tiap hari bila mencatat | Dibangun ulang: saldo ikut berubah dari transaksi; pemasukan, pengeluaran, transfer; bisa diubah dan dihapus. |
| Money: bills | Sering | Tetap. Dibayar = otomatis jadi pengeluaran; bill berulang membuat bill berikutnya. |
| Routines | Sesekali | Dilebur ke tugas berulang dan event berulang. Tidak ada menu sendiri. |
| Saldo "terkonfirmasi", uang bebas (estimasi), kesenjangan dana, target pemasukan | Tidak dipakai | Keluar dari tampilan utama. Bisa kembali nanti sebagai Insights opsional. |
| Kartu "next action", banner backup | Tidak diminta | Keluar dari Home; backup pindah ke Settings. |

## 3. Structure

**Hubungan antar data.** Satu note bisa berdiri sendiri (tautan Drive foto liburan). Bila perlu, buat tugas lalu tautkan keduanya; satu note bisa ditautkan ke banyak tugas dan sebaliknya (sudah ada di data sekarang).

**Alur menangkap sesuatu:** Share Sheet atau Quick note → masuk ke Notes → (opsional) Make task → tautan otomatis terpasang. Setelah menyimpan, app selalu bilang di mana tersimpan ("Saved to Notes") dan tombol untuk membukanya.

**Aturan uang (perubahan logika, bukan hanya tampilan):**

1. Saldo wallet = saldo terakhir yang kamu tetapkan + semua transaksi setelah saat itu. Data lama aman dan tidak terhitung dua kali.
2. Income menambah, expense mengurangi, dan mengubah atau menghapus transaksi langsung memperbarui saldo.
3. Transfer = dua catatan yang saling terkait (keluar dari wallet A, masuk ke wallet B); total uang tidak berubah.
4. Bill ditandai Paid → kamu pilih wallet (default: wallet terakhir dipakai) → otomatis tercatat satu expense yang tertaut ke bill itu. Undo membatalkan keduanya.
5. Bill berulang (weekly/monthly): saat dibayar, bill berikutnya otomatis dibuat dengan judul dan nominal sama (sudah ada), plus expense dari aturan nomor 4.
6. "Adjust balance" tetap ada untuk koreksi bila kenyataan berbeda, dicatat sebagai satu entri koreksi.

Ini butuh migrasi kecil yang menambah kolom (tautan transfer dan tautan bill di transaksi) tanpa menghapus data.

## 4. Skeleton

**Navigasi (terinspirasi ViTube):** rail tipis di sisi kiri (±48 dp), bukan drawer. Label ditulis vertikal, dibaca dari bawah ke atas: Home · Calendar · Tasks · Money · Notes. Yang aktif ditandai penanda berwarna dan teks tebal; angka kecil menempel di label untuk overdue, bill jatuh tempo, dan event hari ini. Tombol **+** di kanan bawah membuka pilihan cepat: Note, Task, Event, Transaction (default menyesuaikan halaman yang sedang dibuka).

Risiko: teks diputar lebih lambat dibaca sebagian orang, dan rail kiri agak jauh bagi ibu jari kanan. Mitigasi: label pendek, area ketuk panjang, semantik aksesibilitas penuh; bila terasa janggal saat dicoba, rail ini satu komponen yang bisa diganti bottom bar tanpa mengubah halaman lain.

**Home (pagi)**

```
Good morning, <name>            [search] [settings]
Wed, 28 Oct

TODAY                                  
 08:00  Database class        Room 3
 13:00  Group meeting
 (no events -> "Nothing scheduled" + [Add event])

NEXT DEADLINES                         
 [ ] Lab report         Tomorrow 17:00
 [ ] Pay internet bill  Fri
 [ ] Essay draft        Mon        (max 3, Overdue first)

NOTES  [ search notes... ]             
  Holiday photos (Drive link)     2h ago
  Dr. Sari: exam moved            Yesterday
```

**Money (malam)** — urutan sesuai keluhanmu: riwayat di atas, bill dan pengaturan wallet di bawah.

```
Total  Rp 1.250.000
[Cash 250k] [BCA 800k] [ShopeePay 200k]   (swipe)
[+ Income] [+ Expense] [Transfer]

RECENT   [search]  [All|Income|Expense]
  Lunch            -Rp 25.000    Today
  Allowance        +Rp 500.000   Mon
  (tap = edit, swipe = delete + Undo)

BILLS
  Internet  Rp 350.000  due Fri   [Pay]
  Rent      Rp 800.000  1 Nov (repeats monthly)

Wallets  >  Manage wallets / Adjust balance
```

**Tasks:** kolom "Add a task" di atas; bagian Overdue, Today, Upcoming; tab Done. Centang = selesai dengan Undo.

**Calendar:** seperti sekarang (bulan + daftar hari), ditambah event berulang (mis. kuliah tiap Senin 08:00).

**Notes:** kolom pencarian di paling atas; daftar terbaru dulu; buka note untuk melihat tugas tertaut atau menekan Make task. Tidak ada kategori atau folder.

## 5. Surface

**Rasa:** hangat, ramah, ceria ala aplikasi mahasiswa. Light mode saja. Kartu bersudut membulat besar, warna lembut dengan satu warna aksen berani, ilustrasi/emoji kecil di empty state, bukan tampilan dashboard admin.

**Pilihan palet (pilih satu):**

| Opsi | Rasa | Primary | Latar | Aksen |
| --- | --- | --- | --- | --- |
| A. Sunny Peach | hangat, ceria | #F26B3A | #FFF8F0 | #FFC23D |
| B. Fresh Mint | segar, tenang | #1FA37A | #F4FBF7 | #FF8A5B |
| C. Berry Pop | berani, muda | #7A4DE0 | #FBF8FF | #FF6FA5 |
|  |  |  |  |  |

Rekomendasi: **A. Sunny Peach** (paling "hangat dan ceria"). Warna income hijau dan expense merah/oranye tetap dipertahankan agar uang mudah dibaca.

**Font:** (1) font sistem — paling ringan, tanpa tambahan; (2) font bulat ramah (mis. Nunito) yang disertakan di dalam app sehingga tetap offline. Rekomendasi: opsi 2, karena memberi karakter dengan biaya kecil.

**Bahasa UI:** seluruh label dalam English, kalimat pendek dan ramah ("Nothing scheduled today").

**Glosarium istilah:**

| Lama | Baru |
| --- | --- |
| Beranda | Home |
| Keuangan | Money |
| Tugas | Tasks |
| Kalender | Calendar |
| Informasi / Inbox | Notes |
| Akun | Wallet |
| Tagihan | Bills |
| Opsi lanjutan | More options |
| Rutinitas | dihapus; jadi Repeat pada task/event |
| Perlu diperiksa | New (titik kecil), bukan menu sendiri |

**Gerak:** tetap singkat (140/220/300 ms), menghormati reduce-motion.

## 6. Open decisions and build order

**Keputusan yang perlu kamu pilih:**

1. Navigasi: rail vertikal kiri + FAB kanan bawah (seperti di atas), atau bottom bar biasa sebagai cadangan? rail vertikal kiri aja
2. Palet: Gunakan Color Palette Saweria
3. Font: Nunito bawaan app
4. Home setelah jam 18.00: urutan tetap
5. Notes: perlu penanda "New" untuk note yang baru masuk dari Share Sheet dan diurutkan dair yang terbaru
6. Letak Settings dan Backup: Fitur yang detail gini bisa gak sih di vertikal rail aja logo gear
7. Saldo wallet memakai aturan "saldo terakhir + transaksi setelahnya" (bagian 3) — setuju? setuju
8. Pembayaran bill: pakai wallet terakhir namun tetap dapat diubah oleh user

**Urutan pengerjaan setelah kamu setuju:**

1. Mesin uang: migrasi v3 (transfer, tautan bill), aturan saldo, auto-expense dari bill, beserta tes dan verifikasi SQL.
2. Navigasi rail, shell, dan Home baru.
3. Halaman Money (history di atas, bills dan wallet di bawah, transfer).
4. Polesan Notes, Tasks, Calendar; event berulang (jadwal kuliah); menggabungkan Routines.
5. Tema, font, dan penerjemahan seluruh teks ke English.
6. Uji di perangkat.
