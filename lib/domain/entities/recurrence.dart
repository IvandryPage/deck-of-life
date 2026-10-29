/// Aturan berulang untuk tugas, acara, dan tagihan (`recurrence_rule`).
///
/// Format teks yang disimpan di SQLite:
///   - `daily`
///   - `weekly`
///   - `monthly:<hari>`  (hari 1-31; "jangkar" agar tanggal 31 tidak melorot
///      menjadi 28 selamanya setelah melewati Februari)
///   - `interval:<hari>`
///   - `weekdays:<hari>,...` (1 = Senin, 7 = Minggu)
enum RecurrenceKind {
  daily('Setiap hari'),
  weekly('Setiap minggu'),
  monthly('Setiap bulan'),
  interval('Setiap N hari'),
  weekdays('Hari tertentu setiap minggu');

  const RecurrenceKind(this.label);
  final String label;
}

class RecurrenceRule {
  const RecurrenceRule(
    this.kind, {
    this.anchorDay,
    this.intervalDays,
    this.weekdays = const [],
  });

  final RecurrenceKind kind;

  /// Hanya untuk [RecurrenceKind.monthly].
  final int? anchorDay;
  final int? intervalDays;
  final List<int> weekdays;

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
    if (v.startsWith('interval:')) {
      final days = int.tryParse(v.substring('interval:'.length));
      if (days == null || days < 1) return null;
      return RecurrenceRule(RecurrenceKind.interval, intervalDays: days);
    }
    if (v.startsWith('weekdays:')) {
      final parsedDays = v
          .substring('weekdays:'.length)
          .split(',')
          .map(int.tryParse)
          .toList();
      if (parsedDays.isEmpty ||
          parsedDays.any((day) => day == null || day < 1 || day > 7)) {
        return null;
      }
      final days = parsedDays.whereType<int>().toSet().toList()..sort();
      return RecurrenceRule(RecurrenceKind.weekdays, weekdays: days);
    }
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
    RecurrenceKind.interval => 'interval:${intervalDays ?? 1}',
    RecurrenceKind.weekdays => 'weekdays:${([...weekdays]..sort()).join(',')}',
  };

  String get label => switch (kind) {
    RecurrenceKind.interval => 'Setiap ${intervalDays ?? 1} hari',
    RecurrenceKind.weekdays =>
      weekdays
          .map(
            (day) => const [
              'Sen',
              'Sel',
              'Rab',
              'Kam',
              'Jum',
              'Sab',
              'Min',
            ].elementAt(day - 1),
          )
          .join(', '),
    _ => kind.label,
  };

  /// Kemunculan berikutnya setelah [from], dengan jam yang sama. Memakai
  /// aritmetika kalender (bukan +24 jam) sehingga aman pada pergantian bulan,
  /// tahun, dan tahun kabisat.
  DateTime next(DateTime from) {
    switch (kind) {
      case RecurrenceKind.daily:
        return DateTime(
          from.year,
          from.month,
          from.day + 1,
          from.hour,
          from.minute,
        );
      case RecurrenceKind.weekly:
        return DateTime(
          from.year,
          from.month,
          from.day + 7,
          from.hour,
          from.minute,
        );
      case RecurrenceKind.weekdays:
        final days = weekdays.where((day) => day >= 1 && day <= 7).toSet();
        if (days.isEmpty) {
          return DateTime(
            from.year,
            from.month,
            from.day + 7,
            from.hour,
            from.minute,
          );
        }
        for (var offset = 1; offset <= 7; offset++) {
          final candidate = DateTime(
            from.year,
            from.month,
            from.day + offset,
            from.hour,
            from.minute,
          );
          if (days.contains(candidate.weekday)) return candidate;
        }
        return DateTime(
          from.year,
          from.month,
          from.day + 7,
          from.hour,
          from.minute,
        );
      case RecurrenceKind.interval:
        final days = intervalDays ?? 1;
        return DateTime(
          from.year,
          from.month,
          from.day + days,
          from.hour,
          from.minute,
        );
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
