import 'package:get/get.dart';

import '../../../core/state/data_revision.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';
import '../controllers/agenda_controller.dart';

class AgendaBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AgendaController>(
      () => AgendaController(
        Get.find<EventRepository>(),
        Get.find<DeleteEvent>(),
        Get.find<DataRevision>(),
      ),
    );
  }
}
