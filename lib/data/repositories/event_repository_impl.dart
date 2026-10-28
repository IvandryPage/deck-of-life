import '../../core/database/app_database.dart';
import '../../core/search/search_service.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/reminder_cleanup.dart';
import '../models/row_mappers.dart';

class EventRepositoryImpl implements EventRepository {
  EventRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<Event> create(Event event) => dbGuard(() async {
        await _db.raw.insert('events', EventRow.toRow(event));
        return event;
      });

  @override
  Future<Event?> getById(String id) => dbGuard(() async {
        final rows = await _db.raw
            .query('events', where: 'id = ?', whereArgs: [id], limit: 1);
        return rows.isEmpty ? null : EventRow.fromRow(rows.first);
      });

  @override
  Future<void> update(Event event) => dbGuard(() async {
        final row = EventRow.toRow(event)
          ..remove('created_at')
          ..['updated_at'] = DateTimeUtils.nowIso();
        await _db.raw
            .update('events', row, where: 'id = ?', whereArgs: [event.id]);
      });

  @override
  Future<NotificationIds> delete(String id) =>
      dbGuard(() => _db.raw.transaction((txn) async {
            final ids =
                await deleteRemindersFor(txn, ReminderTargetType.event, id);
            await txn.delete('events', where: 'id = ?', whereArgs: [id]);
            return ids;
          }));

  /// Teks ISO dengan offset berbeda tidak selalu urut benar secara leksikal,
  /// jadi query memakai margin +-1 hari lalu difilter tepat di Dart.
  @override
  Future<List<Event>> listBetween(DateTime from, DateTime to) =>
      dbGuard(() async {
        final lo = DateTime(from.year, from.month, from.day - 1);
        final hi = DateTime(to.year, to.month, to.day + 1);
        final rows = await _db.raw.query(
          'events',
          where: 'starts_at >= ? AND starts_at < ?',
          whereArgs: [DateTimeUtils.toIso(lo), DateTimeUtils.toIso(hi)],
          orderBy: 'starts_at ASC',
        );
        return rows
            .map(EventRow.fromRow)
            .where((e) => !e.startsAt.isBefore(from) && e.startsAt.isBefore(to))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      });

  @override
  Future<List<Event>> listUpcoming({int limit = 50}) => dbGuard(() async {
        final today = DateTimeUtils.startOfDay(DateTime.now());
        final lo = DateTime(today.year, today.month, today.day - 1);
        final rows = await _db.raw.query(
          'events',
          where: 'starts_at >= ?',
          whereArgs: [DateTimeUtils.toIso(lo)],
          orderBy: 'starts_at ASC',
          limit: limit + 20,
        );
        final list = rows
            .map(EventRow.fromRow)
            .where((e) => !e.startsAt.isBefore(today))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        return list.take(limit).toList();
      });

  @override
  Future<List<Event>> search(String query, {int limit = 50}) =>
      dbGuard(() async {
        final like = SearchService.build(
          query,
          const ['title', 'description', 'location'],
        );
        final rows = await _db.raw.query(
          'events',
          where: like.where,
          whereArgs: like.args,
          orderBy: 'starts_at DESC',
          limit: limit,
        );
        return rows.map(EventRow.fromRow).toList();
      });
}
