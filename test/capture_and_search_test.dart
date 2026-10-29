import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/core/search/search_service.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/domain/usecases/capture.dart';

void main() {
  final now = DateTime(2026, 10, 26);

  group('CaptureSuggester', () {
    test('hanya URL: jenis tautan, judul dari domain', () {
      final s = CaptureSuggester.suggest('https://www.example.com/path?a=1');
      expect(s.type, SavedItemType.link);
      expect(s.url, 'https://www.example.com/path?a=1');
      expect(s.title, 'example.com');
    });

    test('teks singkat + URL: judul dari teks, tanda baca penutup dibuang', () {
      final s = CaptureSuggester.suggest(
        'Tugas kelompok: https://drive.google.com/file/d/abc).',
      );
      expect(s.type, SavedItemType.link);
      expect(s.url, 'https://drive.google.com/file/d/abc');
      expect(s.title, 'Tugas kelompok:');
    });

    test('subject dari aplikasi sumber dipakai sebagai judul', () {
      final s = CaptureSuggester.suggest(
        'https://x.com/a',
        subject: 'Judul dari browser',
      );
      expect(s.title, 'Judul dari browser');
    });

    test('catatan biasa: jenis catatan, judul baris pertama', () {
      final s = CaptureSuggester.suggest(
        'Beli token listrik\nsebelum tanggal 5',
      );
      expect(s.type, SavedItemType.note);
      expect(s.title, 'Beli token listrik');
      expect(s.url, isNull);
    });

    test('teks dari Share Sheet tanpa URL dianggap pesan', () {
      final s = CaptureSuggester.suggest(
        'Besok kumpul laporan jam 10',
        fromShare: true,
      );
      expect(s.type, SavedItemType.message);
    });

    test('pesan panjang berisi URL: jenis pesan, URL tetap diambil', () {
      final long = '${'Instruksi panjang. ' * 20}https://example.com/doc';
      final s = CaptureSuggester.suggest(long);
      expect(s.type, SavedItemType.message);
      expect(s.url, 'https://example.com/doc');
    });

    test('judul dipotong maksimal 80 karakter', () {
      final s = CaptureSuggester.suggest('a' * 200);
      expect(s.title.length, lessThanOrEqualTo(80));
    });

    test('kosong: judul sementara bertanggal dan ditandai sementara', () {
      final s = CaptureSuggester.suggest('   ', now: now);
      expect(s.title, 'New item — Oct 26, 2026');
      expect(s.titleIsPlaceholder, isTrue);
    });
  });

  group('SearchService', () {
    test('tokenize memisahkan kata dan mengabaikan spasi berlebih', () {
      expect(SearchService.tokenize('  basis   data  '), ['basis', 'data']);
      expect(SearchService.tokenize('   '), isEmpty);
    });

    test('escapeLike meloloskan %, _, dan backslash', () {
      expect(SearchService.escapeLike('50%_a'), r'50\%\_a');
      expect(SearchService.escapeLike(r'a\b'), r'a\\b');
    });

    test('query kosong: tanpa filter', () {
      final q = SearchService.build('', ['title']);
      expect(q.where, '1=1');
      expect(q.args, isEmpty);
    });

    test('setiap kata = satu kelompok OR antar kolom, digabung AND', () {
      final q = SearchService.build('basis data', ['title', 'content_text']);
      expect(q.args, ['%basis%', '%basis%', '%data%', '%data%']);
      expect('?'.allMatches(q.where).length, 4);
      expect(q.where, contains(' AND '));
    });

    test('input pengguna tidak pernah masuk ke string SQL', () {
      final q = SearchService.build("x'; DROP TABLE tasks;--", ['title']);
      expect(q.where.contains('DROP'), isFalse);
      expect(q.args.any((a) => (a as String).contains('DROP')), isTrue);
    });
  });
}
