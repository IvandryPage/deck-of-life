import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/core/utils/date_time_utils.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/domain/entities/logic.dart';

import 'helpers.dart';

void main() {
  final now = DateTime(2026, 10, 26, 12);

  group('TaskOrdering.sorted (TDD 6.2)', () {
    test(
      'overdue, lalu urgent/high bertenggat, lalu bertenggat lain, lalu tanpa tenggat',
      () {
        final tasks = [
          makeTask('none'),
          makeTask('later', due: DateTime(2026, 11, 3)),
          makeTask(
            'high',
            due: DateTime(2026, 11, 10),
            priority: TaskPriority.high,
          ),
          makeTask('over', due: DateTime(2026, 10, 25)),
        ];
        final ids = TaskOrdering.sorted(tasks, now).map((t) => t.id).toList();
        expect(ids, ['over', 'high', 'later', 'none']);
      },
    );

    test('di dalam kelompok sama: tenggat terdekat lebih dulu', () {
      final tasks = [
        makeTask('b', due: DateTime(2026, 10, 30)),
        makeTask('a', due: DateTime(2026, 10, 28)),
      ];
      expect(TaskOrdering.sorted(tasks, now).map((t) => t.id), ['a', 'b']);
    });

    test(
      'tanpa tenggat: prioritas tinggi lebih dulu, lalu yang lebih lama dibuat',
      () {
        final tasks = [
          makeTask('old', createdAt: DateTime(2026, 9, 1)),
          makeTask('new', createdAt: DateTime(2026, 10, 1)),
          makeTask(
            'urgent',
            priority: TaskPriority.urgent,
            createdAt: DateTime(2026, 10, 10),
          ),
        ];
        expect(TaskOrdering.sorted(tasks, now).map((t) => t.id), [
          'urgent',
          'old',
          'new',
        ]);
      },
    );

    test('tidak mengubah daftar asli', () {
      final tasks = [
        makeTask('b', due: DateTime(2026, 11, 1)),
        makeTask('a', due: DateTime(2026, 10, 1)),
      ];
      TaskOrdering.sorted(tasks, now);
      expect(tasks.first.id, 'b');
    });
  });

  group('TaskOrdering.nearestDeadlines', () {
    test(
      'maksimal tiga, overdue lebih dulu, mengabaikan selesai dan tanpa tenggat',
      () {
        final tasks = [
          makeTask('d4', due: DateTime(2026, 11, 20)),
          makeTask('d1', due: DateTime(2026, 10, 27)),
          makeTask('none'),
          makeTask(
            'done',
            due: DateTime(2026, 10, 20),
            status: TaskStatus.done,
          ),
          makeTask('over', due: DateTime(2026, 10, 24)),
          makeTask('d3', due: DateTime(2026, 11, 5)),
          makeTask('d2', due: DateTime(2026, 10, 30)),
          makeTask(
            'cancelled',
            due: DateTime(2026, 10, 21),
            status: TaskStatus.cancelled,
          ),
        ];
        final ids = TaskOrdering.nearestDeadlines(
          tasks,
        ).map((t) => t.id).toList();
        expect(ids, ['over', 'd1', 'd2']);
      },
    );

    test('kurang dari tiga tugas bertenggat: tidak memaksa isi', () {
      expect(TaskOrdering.nearestDeadlines([makeTask('none')]), isEmpty);
    });
  });

  group('DueLabel', () {
    test('label relatif', () {
      expect(DueLabel.of(null, now: now), 'No deadline');
      expect(DueLabel.of(DateTime(2026, 10, 26, 20), now: now), 'Today');
      expect(DueLabel.of(DateTime(2026, 10, 27, 9), now: now), 'Tomorrow');
      expect(DueLabel.of(DateTime(2026, 10, 29, 9), now: now), 'In 3 days');
      expect(
        DueLabel.of(DateTime(2026, 10, 24, 9), now: now),
        'Overdue by 2 days',
      );
      expect(
        DueLabel.of(DateTime(2026, 10, 26, 8), now: now),
        'Overdue (today)',
      );
    });
  });
}
