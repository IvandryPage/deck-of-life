import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/core/database/app_database.dart';
import 'package:deck_of_life/core/database/migrations/migrations.dart';
import 'package:deck_of_life/data/repositories/event_repository_impl.dart';
import 'package:deck_of_life/data/repositories/finance_repository_impl.dart';
import 'package:deck_of_life/data/repositories/reminder_repository_impl.dart';
import 'package:deck_of_life/data/repositories/routine_repository_impl.dart';
import 'package:deck_of_life/data/repositories/saved_item_repository_impl.dart';
import 'package:deck_of_life/data/repositories/settings_repository_impl.dart';
import 'package:deck_of_life/data/repositories/task_repository_impl.dart';
import 'package:deck_of_life/core/state/data_revision.dart';
import 'package:deck_of_life/features/calendar/controllers/calendar_controller.dart';
import 'package:deck_of_life/domain/entities/entities.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/domain/entities/logic.dart';
import 'package:deck_of_life/domain/repositories/ports.dart';
import 'package:deck_of_life/domain/usecases/reminder_coordinator.dart';
import 'package:deck_of_life/domain/usecases/usecases.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

class FakeScheduler implements NotificationScheduler {
  final Map<int, DateTime> scheduled = {};
  final List<int> cancelled = [];

  @override
  Future<bool> areNotificationsEnabled() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async => scheduled[id] = at;
  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {}
  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async => scheduled.clear();
}

