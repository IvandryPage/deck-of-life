import 'package:get/get.dart';

import '../../../core/sharing/share_intake_service.dart';
import '../../../core/state/data_revision.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/reminder_coordinator.dart';
import '../../../domain/usecases/usecases.dart';
import '../../calendar/controllers/calendar_controller.dart';
import '../../finance/controllers/finance_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../inbox/controllers/inbox_controller.dart';
import '../../tasks/controllers/tasks_controller.dart';
import '../controllers/shell_controller.dart';

/// Controller kelima tab hidup selama shell hidup (IndexedStack membangun semuanya).
class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ShellController>(
      ShellController(Get.find<ShareIntakeService>(), Get.find<ReminderCoordinator>()),
    );
    Get.put<HomeController>(
      HomeController(
        Get.find<GetDashboard>(),
        Get.find<DataRevision>(),
        Get.find<SaveSavedItem>(),
        Get.find<SavedItemRepository>(),
        Get.find<ChangeTaskStatus>(),
        Get.find<RescheduleTask>(),
      ),
    );
    Get.put<InboxController>(
      InboxController(Get.find<SearchSavedItems>(), Get.find<DataRevision>()),
    );
    Get.put<TasksController>(
      TasksController(
        Get.find<TaskRepository>(),
        Get.find<ChangeTaskStatus>(),
        Get.find<SaveTask>(),
        Get.find<DataRevision>(),
      ),
    );
    Get.put<CalendarController>(
      CalendarController(
        Get.find<EventRepository>(),
        Get.find<TaskRepository>(),
        Get.find<FinanceRepository>(),
        Get.find<DeleteEvent>(),
        Get.find<DataRevision>(),
      ),
    );
    Get.put<FinanceController>(
      FinanceController(
        finance: Get.find<FinanceRepository>(),
        settings: Get.find<SettingsRepository>(),
        saveBill: Get.find<SaveBill>(),
        markBillPaid: Get.find<MarkBillPaid>(),
        deleteBill: Get.find<DeleteBill>(),
        revision: Get.find<DataRevision>(),
      ),
    );
  }
}
