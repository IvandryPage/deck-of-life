import 'dart:math' as math;

import '../../core/utils/date_time_utils.dart';
import 'entities.dart';
import 'enums.dart';

/// Logika bisnis murni (tanpa I/O). Semua diuji unit (TDD bagian 16).

// ---------------------------------------------------------------------------
// Keuangan (TDD 6.5)
// ---------------------------------------------------------------------------

class FinanceSummary {
  const FinanceSummary({
    required this.confirmedTotal,
    required this.knownUnpaidBills,
    required this.hasAccounts,
    this.lastConfirmedAt,
    this.oldestConfirmedAt,
  });

  final int confirmedTotal;
  final int knownUnpaidBills;
  final bool hasAccounts;
  final DateTime? lastConfirmedAt;
  final DateTime? oldestConfirmedAt;

  /// Estimasi, bukan saldo bank aktual. Boleh negatif (kekurangan).
  int get estimatedFreeMoney => confirmedTotal - knownUnpaidBills;
}

enum IncomeTargetStatus { notNeeded, needsWorkdays, ready }

class IncomeTarget {
  const IncomeTarget({
    required this.status,
    required this.fundingGap,
    this.dailyTarget,
    this.workdays,
  });

  final IncomeTargetStatus status;
  final int fundingGap;
  final int? dailyTarget;
  final int? workdays;
}

class FinanceCalculator {
  const FinanceCalculator._();

  /// `confirmed_total` = jumlah saldo terkonfirmasi akun aktif;
  /// `known_unpaid_bills` = jumlah tagihan berstatus unpaid (tagihan paid/cancelled
  /// TIDAK dihitung, sehingga tidak terhitung dua kali).
  static FinanceSummary summarize(List<Account> accounts, List<Bill> bills) {
    final active = accounts.where((a) => a.isActive).toList();
    var total = 0;
    DateTime? latest;
    DateTime? oldest;
    for (final a in active) {
      total += a.confirmedBalance;
      if (latest == null || a.balanceConfirmedAt.isAfter(latest)) {
        latest = a.balanceConfirmedAt;
      }
      if (oldest == null || a.balanceConfirmedAt.isBefore(oldest)) {
        oldest = a.balanceConfirmedAt;
      }
    }
    var unpaid = 0;
    for (final b in bills) {
      if (b.status == BillStatus.unpaid) unpaid += b.amount;
    }
    return FinanceSummary(
      confirmedTotal: total,
      knownUnpaidBills: unpaid,
      hasAccounts: active.isNotEmpty,
      lastConfirmedAt: latest,
      oldestConfirmedAt: oldest,
    );
  }

  /// `funding_gap = max(0, obligations - available_funds - confirmed_income)`
  /// `daily_target = ceil(funding_gap / workdays)`; tidak pernah membagi nol.
  static IncomeTarget dailyIncomeTarget({
    required int upcomingObligations,
    required int availableFunds,
    int confirmedIncome = 0,
    int? workdays,
  }) {
    final gap = math.max(
      0,
      upcomingObligations - availableFunds - confirmedIncome,
    );
    if (gap == 0) {
      return IncomeTarget(
        status: IncomeTargetStatus.notNeeded,
        fundingGap: 0,
        dailyTarget: 0,
        workdays: workdays,
      );
    }
    if (workdays == null || workdays <= 0) {
      return IncomeTarget(
        status: IncomeTargetStatus.needsWorkdays,
        fundingGap: gap,
        workdays: workdays,
      );
    }
    return IncomeTarget(
      status: IncomeTargetStatus.ready,
      fundingGap: gap,
      dailyTarget: (gap + workdays - 1) ~/ workdays,
      workdays: workdays,
    );
  }
}

// ---------------------------------------------------------------------------
// Rutinitas (TDD 6.6)
// ---------------------------------------------------------------------------

class RoutineScheduler {
  const RoutineScheduler._();

