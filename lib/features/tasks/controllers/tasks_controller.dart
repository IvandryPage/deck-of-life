import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_mutations.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/logic.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

enum TaskFilter { active, done, all }

/// Kelompok pada tampilan tugas aktif.
enum TaskBucket { overdue, today, upcoming, noDeadline }

class TasksController extends GetxController with DataMutations {
  TasksController(
    this._tasks,
    this._changeStatus,
    this._saveTask,
    this._revision,
  );

  final TaskRepository _tasks;
  final ChangeTaskStatus _changeStatus;
  final SaveTask _saveTask;
  final DataRevision _revision;

  final RxList<Task> tasks = <Task>[].obs;
  final Rx<TaskFilter> filter = TaskFilter.active.obs;
  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
    ever<int>(_revision.revision, (_) => load());
    ever<TaskFilter>(filter, (_) => load());
  }

  Future<void> load() async {
    errorMessage.value = null;
    try {
      final now = DateTime.now();
      switch (filter.value) {
        case TaskFilter.active:
          final list = await _tasks.list(statuses: {
            TaskStatus.needsReview,
            TaskStatus.todo,
            TaskStatus.inProgress,
          });
          tasks.assignAll(TaskOrdering.sorted(list, now));
        case TaskFilter.done:
          final list = await _tasks.list(
            statuses: {TaskStatus.done, TaskStatus.cancelled},
          );
          list.sort((a, b) => (b.completedAt ?? b.updatedAt)
              .compareTo(a.completedAt ?? a.updatedAt));
          tasks.assignAll(list);
        case TaskFilter.all:
          final list = await _tasks.list();
          tasks.assignAll(TaskOrdering.sorted(list, now));
      }
    } catch (e, st) {
      AppLog.error('tasks.load', e, st);
      errorMessage.value = messageOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Mengelompokkan tugas aktif; urutan di dalam kelompok mengikuti TaskOrdering.
  static Map<TaskBucket, List<Task>> bucketize(List<Task> list, DateTime now) {
    final today = DateTimeUtils.startOfDay(now);
    final out = <TaskBucket, List<Task>>{
      for (final b in TaskBucket.values) b: <Task>[],
    };
    for (final t in list) {
      final d = t.dueAt;
      if (d == null) {
        out[TaskBucket.noDeadline]!.add(t);
      } else if (d.isBefore(now)) {
        out[TaskBucket.overdue]!.add(t);
      } else if (DateTimeUtils.isSameDay(d, today)) {
        out[TaskBucket.today]!.add(t);
      } else {
        out[TaskBucket.upcoming]!.add(t);
      }
    }
    return out;
  }

  /// Satu ketukan: selesai (dengan Urungkan), atau buka kembali bila sudah selesai.
  Future<void> toggleDone(Task task) async {
    final reopening = task.status == TaskStatus.done;
    Task? spawned;
    final ok = await mutate(() async {
      spawned = await _changeStatus(
        task.id,
        reopening ? TaskStatus.todo : TaskStatus.done,
      );
    });
    if (!ok) return;
    if (reopening) {
      AppToast.show('Tugas dibuka kembali');
      return;
    }
    AppToast.undoable('Tugas selesai', () async {
      // Urungkan juga menghapus kemunculan berikutnya yang baru dibuat
      // (tugas berulang) agar tidak tersisa duplikat.
      await mutate(() => _changeStatus.undoDone(task.id, spawnedId: spawned?.id));
    });
  }

  /// Quick add: hanya judul. Mengembalikan true bila tersimpan.
  Future<bool> quickAdd(String raw) async {
    final title = raw.trim();
    if (title.isEmpty) return false;
    final now = DateTime.now();
    return mutate(
      () async {
        await _saveTask(
          Task(
            id: const Uuid().v4(),
            title: title,
            status: TaskStatus.todo,
            priority: TaskPriority.normal,
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
        );
      },
      success: 'Tugas ditambahkan',
    );
  }
}
