/// Satu-satunya tempat konversi tanggal/waktu (TDD bagian 19, risiko zona waktu).
///
/// Semua waktu disimpan sebagai ISO 8601 dengan offset, mis.
/// `2026-10-26T09:00:00+07:00`, dan dibaca kembali sebagai waktu lokal perangkat.
class DateTimeUtils {
  const DateTimeUtils._();

  static String toIso(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final oh = _two(abs.inHours);
    final om = _two(abs.inMinutes.remainder(60));
    return '${_pad(local.year, 4)}-${_two(local.month)}-${_two(local.day)}'
        'T${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}'
        '$sign$oh:$om';
  }

  static String nowIso() => toIso(DateTime.now());

  static DateTime parse(String value) => DateTime.parse(value).toLocal();

  static DateTime? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  /// Jam yang benar-benar diisi pengguna (bukan 00:00 / 23:59 bawaan "seharian").
  static bool hasMeaningfulTime(DateTime value) {
    final v = value.toLocal();
    final allDay = (v.hour == 23 && v.minute == 59) || (v.hour == 0 && v.minute == 0);
    return !allDay;
  }

  static DateTime startOfDay(DateTime value) {
    final l = value.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// Awal hari berikutnya. Memakai aritmetika kalender (bukan +24 jam) agar
  /// aman pada pergantian DST / zona waktu.
  static DateTime startOfNextDay(DateTime value) {
    final l = value.toLocal();
    return DateTime(l.year, l.month, l.day + 1);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// Selisih hari kalender (bukan selisih 24 jam) dari [from] ke [to].
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Menggabungkan tanggal dengan "HH:mm". Mengembalikan null bila format salah.
  static DateTime? withTime(DateTime date, String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, h, m);
  }

  static String formatHhmm(int hour, int minute) =>
      '${_two(hour)}:${_two(minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _pad(int v, int w) => v.toString().padLeft(w, '0');
}

/// Label tenggat yang tidak mengarang kepastian (PRD bagian 7.1).
class DueLabel {
  const DueLabel._();

  static String of(DateTime? due, {DateTime? now}) {
    if (due == null) return 'Tanpa deadline';
    final n = (now ?? DateTime.now());
    final days = DateTimeUtils.calendarDaysBetween(n, due);
    if (due.isBefore(n) && days <= 0) {
      return days == 0 ? 'Terlambat (hari ini)' : 'Terlambat ${-days} hari';
    }
    if (days == 0) return 'Hari ini';
    if (days == 1) return 'Besok';
    return '$days hari lagi';
  }
}
