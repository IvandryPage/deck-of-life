/// Enum domain. `value` = string yang disimpan di SQLite (sesuai CHECK di skema).

enum SavedItemType {
  note('note', 'Catatan'),
  message('message', 'Pesan'),
  link('link', 'Tautan'),
  fileReference('file_reference', 'Referensi file'),
  imageReference('image_reference', 'Referensi gambar'),
  other('other', 'Lainnya');

  const SavedItemType(this.value, this.label);
  final String value;
  final String label;

  static SavedItemType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => other);
}

enum ReviewStatus {
  needsReview('needs_review', 'Perlu diperiksa'),
  reviewed('reviewed', 'Sudah diperiksa'),
  archived('archived', 'Diarsipkan');

  const ReviewStatus(this.value, this.label);
  final String value;
  final String label;

  static ReviewStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => needsReview);
}

enum TaskStatus {
  needsReview('needs_review', 'Perlu diperiksa'),
  todo('todo', 'Akan dikerjakan'),
  inProgress('in_progress', 'Dikerjakan'),
  done('done', 'Selesai'),
  cancelled('cancelled', 'Dibatalkan');

  const TaskStatus(this.value, this.label);
  final String value;
  final String label;

  bool get isActive => this != done && this != cancelled;

  static TaskStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => todo);
}

enum TaskPriority {
  low('low', 'Rendah'),
  normal('normal', 'Normal'),
  high('high', 'Tinggi'),
  urgent('urgent', 'Mendesak');

  const TaskPriority(this.value, this.label);
  final String value;
  final String label;

  bool get isHigh => this == high || this == urgent;

  static TaskPriority fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => normal);
}

enum TaskKind {
  individual('individual', 'Individu'),
  group('group', 'Kelompok'),
  sharedResponsibility('shared_responsibility', 'Tanggung jawab bersama'),
  unknown('unknown', 'Belum jelas');

  const TaskKind(this.value, this.label);
  final String value;
  final String label;

  static TaskKind fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => individual);
}

enum EventType {
  lecture('lecture', 'Kuliah'),
  work('work', 'Kerja'),
  meeting('meeting', 'Rapat'),
  appointment('appointment', 'Janji'),
  personal('personal', 'Pribadi'),
  other('other', 'Lainnya');

  const EventType(this.value, this.label);
  final String value;
  final String label;

  static EventType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => other);
}

enum ReminderTargetType {
  task('task'),
  event('event'),
  bill('bill'),
  routine('routine'),
  savedItem('saved_item');

  const ReminderTargetType(this.value);
  final String value;

  static ReminderTargetType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => task);
}

enum AccountType {
  cash('cash', 'Uang tunai'),
  bank('bank', 'Rekening bank'),
  eWallet('e_wallet', 'E-wallet'),
  other('other', 'Lainnya');

  const AccountType(this.value, this.label);
  final String value;
  final String label;

  static AccountType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => cash);
}

enum TransactionDirection {
  income('income', 'Pemasukan'),
  expense('expense', 'Pengeluaran');

  const TransactionDirection(this.value, this.label);
  final String value;
  final String label;

  static TransactionDirection fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => expense);
}

enum BillStatus {
  unpaid('unpaid', 'Belum dibayar'),
  paid('paid', 'Dibayar'),
  cancelled('cancelled', 'Dibatalkan');

  const BillStatus(this.value, this.label);
  final String value;
  final String label;

  static BillStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => unpaid);
}

enum RecurrenceType {
  daily('daily', 'Setiap hari'),
  weekly('weekly', 'Hari tertentu setiap minggu'),
  interval('interval', 'Setiap N hari');

  const RecurrenceType(this.value, this.label);
  final String value;
  final String label;

  static RecurrenceType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => interval);
}
