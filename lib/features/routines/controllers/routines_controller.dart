import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_mutations.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

class RoutinesController extends GetxController with DataMutations {
  RoutinesController(
    this._routines,
    this._complete,
    this._delete,
    this._revision,
  );

  final RoutineRepository _routines;
  final CompleteRoutine _complete;
  final DeleteRoutine _delete;
  final DataRevision _revision;

  final RxList<Routine> routines = <Routine>[].obs;
  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
    ever<int>(_revision.revision, (_) => load());
  }

  Future<void> load() async {
    errorMessage.value = null;
    try {
      final list = await _routines.list();
      // Aktif dulu, lalu yang paling dekat jatuh tempo.
      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        final x = a.nextDueAt, y = b.nextDueAt;
        if (x == null && y == null) return a.title.compareTo(b.title);
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
      routines.assignAll(list);
    } catch (e, st) {
      AppLog.error('routines.load', e, st);
      errorMessage.value = messageOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> complete(Routine r) async {
    String? message;
    final ok = await mutate(() async {
      final res = await _complete(r.id);
      message = res.reminder?.message;
    }, success: '"${r.title}" selesai');
    if (ok && message != null) AppToast.show(message!, isError: true);
    return ok;
  }

  Future<bool> remove(Routine r) =>
      mutate(() => _delete(r.id), success: 'Rutinitas dihapus');

  Future<List<RoutineLog>> logsOf(Routine r) => _routines.logs(r.id);
}
