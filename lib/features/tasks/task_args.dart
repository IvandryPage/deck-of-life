import '../../domain/entities/entities.dart';

class TaskFormArgs {
  const TaskFormArgs({
    this.existing,
    this.savedItemIds = const [],
    this.title,
    this.description,
    this.courseName,
    this.groupName,
  });

  /// Null = tugas baru.
  final Task? existing;

  /// Item tersimpan yang langsung dihubungkan saat tugas baru dibuat.
  final List<String> savedItemIds;
  final String? title;
  final String? description;
  final String? courseName;
  final String? groupName;
}