  /// Jadwal pertama rutinitas baru: hari ini (atau hari terpilih terdekat untuk
  /// mingguan), pada jam pilihan bila ada. Tanpa jam = jatuh tempo sepanjang hari.
  static DateTime? firstDue(Routine routine, DateTime now) {
    DateTime atTime(DateTime day) =>
        DateTimeUtils.withTime(day, routine.preferredTime) ?? day;
    switch (routine.recurrenceType) {
      case RecurrenceType.daily:
        return atTime(DateTime(now.year, now.month, now.day));
      case RecurrenceType.interval:
        final n = routine.intervalDays;
        if (n == null || n < 1) return null;
        return atTime(DateTime(now.year, now.month, now.day));
      case RecurrenceType.weekly:
        final days = routine.weekdays.where((d) => d >= 1 && d <= 7).toSet();
        if (days.isEmpty) return null;
        for (var i = 0; i < 7; i++) {
          final c = DateTime(now.year, now.month, now.day + i);
          if (days.contains(c.weekday)) return atTime(c);
        }
        return null;
    }
  }

  /// Waktu notifikasi untuk jadwal [Routine.nextDueAt]: jam pilihan, atau
  /// 08:00 bila rutinitas tidak punya jam.
  static DateTime? reminderTime(Routine routine) {
    final due = routine.nextDueAt;
    if (due == null) return null;
    final t = routine.preferredTime;
    if (t != null && t.isNotEmpty) return due;
    return DateTime(due.year, due.month, due.day, 8);
  }

