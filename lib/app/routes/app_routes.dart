/// Nama rute dan tipe argumennya (via `Get.arguments`).
abstract class Routes {
  static const shell = '/';

  /// Argumen: `SavedItemFormArgs?`
  static const savedItemForm = '/inbox/form';

  /// Argumen: `String` (id)
  static const savedItemDetail = '/inbox/detail';

  static const search = '/search';

  /// Argumen: `TaskFormArgs?`
  static const taskForm = '/tasks/form';

  /// Argumen: `String` (id)
  static const taskDetail = '/tasks/detail';

  /// Argumen: `Event?`
  static const eventForm = '/agenda/form';

  static const routines = '/routines';

  /// Argumen: `Routine?`
  static const routineForm = '/routines/form';

  static const settings = '/settings';

  /// Pemulihan tugas yang lewat deadline.
  static const overdue = '/tasks/overdue';
}
