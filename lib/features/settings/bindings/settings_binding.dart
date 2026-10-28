import 'package:get/get.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/state/data_revision.dart';
import '../../../domain/repositories/ports.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/reminder_coordinator.dart';
import '../controllers/settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsController>(
      () => SettingsController(
        Get.find<SettingsRepository>(),
        Get.find<NotificationScheduler>(),
        Get.find<ReminderCoordinator>(),
        Get.find<BackupService>(),
        Get.find<DataRevision>(),
      ),
    );
  }
}
