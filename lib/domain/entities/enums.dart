/// Domain enums. `value` is persisted in SQLite and must match schema checks.

enum SavedItemType {
  note('note', 'Note'),
  message('message', 'Message'),
  link('link', 'Link'),
  fileReference('file_reference', 'File reference'),
  imageReference('image_reference', 'Image reference'),
  other('other', 'Other');

  const SavedItemType(this.value, this.label);
  final String value;
  final String label;

  static SavedItemType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => other);
}

enum ReviewStatus {
  needsReview('needs_review', 'Needs review'),
  reviewed('reviewed', 'Reviewed'),
  archived('archived', 'Archived');

  const ReviewStatus(this.value, this.label);
  final String value;
  final String label;

  static ReviewStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => needsReview);
}

enum TaskStatus {
  needsReview('needs_review', 'Needs review'),
  todo('todo', 'To do'),
  inProgress('in_progress', 'In progress'),
  done('done', 'Done'),
  cancelled('cancelled', 'Canceled');

  const TaskStatus(this.value, this.label);
  final String value;
  final String label;

  bool get isActive => this != done && this != cancelled;

  static TaskStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => todo);
}

enum TaskPriority {
  low('low', 'Low'),
  normal('normal', 'Normal'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const TaskPriority(this.value, this.label);
  final String value;
  final String label;

  bool get isHigh => this == high || this == urgent;

  static TaskPriority fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => normal);
}

enum TaskKind {
  individual('individual', 'Individual'),
  group('group', 'Group'),
  sharedResponsibility('shared_responsibility', 'Shared responsibility'),
  unknown('unknown', 'Unclear');

  const TaskKind(this.value, this.label);
  final String value;
  final String label;

  static TaskKind fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => individual);
}

enum EventType {
  lecture('lecture', 'Class'),
  work('work', 'Work'),
  meeting('meeting', 'Meeting'),
  appointment('appointment', 'Appointment'),
  personal('personal', 'Personal'),
  other('other', 'Other');

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
  cash('cash', 'Cash'),
  bank('bank', 'Bank account'),
  eWallet('e_wallet', 'E-wallet'),
  other('other', 'Other');

  const AccountType(this.value, this.label);
  final String value;
  final String label;

  static AccountType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => cash);
}

enum TransactionDirection {
  income('income', 'Income'),
  expense('expense', 'Expense');

  const TransactionDirection(this.value, this.label);
  final String value;
  final String label;

  static TransactionDirection fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => expense);
}

enum BillStatus {
  unpaid('unpaid', 'Unpaid'),
  paid('paid', 'Paid'),
  cancelled('cancelled', 'Canceled');

  const BillStatus(this.value, this.label);
  final String value;
  final String label;

  static BillStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => unpaid);
}

enum RecurrenceType {
  daily('daily', 'Every day'),
  weekly('weekly', 'Selected weekdays'),
  interval('interval', 'Every N days');

  const RecurrenceType(this.value, this.label);
  final String value;
  final String label;

  static RecurrenceType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => interval);
}
