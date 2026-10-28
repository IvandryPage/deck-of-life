import 'migration_v1.dart';
import 'migration_v2.dart';

/// Daftar migration berurutan. Indeks 0 = versi 1, indeks 1 = versi 2, dst.
/// Menambah versi = menambah satu entri di akhir; jangan mengubah entri lama
/// dan jangan menghapus/membuat ulang database (TDD bagian 11).
const List<List<String>> migrations = [
  migrationV1,
  migrationV2,
];
