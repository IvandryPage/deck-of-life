import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/core/backup/backup_service.dart';
import 'package:deck_of_life/core/database/app_database.dart';
import 'package:deck_of_life/core/errors/app_exception.dart';
import 'package:deck_of_life/data/repositories/event_repository_impl.dart';
import 'package:deck_of_life/data/repositories/finance_repository_impl.dart';
import 'package:deck_of_life/data/repositories/reminder_repository_impl.dart';
import 'package:deck_of_life/data/repositories/routine_repository_impl.dart';
import 'package:deck_of_life/data/repositories/saved_item_repository_impl.dart';
import 'package:deck_of_life/data/repositories/task_repository_impl.dart';
import 'package:deck_of_life/domain/entities/entities.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/domain/entities/logic.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

/// Pengujian terhadap SQLite nyata (in-memory) lewat sqflite_common_ffi.
/// Membutuhkan pustaka sqlite3 di mesin dev (`flutter test` di desktop).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late SavedItemRepositoryImpl items;
  late TaskRepositoryImpl tasks;
  late EventRepositoryImpl events;
  late ReminderRepositoryImpl reminders;
  late FinanceRepositoryImpl finance;
  late RoutineRepositoryImpl routines;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    items = SavedItemRepositoryImpl(db);
    tasks = TaskRepositoryImpl(db);
    events = EventRepositoryImpl(db);
    reminders = ReminderRepositoryImpl(db);
    finance = FinanceRepositoryImpl(db);
    routines = RoutineRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  group('SavedItem', () {
    test('simpan, baca, ubah, arsip', () async {
      await items.create(makeItem('a', content: 'isi', course: 'Basis Data'));
      final read = await items.getById('a');
      expect(read, isNotNull);
      expect(read!.title, 'Item a');
      expect(read.courseName, 'Basis Data');
      expect(read.needsReview, isTrue);

      await items.update(SavedItem(
        id: 'a',
        title: 'Judul baru',
        contentText: 'isi',
        itemType: SavedItemType.note,
        reviewStatus: ReviewStatus.reviewed,
        createdAt: t0,
        updatedAt: t0,
      ));
      final updated = await items.getById('a');
      expect(updated!.title, 'Judul baru');
      expect(updated.createdAt, t0, reason: 'created_at tidak boleh berubah');
      expect(updated.updatedAt, isNot(t0), reason: 'updated_at harus diperbarui');

      await items.archive('a', DateTime.now());
      expect((await items.search('')).where((i) => i.id == 'a'), isEmpty);
      expect(
        (await items.search('', includeArchived: true)).map((i) => i.id),
        contains('a'),
      );
    });

    test('pencarian lintas judul, isi, konteks, grup, dan URL', () async {
      await items.create(makeItem('1', title: 'Tugas besar', content: 'normalisasi tabel'));
      await items.create(makeItem('2', course: 'Jaringan Komputer'));
      await items.create(makeItem('3', group: 'Grup Kelas B'));
      await items.create(makeItem('4', url: 'https://drive.google.com/file/d/xyz'));

      Future<List<String>> ids(String q) async =>
          (await items.search(q)).map((i) => i.id).toList();

      expect(await ids('normalisasi'), ['1']);
      expect(await ids('jaringan'), ['2']);
      expect(await ids('kelas b'), ['3']);
      expect(await ids('drive.google'), ['4']);
      expect(await ids('tidak ada'), isEmpty);
    });

    test('% dan _ dicari apa adanya, bukan wildcard', () async {
      await items.create(makeItem('1', title: 'Diskon 50% hari ini'));
      await items.create(makeItem('2', title: 'Diskon 500 rupiah'));
      expect((await items.search('50%')).map((i) => i.id), ['1']);
    });

    test('filter jenis dan mata kuliah', () async {
      await items.create(makeItem('1', type: SavedItemType.link, course: 'A'));
      await items.create(makeItem('2', type: SavedItemType.note, course: 'A'));
      await items.create(makeItem('3', type: SavedItemType.link, course: 'B'));
      final r = await items.search('', type: SavedItemType.link, courseName: 'A');
      expect(r.map((i) => i.id), ['1']);
    });

    test('hapus permanen melepas relasi tapi tidak menghapus tugas', () async {
      await items.create(makeItem('i'));
      await tasks.create(makeTask('t'), savedItemIds: ['i']);
      expect((await tasks.savedItemsFor('t')).length, 1);

      await items.deletePermanently('i');
      expect(await tasks.savedItemsFor('t'), isEmpty);
      expect(await tasks.getById('t'), isNotNull);
    });
  });

  group('Task', () {
    test('menghubungkan dua kali tidak membuat duplikat', () async {
      await items.create(makeItem('i'));
      await tasks.create(makeTask('t'));
      await tasks.linkSavedItem('t', 'i');
      await tasks.linkSavedItem('t', 'i');
      expect((await tasks.savedItemsFor('t')).length, 1);
      expect((await tasks.tasksForSavedItem('i')).length, 1);
    });

    test('foreign key ditegakkan: relasi ke item yang tidak ada gagal', () async {
      await tasks.create(makeTask('t'));
      expect(
        () => tasks.linkSavedItem('t', 'tidak-ada'),
        throwsA(isA<LocalDatabaseException>()),
      );
    });

    test('selesai mengisi completed_at, dibuka kembali mengosongkannya', () async {
      await tasks.create(makeTask('t'));
      await tasks.setStatus('t', TaskStatus.done);
      final done = await tasks.getById('t');
      expect(done!.status, TaskStatus.done);
      expect(done.completedAt, isNotNull);

      await tasks.setStatus('t', TaskStatus.todo);
      final reopened = await tasks.getById('t');
      expect(reopened!.completedAt, isNull);
    });

    test('menyelesaikan tugas menghapus pengingat dan mengembalikan ID notifikasi', () async {
      await tasks.create(makeTask('t'));
      final r = await reminders.upsertForTarget(
        type: ReminderTargetType.task,
        targetId: 't',
        remindAt: DateTime(2026, 12, 1, 9),
      );
      final ids = await tasks.setStatus('t', TaskStatus.done);
      expect(ids, [r.notificationId]);
      expect(await reminders.getForTarget(ReminderTargetType.task, 't'), isNull);
    });

    test('menghapus tugas membatalkan pengingat; event tertaut jadi tanpa tugas', () async {
      await tasks.create(makeTask('t'));
      final r = await reminders.upsertForTarget(
        type: ReminderTargetType.task,
        targetId: 't',
        remindAt: DateTime(2026, 12, 1, 9),
      );
      await events.create(Event(
        id: 'e',
        title: 'Rapat',
        startsAt: DateTime(2026, 12, 2, 9),
        linkedTaskId: 't',
        createdAt: t0,
        updatedAt: t0,
      ));

      final ids = await tasks.delete('t');
      expect(ids, [r.notificationId]);
      expect(await reminders.listEnabled(), isEmpty);
      expect((await events.getById('e'))!.linkedTaskId, isNull);
    });

    test('pencarian tugas', () async {
      await tasks.create(makeTask('a', title: 'Koreksi esai kelas 3'));
      await tasks.create(makeTask('b', title: 'Laporan lab'));
      expect((await tasks.search('esai')).map((t) => t.id), ['a']);
    });
  });

  group('Reminder', () {
    test('ID notifikasi unik, stabil, dan dimulai dari 1001', () async {
      final a = await reminders.upsertForTarget(
        type: ReminderTargetType.task,
        targetId: 'x',
        remindAt: DateTime(2026, 12, 1),
      );
      final b = await reminders.upsertForTarget(
        type: ReminderTargetType.bill,
        targetId: 'y',
        remindAt: DateTime(2026, 12, 2),
      );
      expect(a.notificationId, 1001);
      expect(b.notificationId, 1002);

      // Ubah waktu: baris dan ID yang sama dipakai ulang.
      final again = await reminders.upsertForTarget(
        type: ReminderTargetType.task,
        targetId: 'x',
        remindAt: DateTime(2026, 12, 5),
      );
      expect(again.id, a.id);
      expect(again.notificationId, 1001);
      expect(again.remindAt, DateTime(2026, 12, 5));
      expect(again.lastScheduledAt, isNull, reason: 'perlu dijadwalkan ulang ke OS');
    });
  });

  group('Event', () {
    test('listBetween memakai batas hari lokal', () async {
      Event ev(String id, DateTime at) => Event(
            id: id,
            title: id,
            startsAt: at,
            createdAt: t0,
            updatedAt: t0,
          );
      await events.create(ev('semalam', DateTime(2026, 10, 25, 23, 59)));
      await events.create(ev('pagi', DateTime(2026, 10, 26, 0, 0)));
      await events.create(ev('malam', DateTime(2026, 10, 26, 23, 59)));
      await events.create(ev('besok', DateTime(2026, 10, 27, 0, 0)));

      final today = await events.listBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 27));
      expect(today.map((e) => e.id), ['pagi', 'malam']);
    });
  });

  group('Keuangan', () {
    test('koreksi saldo memperbarui akun dan mencatat riwayat sekaligus', () async {
      await finance.createAccount(makeAccount('a', 500000));
      await finance.confirmBalance('a', 420000, reason: 'bayar kost');

      final acc = (await finance.accounts()).single;
      expect(acc.confirmedBalance, 420000);
      final adj = (await finance.adjustments('a')).single;
      expect(adj.previousBalance, 500000);
      expect(adj.correctedBalance, 420000);
      expect(adj.difference, -80000);
      expect(adj.reason, 'bayar kost');
    });

    test('saldo negatif ditolak dan tidak meninggalkan riwayat setengah jadi', () async {
      await finance.createAccount(makeAccount('a', 500000));
      await expectLater(
        finance.confirmBalance('a', -1),
        throwsA(isA<ValidationException>()),
      );
      expect((await finance.accounts()).single.confirmedBalance, 500000);
      expect(await finance.adjustments('a'), isEmpty);
    });

    test('koreksi saldo untuk akun yang tidak ada gagal tanpa efek samping', () async {
      await expectLater(
        finance.confirmBalance('tidak-ada', 100),
        throwsA(isA<ValidationException>()),
      );
    });

    test('transaksi opsional tidak mengubah saldo terkonfirmasi', () async {
      await finance.createAccount(makeAccount('a', 500000));
      await finance.addTransaction(MoneyTransaction(
        id: 'tx',
        accountId: 'a',
        amount: 100000,
        direction: TransactionDirection.expense,
        category: 'Makan',
        occurredAt: t0,
        createdAt: t0,
      ));
      expect((await finance.accounts()).single.confirmedBalance, 500000);
      expect((await finance.recentTransactions()).length, 1);
    });

    test('tagihan dibayar tidak lagi mengurangi uang bebas', () async {
      await finance.createAccount(makeAccount('a', 1000000));
      await finance.createBill(makeBill('b1', 400000));

      Future<int> free() async => FinanceCalculator.summarize(
            await finance.accounts(),
            await finance.bills(),
          ).estimatedFreeMoney;

      expect(await free(), 600000);
      await finance.markBillPaid('b1', DateTime.now());
      expect(await free(), 1000000);
    });

    test('menandai tagihan dibayar membersihkan pengingatnya', () async {
      await finance.createBill(makeBill('b1', 400000));
      final r = await reminders.upsertForTarget(
        type: ReminderTargetType.bill,
        targetId: 'b1',
        remindAt: DateTime(2026, 11, 4, 9),
      );
      final ids = await finance.markBillPaid('b1', DateTime.now());
      expect(ids, [r.notificationId]);
    });

    test('akun yang memiliki riwayat tidak bisa dihapus paksa (RESTRICT)', () async {
      await finance.createAccount(makeAccount('a', 1000));
      await finance.confirmBalance('a', 2000);
      await expectLater(
        db.raw.delete('accounts', where: 'id = ?', whereArgs: ['a']),
        throwsA(anything),
      );
    });
  });

  group('Rutinitas', () {
    test('complete: mencatat log, last_completed_at, dan next_due_at', () async {
      final r = makeRoutine(RecurrenceType.interval, interval: 3);
      await routines.create(Routine(
        id: r.id,
        title: r.title,
        recurrenceType: r.recurrenceType,
        intervalDays: 3,
        createdAt: t0,
        updatedAt: t0,
      ));

      final done = DateTime(2026, 10, 30, 9);
      final updated = await routines.complete('r1', done, note: 'selesai');
      expect(updated.lastCompletedAt, done);
      expect(updated.nextDueAt, DateTime(2026, 11, 2));

      final logs = await routines.logs('r1');
      expect(logs.length, 1);
      expect(logs.single.note, 'selesai');
    });

    test('hari terpilih mingguan tersimpan dan terbaca kembali', () async {
      await routines.create(Routine(
        id: 'w',
        title: 'Mingguan',
        recurrenceType: RecurrenceType.weekly,
        weekdays: const [1, 4],
        createdAt: t0,
        updatedAt: t0,
      ));
      expect((await routines.getById('w'))!.weekdays, [1, 4]);
    });
  });

  group('Backup & restore', () {
    Future<void> seed() async {
      await items.create(makeItem('i1', title: 'Info', content: 'isi', course: 'BD'));
      await tasks.create(makeTask('t1', due: DateTime(2026, 11, 1)), savedItemIds: ['i1']);
      await events.create(Event(
        id: 'e1',
        title: 'Kuliah',
        startsAt: DateTime(2026, 11, 2, 8),
        linkedTaskId: 't1',
        createdAt: t0,
        updatedAt: t0,
      ));
      await reminders.upsertForTarget(
        type: ReminderTargetType.task,
        targetId: 't1',
        remindAt: DateTime(2026, 10, 31, 9),
      );
      await finance.createAccount(makeAccount('a1', 750000));
      await finance.confirmBalance('a1', 700000, reason: 'koreksi');
      await finance.createBill(makeBill('b1', 300000));
      await routines.create(Routine(
        id: 'r9',
        title: 'Bersih-bersih',
        recurrenceType: RecurrenceType.interval,
        intervalDays: 3,
        createdAt: t0,
        updatedAt: t0,
      ));
    }

    test('ekspor lalu restore ke database kosong mempertahankan data dan relasi', () async {
      await seed();
      final exported = jsonEncode(await BackupService(db).buildBackup());

      final tmp = Directory.systemTemp.createTempSync('plh_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final target = await AppDatabase.open(path: '${tmp.path}/target.db');
      addTearDown(target.close);

      var restoredCallback = false;
      final service = BackupService(
        target,
        backupDirectory: () async => tmp,
        onRestored: () async => restoredCallback = true,
      );
      final result = await service.restore(exported);

      expect(restoredCallback, isTrue);
      expect(result.restoredRows, greaterThan(0));
      expect(File(result.safetyBackupPath).existsSync(), isTrue);

      final t = TaskRepositoryImpl(target);
      expect((await t.savedItemsFor('t1')).single.id, 'i1');
      expect((await EventRepositoryImpl(target).getById('e1'))!.linkedTaskId, 't1');
      expect(
        (await FinanceRepositoryImpl(target).accounts()).single.confirmedBalance,
        700000,
      );
      expect((await FinanceRepositoryImpl(target).adjustments('a1')).length, 1);
      expect(
        (await ReminderRepositoryImpl(target)
                .getForTarget(ReminderTargetType.task, 't1'))!
            .notificationId,
        1001,
      );
    });

    test('restore ke database yang sudah berisi data = mengganti semuanya', () async {
      await seed();
      final exported = jsonEncode(await BackupService(db).buildBackup());

      final tmp = Directory.systemTemp.createTempSync('plh_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final target = await AppDatabase.open(path: '${tmp.path}/target.db');
      addTearDown(target.close);
      await SavedItemRepositoryImpl(target).create(makeItem('lama'));

      await BackupService(target, backupDirectory: () async => tmp).restore(exported);

      final ids = (await SavedItemRepositoryImpl(target).search('', includeArchived: true))
          .map((i) => i.id)
          .toList();
      expect(ids, ['i1']);

      // Backup pengaman memuat data LAMA sehingga salah pilih berkas bisa dibatalkan.
      final safety = Directory('${tmp.path}/backups')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('pre-restore'))
          .single;
      expect(safety.readAsStringSync(), contains('"lama"'));
    });

    test('berkas rusak ditolak sebelum menyentuh data aktif', () async {
      await seed();
      final tmp = Directory.systemTemp.createTempSync('plh_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final service = BackupService(db, backupDirectory: () async => tmp);

      await expectLater(
        service.restore('{"format":"bukan-backup"}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect((await items.search('')).length, 1, reason: 'data aktif tidak boleh berubah');
      expect(Directory('${tmp.path}/backups').existsSync(), isFalse,
          reason: 'validasi gagal sebelum backup pengaman dibuat');
    });
  });
}
