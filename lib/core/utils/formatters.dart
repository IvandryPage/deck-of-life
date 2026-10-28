import 'package:intl/intl.dart';

/// Format tampilan. Membutuhkan `initializeDateFormatting('id_ID')` di main().
class Formatters {
  const Formatters._();

  static final NumberFormat _rupiah = NumberFormat.decimalPattern('id_ID');
  static final DateFormat _date = DateFormat('d MMM yyyy', 'id_ID');
  static final DateFormat _dateShort = DateFormat('EEE, d MMM', 'id_ID');
  static final DateFormat _time = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  /// Nominal integer rupiah. Nilai negatif ditampilkan sebagai kekurangan.
  static String rupiah(int value) {
    final abs = _rupiah.format(value.abs());
    return value < 0 ? '-Rp $abs' : 'Rp $abs';
  }

  static String date(DateTime value) => _date.format(value.toLocal());
  static String dateShort(DateTime value) => _dateShort.format(value.toLocal());
  static String time(DateTime value) => _time.format(value.toLocal());
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  /// Mengurai input nominal ("1.500.000", "Rp 1500000") menjadi integer.
  /// Mengembalikan null bila tidak ada digit.
  static int? parseRupiah(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }
}
