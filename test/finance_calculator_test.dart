import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/domain/entities/enums.dart';
import 'package:deck_of_life/domain/entities/logic.dart';

import 'helpers.dart';

void main() {
  group('FinanceCalculator.summarize', () {
    test('menjumlahkan saldo akun aktif saja', () {
      final s = FinanceCalculator.summarize(
        [
          makeAccount('a', 1000000),
          makeAccount('b', 250000),
          makeAccount('c', 9999999, active: false),
        ],
        const [],
      );
      expect(s.confirmedTotal, 1250000);
      expect(s.hasAccounts, isTrue);
    });

    test('hanya tagihan unpaid yang mengurangi uang bebas', () {
      final s = FinanceCalculator.summarize(
        [makeAccount('a', 1000000)],
        [
          makeBill('1', 400000),
          makeBill('2', 300000, status: BillStatus.paid),
          makeBill('3', 200000, status: BillStatus.cancelled),
        ],
      );
      expect(s.knownUnpaidBills, 400000);
      expect(s.estimatedFreeMoney, 600000);
    });

    test('tagihan tidak terhitung dua kali setelah dibayar', () {
      final accounts = [makeAccount('a', 1000000)];
      final before = FinanceCalculator.summarize(accounts, [makeBill('1', 400000)]);
      final after = FinanceCalculator.summarize(
        accounts,
        [makeBill('1', 400000, status: BillStatus.paid)],
      );
      expect(before.estimatedFreeMoney, 600000);
      expect(after.estimatedFreeMoney, 1000000);
    });

    test('uang bebas boleh negatif', () {
      final s = FinanceCalculator.summarize(
        [makeAccount('a', 100000)],
        [makeBill('1', 350000)],
      );
      expect(s.estimatedFreeMoney, -250000);
    });

    test('tanpa akun: hasAccounts false (UI tidak menampilkan Rp0 palsu)', () {
      final s = FinanceCalculator.summarize(const [], const []);
      expect(s.hasAccounts, isFalse);
      expect(s.lastConfirmedAt, isNull);
    });

    test('melacak waktu konfirmasi terbaru dan terlama', () {
      final s = FinanceCalculator.summarize(
        [
          makeAccount('a', 1, confirmedAt: DateTime(2026, 10, 1)),
          makeAccount('b', 1, confirmedAt: DateTime(2026, 10, 20)),
        ],
        const [],
      );
      expect(s.lastConfirmedAt, DateTime(2026, 10, 20));
      expect(s.oldestConfirmedAt, DateTime(2026, 10, 1));
    });
  });

  group('FinanceCalculator.dailyIncomeTarget', () {
    test('membulatkan ke atas', () {
      final t = FinanceCalculator.dailyIncomeTarget(
        upcomingObligations: 1500001,
        availableFunds: 500000,
        workdays: 3,
      );
      expect(t.status, IncomeTargetStatus.ready);
      expect(t.fundingGap, 1000001);
      expect(t.dailyTarget, 333334);
    });

    test('pemasukan terkonfirmasi mengurangi kekurangan', () {
      final t = FinanceCalculator.dailyIncomeTarget(
        upcomingObligations: 2000000,
        availableFunds: 500000,
        confirmedIncome: 700000,
        workdays: 4,
      );
      expect(t.fundingGap, 800000);
      expect(t.dailyTarget, 200000);
    });

    test('dana cukup: tidak perlu target', () {
      final t = FinanceCalculator.dailyIncomeTarget(
        upcomingObligations: 500000,
        availableFunds: 900000,
        workdays: 5,
      );
      expect(t.status, IncomeTargetStatus.notNeeded);
      expect(t.fundingGap, 0);
      expect(t.dailyTarget, 0);
    });

    test('hari kerja null: meminta input, bukan membagi nol', () {
      final t = FinanceCalculator.dailyIncomeTarget(
        upcomingObligations: 1000000,
        availableFunds: 0,
      );
      expect(t.status, IncomeTargetStatus.needsWorkdays);
      expect(t.dailyTarget, isNull);
      expect(t.fundingGap, 1000000);
    });

    test('hari kerja nol atau negatif: tidak melempar', () {
      for (final d in [0, -2]) {
        final t = FinanceCalculator.dailyIncomeTarget(
          upcomingObligations: 1000000,
          availableFunds: 0,
          workdays: d,
        );
        expect(t.status, IncomeTargetStatus.needsWorkdays);
        expect(t.dailyTarget, isNull);
      }
    });

    test('kekurangan nol dengan hari kerja nol tetap aman', () {
      final t = FinanceCalculator.dailyIncomeTarget(
        upcomingObligations: 0,
        availableFunds: 0,
        workdays: 0,
      );
      expect(t.status, IncomeTargetStatus.notNeeded);
    });
  });
}
