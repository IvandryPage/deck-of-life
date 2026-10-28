/// Klausa SQL `LIKE` dengan parameter binding (TDD bagian 7).
class LikeQuery {
  const LikeQuery(this.where, this.args);

  final String where;
  final List<Object?> args;
}

/// Pembangun query pencarian MVP. FTS5 sengaja ditunda; lihat TDD bagian 7.
class SearchService {
  const SearchService._();

  static List<String> tokenize(String query) => query
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Meloloskan karakter khusus LIKE agar `%` dan `_` dicari apa adanya.
  static String escapeLike(String token) => token
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// Setiap kata harus cocok di salah satu kolom (AND antar kata, OR antar kolom).
  /// [columns] hanya boleh berisi nama kolom dari kode, bukan input pengguna.
  static LikeQuery build(String query, List<String> columns) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const LikeQuery('1=1', []);
    final parts = <String>[];
    final args = <Object?>[];
    for (final token in tokens) {
      final like = '%${escapeLike(token)}%';
      final perColumn = columns
          .map((c) => "COALESCE($c,'') LIKE ? ESCAPE '\\'")
          .join(' OR ');
      parts.add('($perColumn)');
      args.addAll(List<Object?>.filled(columns.length, like));
    }
    return LikeQuery(parts.join(' AND '), args);
  }
}
