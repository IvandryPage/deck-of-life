import 'package:get/get.dart';

import '../../features/agenda/pages/event_form_page.dart';
import '../../features/inbox/pages/saved_item_detail_page.dart';
import '../../features/inbox/pages/saved_item_form_page.dart';
import '../../features/routines/bindings/routines_binding.dart';
import '../../features/routines/pages/routine_form_page.dart';
import '../../features/routines/pages/routines_page.dart';
import '../../features/search/bindings/search_binding.dart';
import '../../features/search/pages/search_page.dart';
import '../../features/settings/bindings/settings_binding.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/shell/bindings/shell_binding.dart';
import '../../features/shell/pages/shell_page.dart';
import '../../features/tasks/pages/overdue_page.dart';
import '../../features/tasks/pages/task_detail_page.dart';
import '../../features/tasks/pages/task_form_page.dart';
import 'app_routes.dart';

class AppPages {
  const AppPages._();

  static final List<GetPage<dynamic>> pages = [
    GetPage(
      name: Routes.shell,
      page: () => const ShellPage(),
      binding: ShellBinding(),
    ),
    GetPage(
      name: Routes.savedItemForm,
      page: () => const SavedItemFormPage(),
    ),
    GetPage(
      name: Routes.savedItemDetail,
      page: () => const SavedItemDetailPage(),
    ),
    GetPage(
      name: Routes.search,
      page: () => const SearchPage(),
      binding: SearchBinding(),
    ),
    GetPage(name: Routes.taskForm, page: () => const TaskFormPage()),
    GetPage(name: Routes.overdue, page: () => const OverduePage()),
    GetPage(name: Routes.taskDetail, page: () => const TaskDetailPage()),
    GetPage(name: Routes.eventForm, page: () => const EventFormPage()),
    GetPage(
      name: Routes.routines,
      page: () => const RoutinesPage(),
      binding: RoutinesBinding(),
    ),
    GetPage(name: Routes.routineForm, page: () => const RoutineFormPage()),
    GetPage(
      name: Routes.settings,
      page: () => const SettingsPage(),
      binding: SettingsBinding(),
    ),
  ];
}
