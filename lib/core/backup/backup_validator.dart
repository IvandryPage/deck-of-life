import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../errors/app_exception.dart';

/// Definisi kolom backup per tabel untuk skema versi 1. Saat skema naik,
/// tambahkan spesifikasi versi baru dan konversi dari versi lama (TDD bagian 11).
class BackupColumn {
  const BackupColumn.text({this.nullable = false}) : isInt = false;
  const BackupColumn.integer({this.nullable = false}) : isInt = true;

  final bool isInt;
  final bool nullable;
}

class BackupSchema {
  const BackupSchema._();

  static const String formatId = 'deck-of-life-backup';

  /// Urutan insert (induk lebih dulu). Urutan hapus = kebalikannya.
  static const List<String> tables = [
    'saved_items',
    'saved_item_attachments',
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

  static const Map<String, Map<String, BackupColumn>> v1 = {
    'saved_items': {
      'id': BackupColumn.text(),
      'title': BackupColumn.text(),
      'content_text': BackupColumn.text(),
      'item_type': BackupColumn.text(),
      'source_app': BackupColumn.text(nullable: true),
      'source_label': BackupColumn.text(nullable: true),
      'source_url': BackupColumn.text(nullable: true),
      'source_location': BackupColumn.text(nullable: true),
      'course_name': BackupColumn.text(nullable: true),
      'group_name': BackupColumn.text(nullable: true),
      'context_note': BackupColumn.text(nullable: true),
      'review_status': BackupColumn.text(),
      'is_favorite': BackupColumn.integer(),
      'created_at': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
      'archived_at': BackupColumn.text(nullable: true),
    },
    'tasks': {
      'id': BackupColumn.text(),
      'title': BackupColumn.text(),
      'description': BackupColumn.text(),
      'status': BackupColumn.text(),
      'priority': BackupColumn.text(),
      'due_at': BackupColumn.text(nullable: true),
      'estimated_minutes': BackupColumn.integer(nullable: true),
      'course_name': BackupColumn.text(nullable: true),
      'group_name': BackupColumn.text(nullable: true),
      'task_kind': BackupColumn.text(),
      'instruction_source': BackupColumn.text(nullable: true),
      'instruction_location': BackupColumn.text(nullable: true),
      'initiated_by': BackupColumn.text(nullable: true),
      'next_action': BackupColumn.text(nullable: true),
      'created_at': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
      'completed_at': BackupColumn.text(nullable: true),
      'archived_at': BackupColumn.text(nullable: true),
    },
    'task_saved_items': {
      'task_id': BackupColumn.text(),
      'saved_item_id': BackupColumn.text(),
      'relation_note': BackupColumn.text(nullable: true),
    },
    'events': {
      'id': BackupColumn.text(),
      'title': BackupColumn.text(),
      'description': BackupColumn.text(),
      'starts_at': BackupColumn.text(),
      'ends_at': BackupColumn.text(nullable: true),
      'location': BackupColumn.text(nullable: true),
      'event_type': BackupColumn.text(),
      'linked_task_id': BackupColumn.text(nullable: true),
      'linked_saved_item_id': BackupColumn.text(nullable: true),
      'created_at': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
    },
    'reminders': {
      'id': BackupColumn.text(),
      'target_type': BackupColumn.text(),
      'target_id': BackupColumn.text(),
      'remind_at': BackupColumn.text(),
      'repeat_rule': BackupColumn.text(nullable: true),
      'notification_id': BackupColumn.integer(),
      'is_enabled': BackupColumn.integer(),
      'last_scheduled_at': BackupColumn.text(nullable: true),
      'created_at': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
    },
    'accounts': {
      'id': BackupColumn.text(),
      'name': BackupColumn.text(),
      'account_type': BackupColumn.text(),
      'confirmed_balance': BackupColumn.integer(),
      'balance_confirmed_at': BackupColumn.text(),
      'is_active': BackupColumn.integer(),
      'created_at': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
    },
    'transactions': {
      'id': BackupColumn.text(),
      'account_id': BackupColumn.text(),
      'amount': BackupColumn.integer(),
      'direction': BackupColumn.text(),
      'category': BackupColumn.text(),
      'note': BackupColumn.text(nullable: true),
      'occurred_at': BackupColumn.text(),
      'created_at': BackupColumn.text(),
    },
    'balance_adjustments': {
      'id': BackupColumn.text(),
      'account_id': BackupColumn.text(),
      'previous_balance': BackupColumn.integer(),
      'corrected_balance': BackupColumn.integer(),
      'reason': BackupColumn.text(nullable: true),
      'adjusted_at': BackupColumn.text(),
    },
    'bills': {
      'id': BackupColumn.text(),
      'title': BackupColumn.text(),
      'amount': BackupColumn.integer(),
      'due_at': BackupColumn.text(),
      'status': BackupColumn.text(),
      'paid_at': BackupColumn.text(nullable: true),
      'account_id': BackupColumn.text(nullable: true),
      'note': BackupColumn.text(nullable: true),
      'created_at': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
    },
    'routines': {
      'id': BackupColumn.text(),
      'title': BackupColumn.text(),
      'description': BackupColumn.text(),
      'recurrence_type': BackupColumn.text(),
      'interval_days': BackupColumn.integer(nullable: true),
      'weekdays_json': BackupColumn.text(nullable: true),
      'preferred_time': BackupColumn.text(nullable: true),
      'next_due_at': BackupColumn.text(nullable: true),
      'last_completed_at': BackupColumn.text(nullable: true),
      'is_active': BackupColumn.integer(),
      'created_at': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
    },
    'routine_logs': {
      'id': BackupColumn.text(),
      'routine_id': BackupColumn.text(),
      'completed_at': BackupColumn.text(),
      'note': BackupColumn.text(nullable: true),
    },
    'app_settings': {
      'key': BackupColumn.text(),
      'value': BackupColumn.text(),
      'updated_at': BackupColumn.text(),
    },
  };

  /// Skema v2 = v1 + `recurrence_rule` pada tugas dan tagihan (migrasi v2).
  static final Map<String, Map<String, BackupColumn>> v2 = {
    ...v1,
    'tasks': {
      ...v1['tasks']!,
      'recurrence_rule': const BackupColumn.text(nullable: true),
    },
    'bills': {
      ...v1['bills']!,
      'recurrence_rule': const BackupColumn.text(nullable: true),
    },
  };

  /// Skema v3 menghubungkan transfer/tagihan ke ledger dan menandai transaksi
  /// baru yang berpengaruh pada saldo.
  static final Map<String, Map<String, BackupColumn>> v3 = {
    ...v2,
    'transactions': {
      ...v2['transactions']!,
      'transfer_id': const BackupColumn.text(nullable: true),
      'bill_id': const BackupColumn.text(nullable: true),
      'affects_balance': const BackupColumn.integer(),
    },
  };

  /// Skema v4 menambahkan aturan pengulangan ke agenda.
  static final Map<String, Map<String, BackupColumn>> v4 = {
    ...v3,
    'events': {
      ...v3['events']!,
      'recurrence_rule': const BackupColumn.text(nullable: true),
    },
    'routines': {
      ...v3['routines']!,
      'migrated_task_id': const BackupColumn.text(nullable: true),
    },
  };

  static final Map<String, Map<String, BackupColumn>> v5 = {
    ...v4,
    'tasks': {...v4['tasks']!, 'checklist_json': const BackupColumn.text()},
    'saved_item_attachments': {
      'id': const BackupColumn.text(),
      'saved_item_id': const BackupColumn.text(),
      'file_name': const BackupColumn.text(),
      'mime_type': const BackupColumn.text(),
      'content_base64': const BackupColumn.text(),
      'size_bytes': const BackupColumn.integer(),
      'created_at': const BackupColumn.text(),
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
      final columns = spec[table];
      if (columns == null && version < 5 && table == 'saved_item_attachments') {
        final legacyRows = rawData[table];
        if (legacyRows is List && legacyRows.isNotEmpty) {
          throw const ImportValidationException(
            'An older backup cannot contain saved item attachments.',
          );
        }
        data[table] = [];
        continue;
      }
      final rows = rawData[table];
      if (rows is! List) {
        throw ImportValidationException(
          'Table "$table" is missing from the backup.',
        );
      }
      final rowColumns = columns!;
      final out = <Map<String, Object?>>[];
      for (var i = 0; i < rows.length; i++) {
        out.add(_validateRow(table, i, rows[i], rowColumns));
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
    if (version < 5) {
      for (final row in data['tasks']!) {
        row['checklist_json'] = '[]';
      }
      data['saved_item_attachments'] = [];
    }

    return ParsedBackup(
      schemaVersion: version,
      appVersion: decoded['app_version'] as String?,
      exportedAt: decoded['exported_at'] as String?,
      data: data,
    );
  }

  static Map<String, Map<String, BackupColumn>> _specFor(int version) {
    if (version == 1) return BackupSchema.v1;
    if (version == 2) return BackupSchema.v2;
    if (version == 3) return BackupSchema.v3;
    if (version == 4) return BackupSchema.v4;
    if (version == 5) return BackupSchema.v5;
    throw BackupFormatException(
      'Backup schema version $version is not supported.',
    );
  }

  static Map<String, Object?> _validateRow(
    String table,
    int index,
    Object? raw,
    Map<String, BackupColumn> columns,
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
    if (table == 'saved_item_attachments') {
      final size = row['size_bytes']! as int;
      final List<int> bytes;
      try {
        bytes = base64Decode(row['content_base64']! as String);
      } on FormatException catch (error) {
        throw ImportValidationException(
          'Attachment data in row ${index + 1} is not valid base64.',
          error,
        );
      }
      if (size < 1 || size > 10 * 1024 * 1024 || bytes.length != size) {
        throw ImportValidationException(
          'Attachment data in row ${index + 1} has an invalid size.',
        );
      }
    }
    return row;
  }

  static void _checkUniqueIds(Map<String, List<Map<String, Object?>>> data) {
    for (final table in BackupSchema.tables) {
      if (table == 'task_saved_items') {
        continue; // kunci gabungan, dicek di bawah
      }
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
    for (final r in data['saved_item_attachments']!) {
      need(items, r['saved_item_id'], 'note on saved item attachment');
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
