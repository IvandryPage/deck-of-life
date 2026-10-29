import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:deck_of_life/app/design/tokens.dart';
import 'package:deck_of_life/app/theme.dart';
import 'package:deck_of_life/core/widgets/common_widgets.dart';
import 'package:deck_of_life/core/widgets/form_widgets.dart';
import 'package:deck_of_life/domain/entities/entities.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/features/inbox/widgets/saved_item_tile.dart';
import 'package:deck_of_life/features/tasks/controllers/tasks_controller.dart';
import 'package:deck_of_life/features/tasks/widgets/task_tile.dart';

import 'helpers.dart';

Widget host(
  Widget child, {
  Brightness b = Brightness.light,
  double textScale = 1,
  double width = 360,
}) => MaterialApp(
  theme: buildAppTheme(b),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));
  formTests();

  group('Tema & token', () {
    test('light dan dark memuat warna semantik', () {
      for (final b in Brightness.values) {
        final t = buildAppTheme(b);
        expect(t.extension<AppSemanticColors>(), isNotNull);
        expect(t.colorScheme.brightness, b);
      }
    });

    test('tidak ada teks di bawah 12sp dan target sentuh 48dp', () {
      final t = buildAppTheme(Brightness.light);
      for (final s in [
        t.textTheme.bodySmall,
        t.textTheme.labelSmall,
        t.textTheme.labelMedium,
      ]) {
        expect(s!.fontSize, greaterThanOrEqualTo(12));
      }
      expect(AppSize.tap, 48);
    });

    test('durasi animasi mengikuti rentang token', () {
      expect(AppMotion.micro.inMilliseconds, inInclusiveRange(100, 160));
      expect(AppMotion.standard.inMilliseconds, inInclusiveRange(180, 260));
      expect(AppMotion.emphasized.inMilliseconds, inInclusiveRange(260, 350));
    });
  });

  group('Komponen', () {
    testWidgets('EmptyState memanggil aksi utama', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: Icons.inbox,
            title: 'Kosong',
            actionLabel: 'Tambah',
            onAction: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.text('Tambah'));
      expect(tapped, isTrue);
    });

    testWidgets('AmountText panjang tidak overflow di lebar sempit', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SizedBox(width: 90, child: AmountText('-Rp 123.456.789.012')),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatusTag selalu menampilkan teks (tidak hanya warna)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const StatusTag('Terlambat', warning: true)),
      );
      expect(find.text('Terlambat'), findsOneWidget);
    });

    testWidgets('SkeletonList tampil tanpa error, juga dengan reduce-motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: SkeletonList(rows: 3)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });

  group('TaskTile', () {
    testWidgets('tugas terlambat diberi tag teks "Overdue"', (tester) async {
      final t = makeTask(
        'a',
        due: DateTime.now().subtract(const Duration(days: 2)),
      );
      await tester.pumpWidget(
        host(TaskTile(task: t, onTap: () {}, onToggleDone: () {})),
      );
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('ketuk kotak centang memanggil onToggleDone', (tester) async {
      var toggled = 0;
      final t = makeTask('a', due: DateTime.now().add(const Duration(days: 2)));
      await tester.pumpWidget(
        host(TaskTile(task: t, onTap: () {}, onToggleDone: () => toggled++)),
      );
      await tester.tap(find.byType(Checkbox));
      expect(toggled, 1);
    });

    testWidgets('judul sangat panjang + teks 2x tidak overflow', (
      tester,
    ) async {
      final t = makeTask(
        'a',
        title: 'Menyusun laporan akhir praktikum basis data terdistribusi ' * 3,
        due: DateTime.now().add(const Duration(days: 1)),
      );
      await tester.pumpWidget(
        host(
          TaskTile(task: t, onTap: () {}, onToggleDone: () {}),
          textScale: 2,
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tugas selesai dicoret dan label semantik menyebut "done"', (
      tester,
    ) async {
      final t = makeTask('a', status: TaskStatus.done);
      await tester.pumpWidget(
        host(TaskTile(task: t, onTap: () {}, onToggleDone: () {})),
      );
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('done')), findsWidgets);
      handle.dispose();
    });
  });

  group('Pengelompokan tugas', () {
    test('terlambat / hari ini / mendatang / tanpa deadline', () {
      final now = DateTime(2026, 10, 10, 12);
      final g = TasksController.bucketize([
        makeTask('o', due: DateTime(2026, 10, 9)),
        makeTask('t', due: DateTime(2026, 10, 10, 18)),
        makeTask('u', due: DateTime(2026, 10, 20)),
        makeTask('n'),
      ], now);
      expect(g[TaskBucket.overdue]!.single.id, 'o');
      expect(g[TaskBucket.today]!.single.id, 't');
      expect(g[TaskBucket.upcoming]!.single.id, 'u');
      expect(g[TaskBucket.noDeadline]!.single.id, 'n');
    });

    test('tugas hari ini yang jamnya sudah lewat dihitung terlambat', () {
      final now = DateTime(2026, 10, 10, 12);
      final g = TasksController.bucketize([
        makeTask('x', due: DateTime(2026, 10, 10, 8)),
      ], now);
      expect(g[TaskBucket.overdue]!.length, 1);
    });
  });

  group('SavedItemTile', () {
    testWidgets('share yang belum diperiksa ditandai New', (tester) async {
      final item = SavedItem(
        id: 'shared',
        title: 'Shared item',
        contentText: '',
        itemType: SavedItemType.note,
        sourceApp: 'share_sheet',
        reviewStatus: ReviewStatus.needsReview,
        createdAt: t0,
        updatedAt: t0,
      );
      await tester.pumpWidget(host(SavedItemTile(item: item, onTap: () {})));
      expect(find.byTooltip('New'), findsOneWidget);
    });

    testWidgets('New hilang setelah note diperiksa', (tester) async {
      final item = SavedItem(
        id: 'shared',
        title: 'Shared item',
        contentText: '',
        itemType: SavedItemType.note,
        sourceApp: 'share_sheet',
        reviewStatus: ReviewStatus.reviewed,
        createdAt: t0,
        updatedAt: t0,
      );
      await tester.pumpWidget(host(SavedItemTile(item: item, onTap: () {})));
      expect(find.byTooltip('New'), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Formulir: opsi lanjutan tersembunyi sampai dibuka.
// ---------------------------------------------------------------------------
void formTests() {
  group('AdvancedOptions & FormPage', () {
    testWidgets('tersembunyi sampai tombol kecil diketuk', (tester) async {
      await tester.pumpWidget(
        host(const AdvancedOptions(children: [TextField(key: Key('adv'))])),
      );
      expect(find.byKey(const Key('adv')), findsNothing);
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adv')), findsOneWidget);
      await tester.tap(find.textContaining('Hide'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adv')), findsNothing);
    });

    testWidgets('terbuka otomatis bila ada isian lanjutan', (tester) async {
      await tester.pumpWidget(
        host(
          const AdvancedOptions(
            initiallyOpen: true,
            children: [TextField(key: Key('adv'))],
          ),
        ),
      );
      expect(find.byKey(const Key('adv')), findsOneWidget);
    });

    testWidgets(
      'FormPage: tombol simpan memanggil onSave dan nonaktif saat menyimpan',
      (tester) async {
        var saved = 0;
        Widget page(bool saving) => MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: FormPage(
            title: 'Tes',
            onSave: () => saved++,
            saving: saving,
            children: const [TextField()],
          ),
        );
        await tester.pumpWidget(page(false));
        await tester.tap(find.text('Save'));
        expect(saved, 1);
        await tester.pumpWidget(page(true));
        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        expect(saved, 1);
      },
    );
  });
}