  /// Jadwal berikutnya setelah rutinitas diselesaikan pada [completedAt].
  /// Memakai aritmetika kalender sehingga aman untuk pergantian bulan/tahun.
  static DateTime? nextDue(Routine routine, DateTime completedAt) {
    final done = completedAt.toLocal();
    DateTime atTime(DateTime day) =>
        DateTimeUtils.withTime(day, routine.preferredTime) ??
        DateTime(day.year, day.month, day.day);

    switch (routine.recurrenceType) {
      case RecurrenceType.daily:
        return atTime(DateTime(done.year, done.month, done.day + 1));
      case RecurrenceType.interval:
        final n = routine.intervalDays;
        if (n == null || n < 1) return null;
        return atTime(DateTime(done.year, done.month, done.day + n));
      case RecurrenceType.weekly:
        final days = routine.weekdays.where((d) => d >= 1 && d <= 7).toSet();
        if (days.isEmpty) return null;
        for (var i = 1; i <= 7; i++) {
          final candidate = DateTime(done.year, done.month, done.day + i);
          if (days.contains(candidate.weekday)) return atTime(candidate);
        }
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Urutan tugas (TDD 6.2) — aturan tampilan, bukan skor.
// ---------------------------------------------------------------------------

class TaskOrdering {
  const TaskOrdering._();

  /// 0 overdue, 1 urgent/high bertenggat, 2 bertenggat lain, 3 tanpa tenggat.
  static int rank(Task t, DateTime now) {
    if (t.dueAt == null) return 3;
    if (t.dueAt!.isBefore(now)) return 0;
    if (t.priority.isHigh) return 1;
    return 2;
  }

  static int compare(Task a, Task b, DateTime now) {
    final ra = rank(a, now);
    final rb = rank(b, now);
    if (ra != rb) return ra.compareTo(rb);
    if (a.dueAt != null && b.dueAt != null) {
      final c = a.dueAt!.compareTo(b.dueAt!);
      if (c != 0) return c;
    }
    final p = b.priority.index.compareTo(a.priority.index);
    if (p != 0) return p;
    return a.createdAt.compareTo(b.createdAt);
  }

  static List<Task> sorted(Iterable<Task> tasks, DateTime now) =>
      tasks.toList()..sort((a, b) => compare(a, b, now));

  /// Hingga [limit] tugas aktif BERTENGGAT: overdue dulu, lalu `due_at` terdekat.
  static List<Task> nearestDeadlines(Iterable<Task> tasks, {int limit = 3}) {
    final withDue = tasks.where((t) => t.isActive && t.dueAt != null).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return withDue.take(limit).toList();
  }
}

// ---------------------------------------------------------------------------
// Financial Reality Check
// ---------------------------------------------------------------------------

/// Memisahkan FAKTA (saldo terkonfirmasi) dari ESTIMASI (uang bebas, target).
///
/// Aturan anti hitung-ganda:
///  - Setiap tagihan unpaid masuk TEPAT SATU kelompok: terlambat, jatuh tempo
///    dalam horizon, atau lebih jauh. Jumlah ketiganya selalu = total unpaid.
///  - Tagihan paid/cancelled tidak pernah dihitung.
///  - Transaksi opsional TIDAK ikut dihitung (saldo terkonfirmasi sudah
///    mencerminkannya sampai pengguna memperbaruinya), sehingga pengeluaran
///    yang sama tidak terpotong dua kali.
class RealityCheck {
  const RealityCheck({
    required this.hasAccounts,
    required this.confirmedTotal,
    required this.unpaidTotal,
    required this.overdueTotal,
    required this.overdueCount,
    required this.dueInHorizonTotal,
    required this.laterTotal,
    required this.horizonDays,
    required this.confirmedIncome,
    required this.fundingGap,
    required this.target,
    this.lastConfirmedAt,
    this.oldestConfirmedAt,
    this.nextBill,
    this.balanceStale = false,
  });

  final bool hasAccounts;

  /// FAKTA: jumlah saldo terakhir yang dikonfirmasi pengguna.
  final int confirmedTotal;
  final DateTime? lastConfirmedAt;
  final DateTime? oldestConfirmedAt;

  /// Saldo terlama belum diperbarui >= 7 hari.
  final bool balanceStale;

  final int unpaidTotal;
  final int overdueTotal;
  final int overdueCount;
  final int dueInHorizonTotal;
  final int laterTotal;
  final int horizonDays;
  final Bill? nextBill;

  final int confirmedIncome;

  /// ESTIMASI: saldo terkonfirmasi - semua tagihan belum dibayar. Boleh negatif.
  int get estimatedFree => confirmedTotal - unpaidTotal;

  /// Kewajiban yang dihitung untuk kesenjangan: terlambat + jatuh tempo dalam horizon.
  int get obligationsInHorizon => overdueTotal + dueInHorizonTotal;

  /// ESTIMASI: kekurangan dana untuk kewajiban dalam horizon.
  final int fundingGap;

  /// ESTIMASI: target pemasukan harian.
  final IncomeTarget target;

  static RealityCheck compute({
    required List<Account> accounts,
    required List<Bill> bills,
    required DateTime now,
    int horizonDays = 30,
    int confirmedIncome = 0,
    int? workdays,
  }) {
    final active = accounts.where((a) => a.isActive).toList();
    var confirmed = 0;
    DateTime? latest;
    DateTime? oldest;
    for (final a in active) {
      confirmed += a.confirmedBalance;
      if (latest == null || a.balanceConfirmedAt.isAfter(latest)) {
        latest = a.balanceConfirmedAt;
      }
      if (oldest == null || a.balanceConfirmedAt.isBefore(oldest)) {
        oldest = a.balanceConfirmedAt;
      }
    }

    final horizonEnd = DateTime(
      now.year,
      now.month,
      now.day + horizonDays,
      23,
      59,
      59,
    );
    var unpaid = 0, overdue = 0, soon = 0, later = 0, overdueCount = 0;
    Bill? next;
    for (final b in bills) {
      if (b.status != BillStatus.unpaid) continue;
      unpaid += b.amount;
      if (next == null || b.dueAt.isBefore(next.dueAt)) next = b;
      if (b.dueAt.isBefore(now)) {
        overdue += b.amount;
        overdueCount++;
      } else if (!b.dueAt.isAfter(horizonEnd)) {
        soon += b.amount;
      } else {
        later += b.amount;
      }
    }

    final obligations = overdue + soon;
    final target = FinanceCalculator.dailyIncomeTarget(
      upcomingObligations: obligations,
      availableFunds: confirmed,
      confirmedIncome: confirmedIncome,
      workdays: workdays,
    );
    return RealityCheck(
      hasAccounts: active.isNotEmpty,
      confirmedTotal: confirmed,
      lastConfirmedAt: latest,
      oldestConfirmedAt: oldest,
      balanceStale:
          oldest != null &&
          DateTime(now.year, now.month, now.day)
                  .difference(DateTime(oldest.year, oldest.month, oldest.day))
                  .inDays >=
              7,
      unpaidTotal: unpaid,
      overdueTotal: overdue,
      overdueCount: overdueCount,
      dueInHorizonTotal: soon,
      laterTotal: later,
      horizonDays: horizonDays,
      nextBill: next,
      confirmedIncome: confirmedIncome,
      fundingGap: target.fundingGap,
      target: target,
    );
  }
}

// ---------------------------------------------------------------------------
// Tindakan berikutnya (aturan deterministik, selalu disertai alasan)
// ---------------------------------------------------------------------------

enum NextActionKind {
  overdueTask,
  reviewTask,
  task,
  bill,
  reviewItems,
  routine,
  resume,
}

class NextAction {
  const NextAction({
    required this.kind,
    required this.title,
    required this.reason,
    this.targetId,
  });

  final NextActionKind kind;
  final String title;

  /// Alasan singkat yang ditampilkan ke pengguna (PRD 8.2).
  final String reason;
  final String? targetId;
}

class NextActionAdvisor {
  const NextActionAdvisor._();

  static String _days(int n) => n == 1 ? '1 day' : '$n days';

  /// Tidak mengarang estimasi durasi dan tidak mengklaim ada waktu luang.
  /// Mengembalikan null bila memang tidak ada yang mendesak.
  static NextAction? choose({
    required DateTime now,
    required List<Task> activeTasks,
    required List<Bill> unpaidBills,
    required int dueRoutineCount,
    required int needsReviewItemCount,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    int dayDiff(DateTime d) => DateTimeUtils.calendarDaysBetween(today, d);

    // Murni menurut tenggat: urutan berprioritas (TaskOrdering) bisa menaruh tugas
    // bertenggat jauh di depan tugas yang jatuh tempo besok.
    final withDue = activeTasks.where((t) => t.dueAt != null).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    // 1. Tugas lewat deadline (yang paling lama terlewat lebih dulu).
    final overdue = withDue.where((t) => t.dueAt!.isBefore(now)).toList();
    if (overdue.isNotEmpty) {
      final t = overdue.first;
      final late = -dayDiff(t.dueAt!);
      return NextAction(
        kind: NextActionKind.overdueTask,
        title: t.title,
        reason: late <= 0
            ? 'Past due today. Finish it or reschedule.'
            : 'Past due by ${_days(late)}. Finish it or reschedule.',
        targetId: t.id,
      );
    }

    // 2. Tagihan terlambat.
    final bills = [...unpaidBills]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    if (bills.isNotEmpty && bills.first.dueAt.isBefore(now)) {
      final b = bills.first;
      final late = -dayDiff(b.dueAt);
      return NextAction(
        kind: NextActionKind.bill,
        title: 'Pay ${b.title}',
        reason: late <= 0
            ? 'Bill is due today.'
            : 'Bill is ${_days(late)} overdue.',
        targetId: b.id,
      );
    }

    // 3. Deadline hari ini / besok (informasi belum lengkap -> periksa dulu).
    for (final t in withDue) {
      final d = dayDiff(t.dueAt!);
      if (d > 1) break;
      final when = d == 0 ? 'today' : 'tomorrow';
      if (t.status == TaskStatus.needsReview) {
        return NextAction(
          kind: NextActionKind.reviewTask,
          title: 'Review first: ${t.title}',
          reason: 'Due $when, but the details are incomplete.',
          targetId: t.id,
        );
      }
      return NextAction(
        kind: NextActionKind.task,
        title: t.title,
        reason: 'Deadline $when.',
        targetId: t.id,
      );
    }

    // 4. Tagihan dalam 3 hari.
    if (bills.isNotEmpty) {
      final d = dayDiff(bills.first.dueAt);
      if (d <= 3) {
        return NextAction(
          kind: NextActionKind.bill,
          title: 'Prepare ${bills.first.title}',
          reason: d == 0 ? 'Bill is due today.' : 'Bill is due in ${_days(d)}.',
          targetId: bills.first.id,
        );
      }
    }

    // 5. Informasi baru yang belum ditinjau.
    if (needsReviewItemCount > 0) {
      return NextAction(
        kind: NextActionKind.reviewItems,
        title: 'Review $needsReviewItemCount new items',
        reason: 'Not reviewed yet; turn them into tasks or archive them.',
      );
    }

    // 6. Rutinitas jatuh tempo.
    if (dueRoutineCount > 0) {
      return NextAction(
        kind: NextActionKind.routine,
        title: dueRoutineCount == 1
            ? '1 routine is due'
            : '$dueRoutineCount routines are due',
        reason: 'Mark it done after you finish it.',
      );
    }

    // 7. Deadline terdekat berikutnya (minggu ini).
    if (withDue.isNotEmpty) {
      final t = withDue.first;
      final d = dayDiff(t.dueAt!);
      if (d <= 7) {
        return NextAction(
          kind: NextActionKind.task,
          title: t.title,
          reason: 'Next deadline: ${_days(d)} away.',
          targetId: t.id,
        );
      }
    }

    // 8. Lanjutkan yang sedang dikerjakan.
    final doing = activeTasks.where((t) => t.status == TaskStatus.inProgress);
    if (doing.isNotEmpty) {
      final t = doing.first;
      return NextAction(
        kind: NextActionKind.resume,
        title: t.title,
        reason: 'In progress.',
        targetId: t.id,
      );
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Penjadwalan ulang saat pemulihan
// ---------------------------------------------------------------------------

class Reschedule {
  const Reschedule._();

  /// Menggeser [original] ke [days] hari dari HARI INI dengan jam yang sama
  /// (23:59 bila tenggat lama tidak punya jam yang berarti).
  static DateTime shift(DateTime? original, DateTime now, int days) {
    final h = original?.hour ?? 23;
    final m = original?.minute ?? 59;
    return DateTime(now.year, now.month, now.day + days, h, m);
  }
}

// ---------------------------------------------------------------------------
// Dashboard / Today View (TDD 13)
// ---------------------------------------------------------------------------

class DashboardData {
  const DashboardData({
    required this.todayEvents,
    required this.nearestDeadlines,
    required this.nearestBills,
    required this.overdueTasks,
    required this.reality,
    required this.needsReviewItemCount,
    required this.needsReviewTaskCount,
    required this.nextRoutines,
    required this.dueRoutineCount,
    this.nextAction,
    this.backupReminder = false,
  });

  final List<Event> todayEvents;

  /// Maksimal tiga tugas aktif bertenggat terdekat (termasuk yang terlambat).
  final List<Task> nearestDeadlines;
  final List<Bill> nearestBills;

  /// Semua tugas aktif yang sudah lewat deadline, paling lama terlewat dulu.
  final List<Task> overdueTasks;
  final RealityCheck reality;
  final int needsReviewItemCount;
  final int needsReviewTaskCount;
  final List<Routine> nextRoutines;
  final int dueRoutineCount;
  final NextAction? nextAction;

  /// True bila ada data tetapi belum pernah/terlalu lama tidak dibackup.
  final bool backupReminder;

  int get overdueTaskCount => overdueTasks.length;
  int get overdueBillCount => reality.overdueCount;
  int get needsReviewTotal => needsReviewItemCount + needsReviewTaskCount;
}
