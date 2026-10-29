import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../errors/app_exception.dart';

/// Definisi kolom backup per tabel untuk skema versi 1. Saat skema naik,
/// tambahkan spesifikasi versi baru dan konversi dari versi lama (TDD bagian 11).
class _Col {
  const _Col.text({this.nullable = false}) : isInt = false;
  const _Col.integer({this.nullable = false}) : isInt = true;

  final bool isInt;
  final bool nullable;
}

class BackupSchema {
  const BackupSchema._();

  static const String formatId = 'deck-of-life-backup';

  /// Urutan insert (induk lebih dulu). Urutan hapus = kebalikannya.
  static const List<String> tables = [
    'saved_items',
    'tasks',
    'task_saved_items',
    'events',
    'reminders',
    'accounts',
    'bills',
    'transactions',
    'balance_adjustments',
    'routines',
    'routine_logs',
    'app_settings',
  ];

  static const Map<String, Map<String, _Col>> v1 = {
    'saved_items': {
      'id': _Col.text(),
      'title': _Col.text(),
      'content_text': _Col.text(),
      'item_type': _Col.text(),
      'source_app': _Col.text(nullable: true),
      'source_label': _Col.text(nullable: true),
      'source_url': _Col.text(nullable: true),
      'source_location': _Col.text(nullable: true),
      'course_name': _Col.text(nullable: true),
      'group_name': _Col.text(nullable: true),
      'context_note': _Col.text(nullable: true),
      'review_status': _Col.text(),
      'is_favorite': _Col.integer(),
      'created_at': _Col.text(),
      'updated_at': _Col.text(),
      'archived_at': _Col.text(nullable: true),
    },
    'tasks': {
      'id': _Col.text(),
      'title': _Col.text(),
      'description': _Col.text(),
      'status': _Col.text(),
      'priority': _Col.text(),
      'due_at': _Col.text(nullable: true),
      'estimated_minutes': _Col.integer(nullable: true),
      'course_name': _Col.text(nullable: true),
      'group_name': _Col.text(nullable: true),
      'task_kind': _Col.text(),
      'instruction_source': _Col.text(nullable: true),
      'instruction_location': _Col.text(nullable: true),
      'initiated_by': _Col.text(nullable: true),
      'next_action': _Col.text(nullable: true),
      'created_at': _Col.text(),
      'updated_at': _Col.text(),
      'completed_at': _Col.text(nullable: true),
      'archived_at': _Col.text(nullable: true),
    },
    'task_saved_items': {
      'task_id': _Col.text(),
      'saved_item_id': _Col.text(),
      'relation_note': _Col.text(nullable: true),
    },
    'events': {
      'id': _Col.text(),
      'title': _Col.text(),
      'description': _Col.text(),
      'starts_at': _Col.text(),
      'ends_at': _Col.text(nullable: true),
      'location': _Col.text(nullable: true),
      'event_type': _Col.text(),
      'linked_task_id': _Col.text(nullable: true),
      'linked_saved_item_id': _Col.text(nullable: true),
      'created_at': _Col.text(),
      'updated_at': _Col.text(),
    },
    'reminders': {
      'id': _Col.text(),
      'target_type': _Col.text(),
      'target_id': _Col.text(),
      'remind_at': _Col.text(),
      'repeat_rule': _Col.text(nullable: true),
      'notification_id': _Col.integer(),
      'is_enabled': _Col.integer(),
      'last_scheduled_at': _Col.text(nullable: true),
      'created_at': _Col.text(),
      'updated_at': _Col.text(),
    },
    'accounts': {
      'id': _Col.text(),
      'name': _Col.text(),
      'account_type': _Col.text(),
      'confirmed_balance': _Col.integer(),
      'balance_confirmed_at': _Col.text(),
      'is_active': _Col.integer(),
      'created_at': _Col.text(),
      'updated_at': _Col.text(),
    },
    'transactions': {
      'id': _Col.text(),
      'account_id': _Col.text(),
      'amount': _Col.integer(),
      'direction': _Col.text(),
      'category': _Col.text(),
      'note': _Col.text(nullable: true),
      'occurred_at': _Col.text(),
      'created_at': _Col.text(),
    },
    'balance_adjustments': {
      'id': _Col.text(),
      'account_id': _Col.text(),
      'previous_balance': _Col.integer(),
      'corrected_balance': _Col.integer(),
      'reason': _Col.text(nullable: true),
      'adjusted_at': _Col.text(),
    },
    'bills': {
      'id': _Col.text(),
      'title': _Col.text(),
      'amount': _Col.integer(),
      'due_at': _Col.text(),
      'status': _Col.text(),
      'paid_at': _Col.text(nullable: true),
      'account_id': _Col.text(nullable: true),
      'note': _Col.text(nullable: true),
      'created_at': _Col.text(),
      'updated_at': _Col.text(),
    },
    'routines': {
      'id': _Col.text(),
      'title': _Col.text(),
      'description': _Col.text(),
      'recurrence_type': _Col.text(),
      'interval_days': _Col.integer(nullable: true),
      'weekdays_json': _Col.text(nullable: true),
      'preferred_time': _Col.text(nullable: true),
      'next_due_at': _Col.text(nullable: true),
      'last_completed_at': _Col.text(nullable: true),
      'is_active': _Col.integer(),
      'created_at': _Col.text(),
      'updated_at': _Col.text(),
    },
    'routine_logs': {
      'id': _Col.text(),
      'routine_id': _Col.text(),
      'completed_at': _Col.text(),
      'note': _Col.text(nullable: true),
    },
    'app_settings': {
      'key': _Col.text(),
      'value': _Col.text(),
      'updated_at': _Col.text(),
    },
  };

