import 'package:get/get.dart';

import '../../../core/state/data_revision.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';
import '../controllers/routines_controller.dart';

class RoutinesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoutinesController>(
      () => RoutinesController(
        Get.find<RoutineRepository>(),
        Get.find<CompleteRoutine>(),
        Get.find<DeleteRoutine>(),
        Get.find<DataRevision>(),
      ),
    );
  }
}
