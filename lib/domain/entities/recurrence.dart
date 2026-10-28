/// Aturan berulang untuk tugas dan tagihan (kolom `recurrence_rule`).
///
/// Format teks yang disimpan di SQLite:
///   - `daily`
///   - `weekly`
///   - `monthly:<hari>`  (hari 1-31; "jangkar" agar tanggal 31 tidak melorot
///      menjadi 28 selamanya setelah melewati Februari)
///
/// Rutinitas memakai kolom tersendiri (`routines`) dan tidak lewat kelas ini.
enum RecurrenceKind {
  daily('Setiap hari'),
  weekly('Setiap minggu'),
  monthly('Setiap bulan');

  const RecurrenceKind(this.label);
  final String label;
}

class RecurrenceRule {
  const RecurrenceRule(this.kind, {this.anchorDay});

  final RecurrenceKind kind;

  /// Hanya untuk [RecurrenceKind.monthly].
  final int? anchorDay;

  /// Membuat aturan dari pilihan pengguna; jangkar bulanan diambil dari [due].
  factory RecurrenceRule.forDue(RecurrenceKind kind, DateTime due) =>
      RecurrenceRule(
        kind,
        anchorDay: kind == RecurrenceKind.monthly ? due.day : null,
      );

  /// Mengembalikan null untuk nilai kosong atau tidak dikenal (diperlakukan
  /// sebagai tidak berulang, bukan error, agar data lama/aneh tidak merusak layar).
  static RecurrenceRule? tryParse(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v == 'daily') return const RecurrenceRule(RecurrenceKind.daily);
    if (v == 'weekly') return const RecurrenceRule(RecurrenceKind.weekly);
    if (v.startsWith('monthly')) {
      final parts = v.split(':');
      final day = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (day != null && (day < 1 || day > 31)) return null;
      return RecurrenceRule(RecurrenceKind.monthly, anchorDay: day);
    }
    return null;
  }

  String get encoded => switch (kind) {
        RecurrenceKind.daily => 'daily',
        RecurrenceKind.weekly => 'weekly',
        RecurrenceKind.monthly =>
          anchorDay == null ? 'monthly' : 'monthly:$anchorDay',
      };

  String get label => kind.label;

  /// Kemunculan berikutnya setelah [from], dengan jam yang sama. Memakai
  /// aritmetika kalender (bukan +24 jam) sehingga aman pada pergantian bulan,
  /// tahun, dan tahun kabisat.
  DateTime next(DateTime from) {
    switch (kind) {
      case RecurrenceKind.daily:
        return DateTime(from.year, from.month, from.day + 1, from.hour, from.minute);
      case RecurrenceKind.weekly:
        return DateTime(from.year, from.month, from.day + 7, from.hour, from.minute);
      case RecurrenceKind.monthly:
        var year = from.year;
        var month = from.month + 1;
        if (month > 12) {
          month = 1;
          year++;
        }
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final wanted = anchorDay ?? from.day;
        final day = wanted > daysInMonth ? daysInMonth : wanted;
        return DateTime(year, month, day, from.hour, from.minute);
    }
  }

  /// Kemunculan pertama setelah [from] yang juga jatuh setelah [notBefore].
  /// Dipakai untuk tugas: menyelesaikan tugas harian yang terlambat 5 hari tidak
  /// boleh langsung menghasilkan tugas baru yang sudah terlambat 4 hari.
  DateTime nextAfter(DateTime from, DateTime notBefore) {
    var n = next(from);
    // Batas pengaman agar tidak pernah berputar tanpa akhir pada data aneh.
    for (var i = 0; i < 1000 && !n.isAfter(notBefore); i++) {
      n = next(n);
    }
    return n;
  }
}
