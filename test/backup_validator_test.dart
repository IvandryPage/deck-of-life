import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/core/backup/backup_validator.dart';
import 'package:deck_of_life/core/errors/app_exception.dart';

Map<String, Object?> _emptyData() => {
  for (final t in BackupSchema.tables) t: <Object?>[],
};

String _backup({
  Map<String, Object?>? data,
  int schema = 2,
  String format = BackupSchema.formatId,
  bool withChecksum = true,
  String? badChecksum,
}) {
  final d = data ?? _emptyData();
  return jsonEncode({
    'format': format,
    'schema_version': schema,
    'app_version': '1.0.0',
    'exported_at': '2026-10-26T10:00:00+07:00',
    if (withChecksum) 'checksum': badChecksum ?? BackupSchema.checksumOf(d),
    'data': d,
  });
}

Map<String, Object?> _item(String id) => {
  'id': id,
  'title': 't',
  'content_text': '',
  'item_type': 'note',
  'source_app': null,
  'source_label': null,
  'source_url': null,
  'source_location': null,
  'course_name': null,
  'group_name': null,
  'context_note': null,
  'review_status': 'needs_review',
  'is_favorite': 0,
  'created_at': '2026-10-26T10:00:00+07:00',
  'updated_at': '2026-10-26T10:00:00+07:00',
  'archived_at': null,
};

ParsedBackup _parse(String text) =>
    BackupValidator.parse(text, currentSchemaVersion: 4);

void main() {
  test('backup kosong yang valid diterima', () {
    final p = _parse(_backup(schema: 4));
    expect(p.schemaVersion, 4);
    expect(p.totalRows, 0);
  });

  test('backup v2 tetap diterima dan transaksi lama tetap non-ledger', () {
    final data = _emptyData();
    data['accounts'] = [
      {
        'id': 'wallet',
        'name': 'Cash',
        'account_type': 'cash',
        'confirmed_balance': 100000,
        'balance_confirmed_at': '2026-10-01T08:00:00+07:00',
        'is_active': 1,
        'created_at': '2026-10-01T08:00:00+07:00',
        'updated_at': '2026-10-01T08:00:00+07:00',
      },
    ];
    data['transactions'] = [
      {
        'id': 'old',
        'account_id': 'wallet',
        'amount': 10000,
        'direction': 'expense',
        'category': 'Food',
        'note': null,
        'occurred_at': '2026-10-02T08:00:00+07:00',
        'created_at': '2026-10-02T08:00:00+07:00',
      },
    ];
    final p = _parse(_backup(schema: 2, data: data));
    expect(p.data['transactions']!.single['affects_balance'], 0);
    expect(p.data['transactions']!.single['bill_id'], isNull);
  });

  test('backup v3 mengisi event lama sebagai non-berulang', () {
    final p = _parse(_backup(schema: 3));
    expect(p.data['events'], isEmpty);
    final data = _emptyData();
    data['events'] = [
      {
        'id': 'event',
        'title': 'Kuliah',
        'description': '',
        'starts_at': '2026-10-26T08:00:00+07:00',
        'ends_at': null,
        'location': null,
        'event_type': 'lecture',
        'linked_task_id': null,
        'linked_saved_item_id': null,
        'created_at': '2026-10-26T08:00:00+07:00',
        'updated_at': '2026-10-26T08:00:00+07:00',
      },
    ];
    final upgraded = _parse(_backup(schema: 3, data: data));
    expect(upgraded.data['events']!.single['recurrence_rule'], isNull);
  });

  test('backup tanpa checksum tetap diterima (checksum opsional)', () {
    expect(_parse(_backup(withChecksum: false)).totalRows, 0);
  });

  test('bukan JSON ditolak dengan BackupFormatException', () {
    expect(() => _parse('bukan json'), throwsA(isA<BackupFormatException>()));
  });

  test('format asing ditolak', () {
    expect(
      () => _parse(_backup(format: 'lain')),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('skema lebih baru dari aplikasi ditolak dengan pesan yang jelas', () {
    expect(
      () => _parse(_backup(schema: 5)),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('lebih baru'),
        ),
      ),
    );
  });

  test('checksum tidak cocok ditolak', () {
    expect(
      () => _parse(_backup(badChecksum: 'deadbeef')),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('tabel hilang ditolak', () {
    final d = _emptyData()..remove('tasks');
    expect(
      () => _parse(_backup(data: d)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test('kolom tidak dikenal ditolak', () {
    final d = _emptyData();
    d['saved_items'] = [
      {..._item('a'), 'kolom_aneh': 1},
    ];
    expect(
      () => _parse(_backup(data: d)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test('tipe data salah ditolak', () {
    final d = _emptyData();
    d['saved_items'] = [
      {..._item('a'), 'is_favorite': 'ya'},
    ];
    expect(
      () => _parse(_backup(data: d)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test('kolom wajib null ditolak', () {
    final d = _emptyData();
    d['saved_items'] = [
      {..._item('a'), 'title': null},
    ];
    expect(
      () => _parse(_backup(data: d)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test('ID ganda ditolak', () {
    final d = _emptyData();
    d['saved_items'] = [_item('a'), _item('a')];
    expect(
      () => _parse(_backup(data: d)),
      throwsA(isA<ImportValidationException>()),
    );
  });

  test(
    'relasi rusak ditolak (task_saved_items menunjuk item yang tidak ada)',
    () {
      final d = _emptyData();
      d['saved_items'] = [_item('a')];
      d['task_saved_items'] = [
        {'task_id': 'tidak-ada', 'saved_item_id': 'a', 'relation_note': null},
      ];
      expect(
        () => _parse(_backup(data: d)),
        throwsA(isA<ImportValidationException>()),
      );
    },
  );

  test('relasi valid diterima dan dihitung', () {
    final d = _emptyData();
    d['saved_items'] = [_item('a'), _item('b')];
    final p = _parse(_backup(data: d));
    expect(p.countOf('saved_items'), 2);
    expect(p.totalRows, 2);
  });

  Map<String, Object?> task({bool withRule = true}) => {
    'id': 't1',
    'title': 'Tugas',
    'description': '',
    'status': 'todo',
    'priority': 'normal',
    'due_at': null,
    'estimated_minutes': null,
    'course_name': null,
    'group_name': null,
    'task_kind': 'individual',
    'instruction_source': null,
    'instruction_location': null,
    'initiated_by': null,
    'next_action': null,
    'created_at': '2026-10-26T10:00:00+07:00',
    'updated_at': '2026-10-26T10:00:00+07:00',
    'completed_at': null,
    'archived_at': null,
    if (withRule) 'recurrence_rule': 'weekly',
  };

  test('backup skema 1 (tanpa recurrence_rule) tetap bisa dipulihkan', () {
    final d = _emptyData();
    d['tasks'] = [task(withRule: false)];
    final p = _parse(_backup(data: d, schema: 1));
    expect(p.countOf('tasks'), 1);
  });

  test('backup skema 2 dengan recurrence_rule diterima', () {
    final d = _emptyData();
    d['tasks'] = [task()];
    expect(_parse(_backup(data: d)).countOf('tasks'), 1);
  });

  test('skema 2 tanpa recurrence_rule ditolak (kolom wajib ada)', () {
    final d = _emptyData();
    d['tasks'] = [task(withRule: false)];
    expect(
      () => _parse(_backup(data: d, schema: 2)),
      throwsA(isA<ImportValidationException>()),
    );
  });
}