  /// Skema v2 = v1 + `recurrence_rule` pada tugas dan tagihan (migrasi v2).
  static final Map<String, Map<String, _Col>> v2 = {
    ...v1,
    'tasks': {
      ...v1['tasks']!,
      'recurrence_rule': const _Col.text(nullable: true),
    },
    'bills': {
      ...v1['bills']!,
      'recurrence_rule': const _Col.text(nullable: true),
    },
  };

  /// Skema v3 menghubungkan transfer/tagihan ke ledger dan menandai transaksi
  /// baru yang berpengaruh pada saldo.
  static final Map<String, Map<String, _Col>> v3 = {
    ...v2,
    'transactions': {
      ...v2['transactions']!,
      'transfer_id': const _Col.text(nullable: true),
      'bill_id': const _Col.text(nullable: true),
      'affects_balance': const _Col.integer(),
    },
  };

  /// Skema v4 menambahkan aturan pengulangan ke agenda.
  static final Map<String, Map<String, _Col>> v4 = {
    ...v3,
    'events': {
      ...v3['events']!,
      'recurrence_rule': const _Col.text(nullable: true),
    },
    'routines': {
      ...v3['routines']!,
      'migrated_task_id': const _Col.text(nullable: true),
    },
  };

  /// SHA-256 dari `data` yang di-encode kompak. Dipakai saat ekspor dan impor.
  static String checksumOf(Object? data) =>
      sha256.convert(utf8.encode(jsonEncode(data))).toString();
}

class ParsedBackup {
  const ParsedBackup({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.data,
  });

  final int schemaVersion;
  final String? appVersion;
  final String? exportedAt;
  final Map<String, List<Map<String, Object?>>> data;

  int get totalRows => data.values.fold(0, (a, b) => a + b.length);
  int countOf(String table) => data[table]?.length ?? 0;
}

/// Validasi murni (tanpa I/O) sebelum database disentuh (TDD bagian 12):
/// format, versi skema, tipe data, ID unik, dan referensi antar tabel.
class BackupValidator {
  const BackupValidator._();

  static ParsedBackup parse(
    String jsonText, {
    required int currentSchemaVersion,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw BackupFormatException('This file is not valid JSON.', e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException(
        'The backup file structure is not recognized.',
      );
    }
    if (decoded['format'] != BackupSchema.formatId) {
      throw const BackupFormatException('This is not a Deck of Life backup.');
    }
    final version = decoded['schema_version'];
    if (version is! int || version < 1) {
      throw const BackupFormatException(
        'The backup schema version is invalid.',
      );
    }
    if (version > currentSchemaVersion) {
      throw const BackupFormatException(
        'This backup was created by a newer version of the app. '
        'Update the app before restoring.',
      );
    }
    final spec = _specFor(version);

    final rawData = decoded['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const BackupFormatException(
        'The backup data section was not found.',
      );
    }

    final checksum = decoded['checksum'];
    if (checksum != null &&
        (checksum is! String || checksum != BackupSchema.checksumOf(rawData))) {
      throw const BackupFormatException(
        'The backup checksum does not match; the file may be damaged or modified.',
      );
    }

    final data = <String, List<Map<String, Object?>>>{};
    for (final table in BackupSchema.tables) {
      final rows = rawData[table];
      if (rows is! List) {
        throw ImportValidationException(
          'Table "$table" is missing from the backup.',
        );
      }
      final columns = spec[table]!;
      final out = <Map<String, Object?>>[];
      for (var i = 0; i < rows.length; i++) {
        out.add(_validateRow(table, i, rows[i], columns));
      }
      data[table] = out;
    }

    _checkUniqueIds(data);
    _checkReferences(data);

    // Older backups are upgraded in memory and leave their transactions inert.
    if (version < 2) {
      for (final table in const ['tasks', 'bills']) {
        for (final row in data[table]!) {
          row['recurrence_rule'] = null;
        }
      }
    }
    if (version < 3) {
      for (final row in data['transactions']!) {
        row['transfer_id'] = null;
        row['bill_id'] = null;
        row['affects_balance'] = 0;
      }
    }
    if (version < 4) {
      for (final row in data['events']!) {
        row['recurrence_rule'] = null;
      }
      for (final row in data['routines']!) {
        row['migrated_task_id'] = null;
      }
    }

    return ParsedBackup(
      schemaVersion: version,
      appVersion: decoded['app_version'] as String?,
      exportedAt: decoded['exported_at'] as String?,
      data: data,
    );
  }

