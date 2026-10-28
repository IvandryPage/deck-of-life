import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/search/search_service.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/reminder_cleanup.dart';
import '../models/row_mappers.dart';

class SavedItemRepositoryImpl implements SavedItemRepository {
  SavedItemRepositoryImpl(this._db);

  final AppDatabase _db;

  static const List<String> _searchColumns = [
    'title',
    'content_text',
    'course_name',
    'group_name',
    'context_note',
    'source_label',
    'source_location',
    'source_url',
    'source_app',
  ];

  @override
  Future<SavedItem> create(SavedItem item) => dbGuard(() async {
        await _db.raw.insert('saved_items', SavedItemRow.toRow(item));
        return item;
      });

  @override
  Future<SavedItem?> getById(String id) => dbGuard(() async {
        final rows = await _db.raw.query(
          'saved_items',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        return rows.isEmpty ? null : SavedItemRow.fromRow(rows.first);
      });

  @override
  Future<List<SavedItem>> search(
    String query, {
    SavedItemType? type,
    String? courseName,
    ReviewStatus? reviewStatus,
    bool includeArchived = false,
    int limit = 50,
    int offset = 0,
  }) =>
      dbGuard(() async {
        final like = SearchService.build(query, _searchColumns);
        final where = <String>[like.where];
        final args = <Object?>[...like.args];
        if (type != null) {
          where.add('item_type = ?');
          args.add(type.value);
        }
        if (courseName != null && courseName.isNotEmpty) {
          where.add('course_name = ?');
          args.add(courseName);
        }
        if (reviewStatus != null) {
          where.add('review_status = ?');
          args.add(reviewStatus.value);
        } else if (!includeArchived) {
          where.add("review_status != 'archived'");
        }
        final rows = await _db.raw.query(
          'saved_items',
          where: where.join(' AND '),
          whereArgs: args,
          orderBy: 'updated_at DESC',
          limit: limit,
          offset: offset,
        );
        return rows.map(SavedItemRow.fromRow).toList();
      });

  @override
  Future<void> update(SavedItem item) => dbGuard(() async {
        final row = SavedItemRow.toRow(item)
          ..remove('created_at')
          ..['updated_at'] = DateTimeUtils.nowIso();
        await _db.raw.update(
          'saved_items',
          row,
          where: 'id = ?',
          whereArgs: [item.id],
        );
      });

  @override
  Future<NotificationIds> setReviewStatus(String id, ReviewStatus status) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            await txn.update(
              'saved_items',
              {
                'review_status': status.value,
                'archived_at': status == ReviewStatus.archived
                    ? DateTimeUtils.nowIso()
                    : null,
                'updated_at': DateTimeUtils.nowIso(),
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            // Pengingat "periksa" tidak berlaku lagi setelah item ditinjau/diarsipkan.
            if (status != ReviewStatus.needsReview) {
              return deleteRemindersFor(txn, ReminderTargetType.savedItem, id);
            }
            return <int>[];
          }));

  @override
  Future<SavedItem?> findDuplicate({String? url, String? content}) =>
      dbGuard(() async {
        final where = <String>[];
        final args = <Object?>[];
        final u = url?.trim();
        if (u != null && u.isNotEmpty) {
          where.add('source_url = ?');
          args.add(u);
        }
        final c = content?.trim();
        if (c != null && c.isNotEmpty) {
          where.add('TRIM(content_text) = ?');
          args.add(c);
        }
        if (where.isEmpty) return null;
        final rows = await _db.raw.query(
          'saved_items',
          where: where.join(' OR '),
          whereArgs: args,
          orderBy: 'created_at DESC',
          limit: 1,
        );
        return rows.isEmpty ? null : SavedItemRow.fromRow(rows.first);
      });

  @override
  Future<NotificationIds> archive(String id, DateTime archivedAt) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            await txn.update(
              'saved_items',
              {
                'review_status': ReviewStatus.archived.value,
                'archived_at': DateTimeUtils.toIso(archivedAt),
                'updated_at': DateTimeUtils.nowIso(),
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            return deleteRemindersFor(txn, ReminderTargetType.savedItem, id);
          }));

  @override
  Future<NotificationIds> deletePermanently(String id) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final ids =
                await deleteRemindersFor(txn, ReminderTargetType.savedItem, id);
            // task_saved_items ikut terhapus (ON DELETE CASCADE);
            // events.linked_saved_item_id menjadi NULL (ON DELETE SET NULL).
            await txn.delete('saved_items', where: 'id = ?', whereArgs: [id]);
            return ids;
          }));

  @override
  Future<int> countNeedsReview() => dbGuard(() async {
        final n = Sqflite.firstIntValue(await _db.raw.rawQuery(
          "SELECT COUNT(*) FROM saved_items WHERE review_status = 'needs_review'",
        ));
        return n ?? 0;
      });

  @override
  Future<List<String>> distinctCourseNames() => dbGuard(() async {
        final rows = await _db.raw.rawQuery(
          'SELECT course_name AS n FROM saved_items WHERE course_name IS NOT NULL '
          'UNION SELECT course_name FROM tasks WHERE course_name IS NOT NULL '
          'ORDER BY 1',
        );
        return rows.map((r) => r['n'] as String).toList();
      });
}
