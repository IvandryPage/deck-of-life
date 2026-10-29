import '../../core/database/app_database.dart';
import '../../core/search/search_service.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/recurrence.dart';
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
    final rows = await _db.raw.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : EventRow.fromRow(rows.first);
  });

  @override
  Future<void> update(Event event) => dbGuard(() async {
    final row = EventRow.toRow(event)
      ..remove('created_at')
      ..['updated_at'] = DateTimeUtils.nowIso();
    await _db.raw.update('events', row, where: 'id = ?', whereArgs: [event.id]);
  });

  @override
  Future<NotificationIds> delete(String id) => dbGuard(
    () => _db.raw.transaction((txn) async {
      final ids = await deleteRemindersFor(txn, ReminderTargetType.event, id);
      await txn.delete('events', where: 'id = ?', whereArgs: [id]);
      return ids;
    }),
  );

  /// Teks ISO dengan offset berbeda tidak selalu urut benar secara leksikal,
  /// jadi query memakai margin +-1 hari lalu difilter tepat di Dart.
  @override
  Future<List<Event>> listBetween(DateTime from, DateTime to) =>
      dbGuard(() async {
        final hi = DateTime(to.year, to.month, to.day + 1);
        final rows = await _db.raw.query(
          'events',
          where: 'starts_at < ?',
          whereArgs: [DateTimeUtils.toIso(hi)],
          orderBy: 'starts_at ASC',
        );
        return _occurrences(rows.map(EventRow.fromRow), from, to);
      });

  @override
  Future<List<Event>> listUpcoming({int limit = 50}) => dbGuard(() async {
    final today = DateTimeUtils.startOfDay(DateTime.now());
    final end = DateTime(today.year + 2, today.month, today.day);
    final rows = await _db.raw.query('events', orderBy: 'starts_at ASC');
    final list = _occurrences(rows.map(EventRow.fromRow), today, end);
    return list.take(limit).toList();
  });

  static List<Event> _occurrences(
    Iterable<Event> events,
    DateTime from,
    DateTime to,
  ) {
    final occurrences = <Event>[];
    for (final event in events) {
      final rule = RecurrenceRule.tryParse(event.recurrenceRule);
      if (rule == null) {
        if (!event.startsAt.isBefore(from) && event.startsAt.isBefore(to)) {
          occurrences.add(event);
        }
        continue;
      }

      var start = event.startsAt;
      var end = event.endsAt;
      if (start.isBefore(from) && rule.kind != RecurrenceKind.monthly) {
        final elapsedDays = DateTime.utc(
          from.year,
          from.month,
          from.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
        final periodDays = switch (rule.kind) {
          RecurrenceKind.daily => 1,
          RecurrenceKind.weekly || RecurrenceKind.weekdays => 7,
          RecurrenceKind.interval => rule.intervalDays ?? 1,
          RecurrenceKind.monthly => 1,
        };
        final periods = elapsedDays ~/ periodDays;
        final fastForwardDays = periods * periodDays;
        final fastForwarded = DateTime(
          start.year,
          start.month,
          start.day + fastForwardDays,
          start.hour,
          start.minute,
        );
        end = _shiftEnd(end, start, fastForwarded);
        start = fastForwarded;
      }
      while (start.isBefore(from)) {
        final next = rule.next(start);
        end = _shiftEnd(end, start, next);
        start = next;
      }
      while (start.isBefore(to)) {
        occurrences.add(event.copyWith(startsAt: start, endsAt: end));
        final next = rule.next(start);
        end = _shiftEnd(end, start, next);
        start = next;
      }
    }
    occurrences.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return occurrences;
  }

  static DateTime? _shiftEnd(DateTime? end, DateTime from, DateTime to) {
    if (end == null) return null;
    final dayOffset = DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
    return DateTime(
      end.year,
      end.month,
      end.day + dayOffset,
      end.hour,
      end.minute,
      end.second,
      end.millisecond,
      end.microsecond,
    );
  }

  @override
  Future<List<Event>> search(String query, {int limit = 50}) =>
      dbGuard(() async {
        final like = SearchService.build(query, const [
          'title',
          'description',
          'location',
        ]);
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
