import '../../domain/entities/entities.dart';

class SavedItemFormArgs {
  const SavedItemFormArgs({
    this.existing,
    this.text,
    this.subject,
    this.fromShare = false,
  });

  /// Null = item baru.
  final SavedItem? existing;

  /// Isi awal (dari Share Sheet atau tempel).
  final String? text;
  final String? subject;
  final bool fromShare;
}
