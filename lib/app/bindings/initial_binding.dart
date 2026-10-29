import 'package:get/get.dart';

import '../../core/backup/backup_service.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/sharing/share_intake_service.dart';
import '../../core/state/data_revision.dart';
import '../../data/repositories/event_repository_impl.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../data/repositories/routine_repository_impl.dart';
import '../../data/repositories/saved_item_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/ports.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/reminder_coordinator.dart';
import '../../domain/usecases/usecases.dart';

/// Dependency yang hidup sepanjang aplikasi (TDD bagian 9): database, layanan
/// notifikasi, repository, dan use case dibuat SEKALI di sini.
class InitialBinding extends Bindings {
  InitialBinding({required this.db, required this.notifications});

  final AppDatabase db;
  final LocalNotificationService notifications;

  @override
  void dependencies() {
    Get.put<AppDatabase>(db, permanent: true);
    Get.put<NotificationScheduler>(notifications, permanent: true);
    Get.put<DataRevision>(DataRevision(), permanent: true);

    final savedItems = SavedItemRepositoryImpl(db);
    final tasks = TaskRepositoryImpl(db);
    final events = EventRepositoryImpl(db);
    final reminders = ReminderRepositoryImpl(db);
    final finance = FinanceRepositoryImpl(db);
    final routines = RoutineRepositoryImpl(db);
    final settings = SettingsRepositoryImpl(db);

    Get.put<SavedItemRepository>(savedItems, permanent: true);
    Get.put<TaskRepository>(tasks, permanent: true);
    Get.put<EventRepository>(events, permanent: true);
    Get.put<ReminderRepository>(reminders, permanent: true);
    Get.put<FinanceRepository>(finance, permanent: true);
    Get.put<RoutineRepository>(routines, permanent: true);
    Get.put<SettingsRepository>(settings, permanent: true);

    final coordinator = ReminderCoordinator(
      reminders: reminders,
      scheduler: notifications,
      lookup: ReminderTargetLookupImpl(db),
      settings: settings,
    );
    Get.put<ReminderCoordinator>(coordinator, permanent: true);

    Get.put<SearchSavedItems>(SearchSavedItems(savedItems), permanent: true);
    Get.put<SaveSavedItem>(
      SaveSavedItem(savedItems, coordinator),
      permanent: true,
    );
    Get.put<ArchiveSavedItem>(
      ArchiveSavedItem(savedItems, coordinator),
      permanent: true,
    );
    Get.put<DeleteSavedItem>(
      DeleteSavedItem(savedItems, coordinator),
      permanent: true,
    );
    Get.put<SaveTask>(SaveTask(tasks, coordinator), permanent: true);
    Get.put<ChangeTaskStatus>(
      ChangeTaskStatus(tasks, reminders, coordinator),
      permanent: true,
    );
    Get.put<RescheduleTask>(
      RescheduleTask(tasks, reminders, coordinator),
      permanent: true,
    );
    Get.put<DeleteTask>(DeleteTask(tasks, coordinator), permanent: true);
    Get.put<SaveEvent>(SaveEvent(events, coordinator), permanent: true);
    Get.put<DeleteEvent>(DeleteEvent(events, coordinator), permanent: true);
    Get.put<SaveBill>(SaveBill(finance, coordinator), permanent: true);
    Get.put<MarkBillPaid>(
      MarkBillPaid(finance, reminders, coordinator),
      permanent: true,
    );
    Get.put<DeleteBill>(DeleteBill(finance, coordinator), permanent: true);
    Get.put<SaveRoutine>(SaveRoutine(routines, coordinator), permanent: true);
    Get.put<CompleteRoutine>(
      CompleteRoutine(routines, reminders, coordinator),
      permanent: true,
    );
    Get.put<SkipRoutine>(
      SkipRoutine(routines, reminders, coordinator),
      permanent: true,
    );
    Get.put<DeleteRoutine>(
      DeleteRoutine(routines, coordinator),
      permanent: true,
    );
    Get.put<SearchAll>(
      SearchAll(savedItems, tasks, events, finance),
      permanent: true,
    );
    Get.put<GetDashboard>(
      GetDashboard(
        events: events,
        tasks: tasks,
        savedItems: savedItems,
        finance: finance,
        routines: routines,
        settings: settings,
      ),
      permanent: true,
    );

    // Setelah restore, jadwal notifikasi OS harus mengikuti data yang baru.
    Get.put<BackupService>(
      BackupService(
        db,
        onRestored: () async {
          await routines.migrateToRecurringTasks();
          await coordinator.reconcileAll();
        },
      ),
      permanent: true,
    );
    Get.put<ShareIntakeService>(ShareIntakeService(), permanent: true);
  }
}
