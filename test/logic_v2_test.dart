import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/domain/entities/entities.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/domain/entities/logic.dart';
import 'package:deck_of_life/domain/entities/recurrence.dart';

import 'helpers.dart';

void main() {
  group('RecurrenceRule', () {
    test('encode/parse bolak-balik; nilai aneh dianggap tidak berulang', () {
      expect(RecurrenceRule.tryParse('daily')!.kind, RecurrenceKind.daily);
      expect(RecurrenceRule.tryParse('weekly')!.encoded, 'weekly');
      expect(RecurrenceRule.tryParse('monthly:31')!.anchorDay, 31);
      expect(RecurrenceRule.tryParse('monthly:99'), isNull);
      expect(RecurrenceRule.tryParse('interval:3')!.encoded, 'interval:3');
      expect(RecurrenceRule.tryParse('interval:0'), isNull);
      expect(
        RecurrenceRule.tryParse('weekdays:1,3,5')!.encoded,
        'weekdays:1,3,5',
      );
      expect(RecurrenceRule.tryParse('weekdays:1,8'), isNull);
      expect(RecurrenceRule.tryParse('???'), isNull);
      expect(RecurrenceRule.tryParse(null), isNull);
    });

    test('bulanan berjangkar: 31 Jan -> 28 Feb -> 31 Mar', () {
      const r = RecurrenceRule(RecurrenceKind.monthly, anchorDay: 31);
      final feb = r.next(DateTime(2027, 1, 31, 9));
      expect(feb, DateTime(2027, 2, 28, 9));
      expect(r.next(feb), DateTime(2027, 3, 31, 9));
    });

    test('tahun kabisat dan pergantian tahun', () {
      const r = RecurrenceRule(RecurrenceKind.monthly, anchorDay: 29);
      expect(r.next(DateTime(2028, 1, 29)), DateTime(2028, 2, 29));
      expect(r.next(DateTime(2026, 12, 29)), DateTime(2027, 1, 29));
    });

    test('nextAfter tidak menghasilkan tanggal yang sudah lewat', () {
      const r = RecurrenceRule(RecurrenceKind.daily);
      final n = r.nextAfter(
        DateTime(2026, 10, 1, 8),
        DateTime(2026, 10, 6, 12),
      );
      expect(n, DateTime(2026, 10, 7, 8));
    });

    test('interval dan beberapa hari mingguan memakai jam yang sama', () {
      const interval = RecurrenceRule(RecurrenceKind.interval, intervalDays: 3);
      expect(
        interval.next(DateTime(2026, 10, 1, 8, 30)),
        DateTime(2026, 10, 4, 8, 30),
      );
      const weekdays = RecurrenceRule(
        RecurrenceKind.weekdays,
        weekdays: [1, 3, 5],
      );
      expect(
        weekdays.next(DateTime(2026, 10, 1, 8, 30)),
        DateTime(2026, 10, 2, 8, 30),
      );
      expect(
        weekdays.next(DateTime(2026, 10, 2, 8, 30)),
        DateTime(2026, 10, 5, 8, 30),
      );
    });
  });

  group('RealityCheck', () {
    final now = DateTime(2026, 10, 10, 12);

    test('tagihan lunas/dibatalkan tidak dihitung dan tidak dobel', () {
      final rc = RealityCheck.compute(
        accounts: [makeAccount('a', 1000000, confirmedAt: now)],
        bills: [
          makeBill('1', 300000, due: DateTime(2026, 10, 15)),
          makeBill('2', 200000, status: BillStatus.paid),
          makeBill('3', 100000, status: BillStatus.cancelled),
        ],
        now: now,
      );
      expect(rc.unpaidTotal, 300000);
      expect(rc.estimatedFree, 700000);
      expect(rc.fundingGap, 0);
    });

    test('memisahkan terlambat, dalam horizon, dan lebih jauh', () {
      final rc = RealityCheck.compute(
        accounts: [makeAccount('a', 100000, confirmedAt: now)],
        bills: [
          makeBill('o', 50000, due: DateTime(2026, 10, 5)),
          makeBill('s', 200000, due: DateTime(2026, 10, 20)),
          makeBill('l', 900000, due: DateTime(2026, 12, 20)),
        ],
        now: now,
        horizonDays: 30,
      );
      expect(rc.overdueTotal, 50000);
      expect(rc.dueInHorizonTotal, 200000);
      expect(rc.laterTotal, 900000);
      expect(rc.unpaidTotal, 1150000);
      expect(rc.estimatedFree, 100000 - 1150000);
      // Kesenjangan hanya dari kewajiban terlambat + dalam horizon.
      expect(rc.fundingGap, 150000);
    });

    test('saldo lama ditandai kedaluwarsa; tanpa akun = belum ada saldo', () {
      final stale = RealityCheck.compute(
        accounts: [makeAccount('a', 1, confirmedAt: DateTime(2026, 10, 1))],
        bills: const [],
        now: now,
      );
      expect(stale.balanceStale, isTrue);
      final none = RealityCheck.compute(
        accounts: const [],
        bills: const [],
        now: now,
      );
      expect(none.hasAccounts, isFalse);
    });

    test('target harian memakai hari kerja dan tidak memakai tagihan jauh', () {
      final rc = RealityCheck.compute(
        accounts: [makeAccount('a', 0, confirmedAt: now)],
        bills: [
          makeBill('s', 300000, due: DateTime(2026, 10, 20)),
          makeBill('l', 9000000, due: DateTime(2027, 3, 1)),
        ],
        now: now,
        workdays: 10,
      );
      expect(rc.target.status, IncomeTargetStatus.ready);
      expect(rc.target.dailyTarget, 30000);
    });
  });

  group('NextActionAdvisor & Reschedule', () {
    final now = DateTime(2026, 10, 10, 12);

    NextAction? choose(List<Task> tasks, {List<Bill> bills = const []}) =>
        NextActionAdvisor.choose(
          now: now,
          activeTasks: tasks,
          unpaidBills: bills,
          dueRoutineCount: 0,
          needsReviewItemCount: 0,
        );

    test('tugas terlambat didahulukan', () {
      final a = choose([
        makeTask('b', due: DateTime(2026, 10, 11)),
        makeTask('a', due: DateTime(2026, 10, 8)),
      ]);
      expect(a!.kind, NextActionKind.overdueTask);
      expect(a.targetId, 'a');
    });

    test('tugas besok mengalahkan tugas jauh walau prioritas lebih rendah', () {
      final a = choose([
        makeTask(
          'far',
          due: DateTime(2026, 12, 1),
          priority: TaskPriority.urgent,
        ),
        makeTask('soon', due: DateTime(2026, 10, 11)),
      ]);
      expect(a!.targetId, 'soon');
    });

    test('tidak ada yang mendesak -> null, bukan karangan', () {
      expect(choose(const []), isNull);
    });

    test('Reschedule.shift mempertahankan jam; default 23:59', () {
      expect(
        Reschedule.shift(DateTime(2026, 10, 1, 9, 30), now, 1),
        DateTime(2026, 10, 11, 9, 30),
      );
      expect(Reschedule.shift(null, now, 2), DateTime(2026, 10, 12, 23, 59));
    });
  });
}
