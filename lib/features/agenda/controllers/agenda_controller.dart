import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_mutations.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

class AgendaController extends GetxController with DataMutations {
  AgendaController(this._events, this._deleteEvent, this._revision);

  final EventRepository _events;
  final DeleteEvent _deleteEvent;
  final DataRevision _revision;

  final RxList<Event> events = <Event>[].obs;
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
      events.assignAll(await _events.listUpcoming(limit: 200));
    } catch (e, st) {
      AppLog.error('agenda.load', e, st);
      errorMessage.value = messageOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Item dikeluarkan dari daftar lebih dulu: Dismissible mewajibkan widget-nya
  /// hilang dari pohon pada frame yang sama dengan `onDismissed`.
  Future<bool> remove(Event e) {
    events.removeWhere((x) => x.id == e.id);
    return mutate(() => _deleteEvent(e.id), success: 'Agenda dihapus');
  }
}
