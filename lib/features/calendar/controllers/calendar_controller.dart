import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_mutations.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

/// Satu tampilan: bulan + daftar hari terpilih. Agenda, deadline tugas, dan
/// tagihan jatuh tempo ditampilkan bersama agar distribusi waktu terlihat utuh.
class CalendarController extends GetxController with DataMutations {
  CalendarController(
    this._events,
    this._tasks,
    this._finance,
    this._deleteEvent,
    this._revision,
  );

  final EventRepository _events;
  final TaskRepository _tasks;
  final FinanceRepository _finance;
  final DeleteEvent _deleteEvent;
  final DataRevision _revision;

  final Rx<DateTime> month = _firstOfMonth(DateTime.now()).obs;
  final Rx<DateTime> selected = DateTimeUtils.startOfDay(DateTime.now()).obs;

  /// Arah transisi bulan (-1 mundur, 1 maju) untuk animasi geser.
  final RxInt direction = 1.obs;

  final RxMap<DateTime, List<Event>> eventsByDay = <DateTime, List<Event>>{}.obs;
  final RxMap<DateTime, List<Task>> tasksByDay = <DateTime, List<Task>>{}.obs;
  final RxMap<DateTime, List<Bill>> billsByDay = <DateTime, List<Bill>>{}.obs;

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);

  @override
  void onInit() {
    super.onInit();
    load();
    ever<int>(_revision.revision, (_) => load());
  }

  Future<void> load() async {
    errorMessage.value = null;
    try {
      final m = month.value;
      final start = DateTime(m.year, m.month, 1);
      final end = DateTime(m.year, m.month + 1, 1);

      final events = await _events.listBetween(start, end);
      final activeTasks = await _tasks.list(statuses: {
        TaskStatus.needsReview,
        TaskStatus.todo,
        TaskStatus.inProgress,
      });
      final bills = await _finance.bills(statuses: {BillStatus.unpaid});

      bool inRange(DateTime d) => !d.isBefore(start) && d.isBefore(end);
      final e = <DateTime, List<Event>>{};
      for (final x in events) {
        e.putIfAbsent(DateTimeUtils.startOfDay(x.startsAt), () => []).add(x);
      }
      final t = <DateTime, List<Task>>{};
      for (final x in activeTasks) {
        if (x.dueAt != null && inRange(x.dueAt!)) {
          t.putIfAbsent(DateTimeUtils.startOfDay(x.dueAt!), () => []).add(x);
        }
      }
      final b = <DateTime, List<Bill>>{};
      for (final x in bills) {
        if (inRange(x.dueAt)) {
          b.putIfAbsent(DateTimeUtils.startOfDay(x.dueAt), () => []).add(x);
        }
      }
      eventsByDay.assignAll(e);
      tasksByDay.assignAll(t);
      billsByDay.assignAll(b);
    } catch (e, st) {
      AppLog.error('calendar.load', e, st);
      errorMessage.value = messageOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  void select(DateTime day) {
    selected.value = DateTimeUtils.startOfDay(day);
    // Memilih hari di bulan sebelah (sel abu-abu) ikut memindahkan bulan.
    if (day.month != month.value.month || day.year != month.value.year) {
      direction.value = day.isAfter(month.value) ? 1 : -1;
      month.value = _firstOfMonth(day);
      isLoading.value = true;
      load();
    }
  }

  void shiftMonth(int delta) {
    direction.value = delta;
    month.value = DateTime(month.value.year, month.value.month + delta);
    final sel = selected.value;
    // Hari terpilih mengikuti bulan (tanggal sama atau hari terakhir bulan).
    final last = DateTime(month.value.year, month.value.month + 1, 0).day;
    selected.value = DateTime(
        month.value.year, month.value.month, sel.day > last ? last : sel.day);
    isLoading.value = true;
    load();
  }

  void goToday() {
    final today = DateTimeUtils.startOfDay(DateTime.now());
    direction.value = today.isAfter(month.value) ? 1 : -1;
    month.value = _firstOfMonth(today);
    selected.value = today;
    isLoading.value = true;
    load();
  }

  List<Event> eventsOn(DateTime d) =>
      (eventsByDay[DateTimeUtils.startOfDay(d)] ?? const <Event>[])
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  List<Task> tasksOn(DateTime d) =>
      tasksByDay[DateTimeUtils.startOfDay(d)] ?? const <Task>[];
  List<Bill> billsOn(DateTime d) =>
      billsByDay[DateTimeUtils.startOfDay(d)] ?? const <Bill>[];

  int markersOn(DateTime d) =>
      eventsOn(d).length + tasksOn(d).length + billsOn(d).length;

  Future<bool> remove(Event e) {
    final key = DateTimeUtils.startOfDay(e.startsAt);
    final list = (eventsByDay[key] ?? const <Event>[]).where((x) => x.id != e.id).toList();
    if (list.isEmpty) {
      eventsByDay.remove(key);
    } else {
      eventsByDay[key] = list;
    }
    return mutate(() => _deleteEvent(e.id), success: 'Event deleted');
  }
}
