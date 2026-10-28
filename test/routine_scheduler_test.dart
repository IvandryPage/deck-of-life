import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/domain/entities/entities.dart';
import 'package:deck_of_life/domain/entities/logic.dart';

import 'helpers.dart';

void main() {
  group('RoutineScheduler.nextDue', () {
    test('interval: menambah hari dari waktu selesai', () {
      final r = makeRoutine(RecurrenceType.interval, interval: 3);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 10, 26, 14, 20)),
        DateTime(2026, 10, 29),
      );
    });

    test('interval: pergantian bulan', () {
      final r = makeRoutine(RecurrenceType.interval, interval: 3);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 10, 30, 9)),
        DateTime(2026, 11, 2),
      );
    });

    test('interval: pergantian tahun', () {
      final r = makeRoutine(RecurrenceType.interval, interval: 3);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 12, 30, 9)),
        DateTime(2027, 1, 2),
      );
    });

    test('interval: tahun kabisat', () {
      final r = makeRoutine(RecurrenceType.interval, interval: 2);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2028, 2, 28, 9)),
        DateTime(2028, 3, 1),
      );
    });

    test('interval tidak valid: null', () {
      expect(
        RoutineScheduler.nextDue(
          makeRoutine(RecurrenceType.interval),
          DateTime(2026, 10, 26),
        ),
        isNull,
      );
      expect(
        RoutineScheduler.nextDue(
          makeRoutine(RecurrenceType.interval, interval: 0),
          DateTime(2026, 10, 26),
        ),
        isNull,
      );
    });

    test('harian dengan jam pilihan', () {
      final r = makeRoutine(RecurrenceType.daily, time: '07:30');
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 10, 26, 20)),
        DateTime(2026, 10, 27, 7, 30),
      );
    });

    test('tanpa jam pilihan: jatuh tempo sepanjang hari (00:00)', () {
      final r = makeRoutine(RecurrenceType.daily);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 10, 26, 20, 15)),
        DateTime(2026, 10, 27),
      );
    });

    test('mingguan: hari terpilih berikutnya setelah hari ini', () {
      // 26 Okt 2026 = Senin. Senin & Kamis -> Kamis 29 Okt.
      final r = makeRoutine(RecurrenceType.weekly, weekdays: [1, 4]);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 10, 26, 10)),
        DateTime(2026, 10, 29),
      );
    });

    test('mingguan: melewati akhir pekan ke Senin berikutnya', () {
      // Kamis 29 Okt -> Senin 2 Nov.
      final r = makeRoutine(RecurrenceType.weekly, weekdays: [1, 4]);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 10, 29, 10)),
        DateTime(2026, 11, 2),
      );
    });

    test('mingguan: satu hari terpilih = 7 hari lagi', () {
      final r = makeRoutine(RecurrenceType.weekly, weekdays: [1]);
      expect(
        RoutineScheduler.nextDue(r, DateTime(2026, 10, 26, 10)),
        DateTime(2026, 11, 2),
      );
    });

    test('mingguan tanpa hari: null', () {
      expect(
        RoutineScheduler.nextDue(
          makeRoutine(RecurrenceType.weekly),
          DateTime(2026, 10, 26),
        ),
        isNull,
      );
    });
  });

  group('RoutineScheduler.firstDue', () {
    final monday = DateTime(2026, 10, 26, 15); // Senin

    test('interval/harian: hari ini', () {
      expect(
        RoutineScheduler.firstDue(
          makeRoutine(RecurrenceType.interval, interval: 3),
          monday,
        ),
        DateTime(2026, 10, 26),
      );
      expect(
        RoutineScheduler.firstDue(
          makeRoutine(RecurrenceType.daily, time: '06:00'),
          monday,
        ),
        DateTime(2026, 10, 26, 6),
      );
    });

    test('mingguan: hari ini bila termasuk, jika tidak yang terdekat', () {
      expect(
        RoutineScheduler.firstDue(
          makeRoutine(RecurrenceType.weekly, weekdays: [1, 4]),
          monday,
        ),
        DateTime(2026, 10, 26),
      );
      expect(
        RoutineScheduler.firstDue(
          makeRoutine(RecurrenceType.weekly, weekdays: [3]),
          monday,
        ),
        DateTime(2026, 10, 28),
      );
    });
  });

  group('Routine due dan pengingat', () {
    test('isDue: jatuh tempo sepanjang hari ini', () {
      final r = Routine(
        id: 'r',
        title: 'x',
        recurrenceType: RecurrenceType.daily,
        nextDueAt: DateTime(2026, 10, 26),
        createdAt: t0,
        updatedAt: t0,
      );
      expect(r.isDue(DateTime(2026, 10, 26, 13)), isTrue);
      expect(r.isDue(DateTime(2026, 10, 25, 23)), isFalse);
    });

    test('reminderTime: 08:00 bila tanpa jam, jam pilihan bila ada', () {
      final noTime = Routine(
        id: 'r',
        title: 'x',
        recurrenceType: RecurrenceType.daily,
        nextDueAt: DateTime(2026, 10, 27),
        createdAt: t0,
        updatedAt: t0,
      );
      expect(RoutineScheduler.reminderTime(noTime), DateTime(2026, 10, 27, 8));

      final withTime = Routine(
        id: 'r',
        title: 'x',
        recurrenceType: RecurrenceType.daily,
        preferredTime: '07:30',
        nextDueAt: DateTime(2026, 10, 27, 7, 30),
        createdAt: t0,
        updatedAt: t0,
      );
      expect(
        RoutineScheduler.reminderTime(withTime),
        DateTime(2026, 10, 27, 7, 30),
      );
    });
  });
}
