/// Event recurrence rules; null keeps existing events as single occurrences.
const List<String> migrationV4 = [
  'ALTER TABLE events ADD COLUMN recurrence_rule TEXT',
  'ALTER TABLE routines ADD COLUMN migrated_task_id TEXT',
];