class FakeLookup implements ReminderTargetLookup {
  @override
  Future<String?> titleOf(ReminderTargetType type, String targetId) async =>
      'x';
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late TaskRepositoryImpl tasks;
  late FinanceRepositoryImpl finance;
  late ReminderRepositoryImpl reminders;
  late SavedItemRepositoryImpl items;
  late EventRepositoryImpl events;
  late FakeScheduler scheduler;
  late ReminderCoordinator coordinator;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    tasks = TaskRepositoryImpl(db);
    finance = FinanceRepositoryImpl(db);
    reminders = ReminderRepositoryImpl(db);
    items = SavedItemRepositoryImpl(db);
    events = EventRepositoryImpl(db);
    scheduler = FakeScheduler();
    coordinator = ReminderCoordinator(
      reminders: reminders,
      scheduler: scheduler,
      lookup: FakeLookup(),
      settings: SettingsRepositoryImpl(db),
    );
  });

  tearDown(() async => db.close());

  Task recurring(String id, DateTime due, String rule) => Task(
    id: id,
    title: 'Laporan mingguan',
    status: TaskStatus.todo,
    priority: TaskPriority.normal,
    dueAt: due,
    recurrenceRule: rule,
    createdAt: t0,
    updatedAt: t0,
  );

  group('Tugas berulang', () {
    test(
      'selesai -> tugas berikutnya dibuat sekali, pengingat ikut bergeser',
      () async {
        final now = DateTime.now();
        final due = DateTime(now.year, now.month, now.day + 1, 9);
        await tasks.create(recurring('t1', due, 'weekly'));
        await coordinator.setReminder(
          ReminderTargetType.task,
          't1',
          due.subtract(const Duration(hours: 2)),
        );

        final change = ChangeTaskStatus(tasks, reminders, coordinator);
        final next = await change('t1', TaskStatus.done);
        expect(next, isNotNull);
        expect(next!.dueAt, DateTime(due.year, due.month, due.day + 7, 9));
        expect((await tasks.getById('t1'))!.status, TaskStatus.done);
        expect(
          await reminders.getForTarget(ReminderTargetType.task, 't1'),
          isNull,
        );
        final r = await reminders.getForTarget(
          ReminderTargetType.task,
          next.id,
        );
        expect(r!.remindAt, next.dueAt!.subtract(const Duration(hours: 2)));

        // Idempoten: kemunculan yang sama tidak dibuat ganda.
        expect(
          await tasks.createNextOccurrence(
            (await tasks.getById('t1'))!,
            next.dueAt!,
          ),
          isNull,
        );
        final active = await tasks.list(statuses: {TaskStatus.todo});
        expect(active.length, 1);
      },
    );

    test('tugas biasa selesai tidak membuat tugas baru', () async {
      await tasks.create(makeTask('p', due: DateTime(2030, 1, 1)));
      final next = await ChangeTaskStatus(tasks, reminders, coordinator)(
        'p',
        TaskStatus.done,
      );
      expect(next, isNull);
    });

    test(
      'tugas harian yang terlambat 5 hari tidak melahirkan tugas yang sudah terlambat',
      () async {
        final now = DateTime(2026, 10, 10, 12);
        await tasks.create(recurring('d', DateTime(2026, 10, 5, 9), 'daily'));
        final next = await ChangeTaskStatus(tasks, reminders, coordinator)(
          'd',
          TaskStatus.done,
          now: now,
        );
        expect(next!.dueAt!.isAfter(now), isTrue);
      },
    );

    test('konteks (item tersimpan) terbawa ke tugas berikutnya', () async {
      await items.create(makeItem('i1'));
      await tasks.create(
        recurring('t1', DateTime(2030, 1, 1, 9), 'daily'),
        savedItemIds: ['i1'],
      );
      final next = await ChangeTaskStatus(tasks, reminders, coordinator)(
        't1',
        TaskStatus.done,
        now: DateTime(2029, 12, 31),
      );
      expect((await tasks.savedItemsFor(next!.id)).single.id, 'i1');
    });
  });

  group('Tagihan berulang', () {
    test('dibayar -> tagihan bulan depan dibuat; tidak ganda', () async {
      await finance.createBill(
        Bill(
          id: 'b1',
          title: 'Kost',
          amount: 800000,
          dueAt: DateTime(2026, 10, 31, 9),
          recurrenceRule: 'monthly:31',
          createdAt: t0,
          updatedAt: t0,
        ),
      );
      final pay = MarkBillPaid(finance, reminders, coordinator);
      await finance.createAccount(makeAccount('wallet', 1000000));
      final next = await pay(
        'b1',
        accountId: 'wallet',
        now: DateTime(2026, 10, 30),
      );
      expect(next, isNotNull);
      expect(next!.dueAt, DateTime(2026, 11, 30, 9));
      expect(next.status, BillStatus.unpaid);
      expect((await finance.getBill('b1'))!.status, BillStatus.paid);
      // Hanya satu yang belum dibayar: tidak terhitung dua kali.
      expect((await finance.bills(statuses: {BillStatus.unpaid})).length, 1);
      final bill = (await finance.getBill('b1'))!;
      expect(await finance.createNextBillIfAbsent(bill, next.dueAt), isNull);

      await pay.undo();
      expect((await finance.getBill('b1'))!.status, BillStatus.unpaid);
      expect(await finance.bills(statuses: {BillStatus.unpaid}), hasLength(1));
      expect(await finance.recentTransactions(), isEmpty);
      expect((await finance.accounts()).single.confirmedBalance, 1000000);
    });
  });

  group('Pengingat', () {
    test(
      'pruneOrphans membuang pengingat tugas selesai & item yang sudah ditinjau',
      () async {
        await tasks.create(makeTask('t1', due: DateTime(2030, 1, 1)));
        await items.create(makeItem('i1'));
        final future = DateTime.now().add(const Duration(days: 2));
        await reminders.upsertForTarget(
          type: ReminderTargetType.task,
          targetId: 't1',
          remindAt: future,
        );
        await reminders.upsertForTarget(
          type: ReminderTargetType.savedItem,
          targetId: 'i1',
          remindAt: future,
        );
        // Ubah status lewat SQL langsung = situasi data tidak konsisten (mis. hasil restore).
        await db.raw.update('tasks', {'status': 'done'}, where: "id = 't1'");
        await db.raw.update('saved_items', {
          'review_status': 'reviewed',
        }, where: "id = 'i1'");

        final ids = await reminders.pruneOrphans();
        expect(ids.length, 2);
        expect(await reminders.listEnabled(), isEmpty);
      },
    );

    test('reconcileAll tidak menjadwalkan ulang pengingat yatim', () async {
      await tasks.create(makeTask('t1', due: DateTime(2030, 1, 1)));
      final future = DateTime.now().add(const Duration(days: 2));
      await coordinator.setReminder(ReminderTargetType.task, 't1', future);
      expect(scheduler.scheduled, isNotEmpty);
      await db.raw.update('tasks', {'status': 'cancelled'}, where: "id = 't1'");
      await coordinator.reconcileAll();
      expect(scheduler.scheduled, isEmpty);
    });

    test('meninjau item membatalkan pengingat "periksa"-nya', () async {
      await items.create(makeItem('i1'));
      await reminders.upsertForTarget(
        type: ReminderTargetType.savedItem,
        targetId: 'i1',
        remindAt: DateTime.now().add(const Duration(days: 1)),
      );
      final ids = await items.setReviewStatus('i1', ReviewStatus.reviewed);
      expect(ids.length, 1);
      expect(
        await reminders.getForTarget(ReminderTargetType.savedItem, 'i1'),
        isNull,
      );
    });
  });

  group('Pemulihan & pencarian', () {
    test('RescheduleTask menggeser tenggat dan pengingat', () async {
      final now = DateTime(2026, 10, 10, 12);
      await tasks.create(makeTask('t1', due: DateTime(2026, 10, 8, 9)));
      await reminders.upsertForTarget(
        type: ReminderTargetType.task,
        targetId: 't1',
        remindAt: DateTime(2026, 10, 8, 8),
      );
      await RescheduleTask(tasks, reminders, coordinator)('t1', 1, now: now);
      expect((await tasks.getById('t1'))!.dueAt, DateTime(2026, 10, 11, 9));
    });

    test(
      'findDuplicate: URL sama atau isi sama; tidak cocok -> null',
      () async {
        await items.create(
          makeItem('i1', url: 'https://a.id/x', content: 'halo'),
        );
        expect((await items.findDuplicate(url: 'https://a.id/x'))!.id, 'i1');
        expect((await items.findDuplicate(content: '  halo '))!.id, 'i1');
        expect(await items.findDuplicate(url: 'https://b.id'), isNull);
        expect(await items.findDuplicate(), isNull);
      },
    );

    test(
      'pencarian global mencakup item, tugas, agenda, dan tagihan',
      () async {
        await items.create(makeItem('i1', title: 'Skripsi bab 1'));
        await tasks.create(makeTask('t1', title: 'Revisi skripsi'));
        await events.create(
          Event(
            id: 'e1',
            title: 'Bimbingan skripsi',
            startsAt: DateTime(2026, 11, 2, 10),
            createdAt: t0,
            updatedAt: t0,
          ),
        );
        await finance.createBill(
          Bill(
            id: 'b1',
            title: 'Cetak skripsi',
            amount: 50000,
            dueAt: DateTime(2026, 11, 3),
            createdAt: t0,
            updatedAt: t0,
          ),
        );
        final r = await SearchAll(items, tasks, events, finance)('skripsi');
        expect(r.items.length, 1);
        expect(r.tasks.length, 1);
        expect(r.events.length, 1);
        expect(r.bills.length, 1);
        expect(r.total, 4);
      },
    );

    test(
      'GetDashboard: overdue, tindakan berikutnya, tanpa hitung ganda',
      () async {
        final now = DateTime(2026, 10, 10, 12);
        await tasks.create(makeTask('late', due: DateTime(2026, 10, 8)));
        await finance.createAccount(makeAccount('a', 500000, confirmedAt: now));
        await finance.createBill(
          makeBill('b1', 200000, due: DateTime(2026, 10, 15)),
        );
        await finance.createBill(
          makeBill('b2', 999999, status: BillStatus.paid),
        );
        final d = await GetDashboard(
          events: events,
          tasks: tasks,
          savedItems: items,
          finance: finance,
          routines: RoutineRepositoryImpl(db),
          settings: SettingsRepositoryImpl(db),
        )(now: now);
        expect(d.overdueTasks.single.id, 'late');
        expect(d.nextAction!.kind, NextActionKind.overdueTask);
        expect(d.reality.unpaidTotal, 200000);
        expect(d.reality.estimatedFree, 300000);
        expect(d.backupReminder, isTrue);
      },
    );
  });

  group('Kalender', () {
    test(
      'mengelompokkan agenda, deadline tugas, dan tagihan per hari',
      () async {
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, 15, 10);
        await events.create(
          Event(
            id: 'e1',
            title: 'Rapat',
            startsAt: day,
            createdAt: t0,
            updatedAt: t0,
          ),
        );
        await tasks.create(
          makeTask('t1', due: DateTime(now.year, now.month, 15, 17)),
        );
        await tasks.create(
          makeTask('t2', due: DateTime(now.year, now.month, 16, 17)),
        );
        await finance.createBill(
          makeBill('b1', 100000, due: DateTime(now.year, now.month, 15, 23)),
        );

        final c = CalendarController(
          events,
          tasks,
          finance,
          DeleteEvent(events, coordinator),
          DataRevision(),
        );
        await c.load();

        expect(c.eventsOn(day).single.id, 'e1');
        expect(c.tasksOn(day).single.id, 't1');
        expect(c.billsOn(day).single.id, 'b1');
        expect(c.markersOn(day), 3);
        expect(c.markersOn(DateTime(now.year, now.month, 16)), 1);
        expect(c.markersOn(DateTime(now.year, now.month, 20)), 0);
        expect(c.errorMessage.value, isNull);
      },
    );
  });

  group('Migrasi v1 -> v3 mempertahankan data', () {
    test('database v1 berisi data dibuka oleh aplikasi v3', () async {
      final tmp = Directory.systemTemp.createTempSync('dol_mig_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = '${tmp.path}/v1.db';

      // Buat DB persis seperti rilis lama (hanya migrasi 1).
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
          onCreate: (d, v) async {
            for (final sql in migrations.first) {
              await d.execute(sql);
            }
          },
        ),
      );
      await old.insert('tasks', {
        'id': 'old1',
        'title': 'Tugas lama',
        'created_at': '2026-10-01T08:00:00+07:00',
        'updated_at': '2026-10-01T08:00:00+07:00',
      });
      await old.close();

      final upgraded = await AppDatabase.open(path: path);
      addTearDown(upgraded.close);
      final t = await TaskRepositoryImpl(upgraded).getById('old1');
      expect(t!.title, 'Tugas lama');
      expect(t.recurrenceRule, isNull);
      expect(AppDatabase.schemaVersion, 3);
    });
  });
}