  static Map<String, Map<String, _Col>> _specFor(int version) {
    if (version == 1) return BackupSchema.v1;
    if (version == 2) return BackupSchema.v2;
    if (version == 3) return BackupSchema.v3;
    if (version == 4) return BackupSchema.v4;
    throw BackupFormatException(
      'Backup schema version $version is not supported.',
    );
  }

  static Map<String, Object?> _validateRow(
    String table,
    int index,
    Object? raw,
    Map<String, _Col> columns,
  ) {
    if (raw is! Map) {
      throw ImportValidationException(
        'Row ${index + 1} in "$table" is malformed.',
      );
    }
    final row = <String, Object?>{};
    for (final key in raw.keys) {
      if (key is! String || !columns.containsKey(key)) {
        throw ImportValidationException('Unknown column "$key" in "$table".');
      }
    }
    for (final entry in columns.entries) {
      if (!raw.containsKey(entry.key)) {
        throw ImportValidationException(
          'Column "${entry.key}" is missing (row ${index + 1} in "$table").',
        );
      }
      final value = raw[entry.key];
      final col = entry.value;
      if (value == null) {
        if (!col.nullable) {
          throw ImportValidationException(
            'Column "${entry.key}" is required (row ${index + 1} in "$table").',
          );
        }
        row[entry.key] = null;
        continue;
      }
      final ok = col.isInt ? value is int : value is String;
      if (!ok) {
        throw ImportValidationException(
          'Column "${entry.key}" has the wrong type (row ${index + 1} in "$table").',
        );
      }
      row[entry.key] = value;
    }
    return row;
  }

  static void _checkUniqueIds(Map<String, List<Map<String, Object?>>> data) {
    for (final table in BackupSchema.tables) {
      if (table == 'task_saved_items')
        continue; // kunci gabungan, dicek di bawah
      final keyCol = table == 'app_settings' ? 'key' : 'id';
      final seen = <Object?>{};
      for (final row in data[table]!) {
        if (!seen.add(row[keyCol])) {
          throw ImportValidationException('Duplicate ID in table "$table".');
        }
      }
    }
    final pairs = <String>{};
    for (final row in data['task_saved_items']!) {
      if (!pairs.add('${row['task_id']}|${row['saved_item_id']}')) {
        throw const ImportValidationException(
          'Duplicate task-note link in the backup.',
        );
      }
    }
    final notificationIds = <Object?>{};
    for (final row in data['reminders']!) {
      if (!notificationIds.add(row['notification_id'])) {
        throw const ImportValidationException(
          'Duplicate notification ID in the backup.',
        );
      }
    }
  }

  static Set<Object?> _ids(
    Map<String, List<Map<String, Object?>>> data,
    String table,
  ) => data[table]!.map((r) => r['id']).toSet();

  static void _checkReferences(Map<String, List<Map<String, Object?>>> data) {
    final tasks = _ids(data, 'tasks');
    final items = _ids(data, 'saved_items');
    final accounts = _ids(data, 'accounts');
    final routines = _ids(data, 'routines');
    final bills = _ids(data, 'bills');

    void need(
      Set<Object?> parents,
      Object? value,
      String what, {
      bool nullable = false,
    }) {
      if (value == null && nullable) return;
      if (!parents.contains(value)) {
        throw ImportValidationException(
          'Broken relation: $what was not found.',
        );
      }
    }

    for (final r in data['task_saved_items']!) {
      need(tasks, r['task_id'], 'task in note link');
      need(items, r['saved_item_id'], 'note in task link');
    }
    for (final r in data['events']!) {
      need(tasks, r['linked_task_id'], 'task linked to event', nullable: true);
      need(
        items,
        r['linked_saved_item_id'],
        'note linked to event',
        nullable: true,
      );
    }
    for (final r in data['transactions']!) {
      need(accounts, r['account_id'], 'account on transaction');
      need(bills, r['bill_id'], 'bill on transaction', nullable: true);
    }
    for (final r in data['balance_adjustments']!) {
      need(accounts, r['account_id'], 'account on balance adjustment');
    }
    for (final r in data['bills']!) {
      need(accounts, r['account_id'], 'account on bill', nullable: true);
    }
    for (final r in data['routine_logs']!) {
      need(routines, r['routine_id'], 'routine on history entry');
    }
  }
}
