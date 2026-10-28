/// Skema baseline v1 (TDD bagian 5). Jangan diubah setelah dirilis: perubahan
/// berikutnya ditulis sebagai migration baru (v2, v3, ...) di `migrations.dart`.
const List<String> migrationV1 = [
  '''
CREATE TABLE saved_items (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content_text TEXT NOT NULL DEFAULT '',
  item_type TEXT NOT NULL CHECK (
    item_type IN ('note','message','link','file_reference','image_reference','other')
  ),
  source_app TEXT,
  source_label TEXT,
  source_url TEXT,
  source_location TEXT,
  course_name TEXT,
  group_name TEXT,
  context_note TEXT,
  review_status TEXT NOT NULL DEFAULT 'needs_review' CHECK (
    review_status IN ('needs_review','reviewed','archived')
  ),
  is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT
)''',
  '''
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'todo' CHECK (
    status IN ('needs_review','todo','in_progress','done','cancelled')
  ),
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (
    priority IN ('low','normal','high','urgent')
  ),
  due_at TEXT,
  estimated_minutes INTEGER,
  course_name TEXT,
  group_name TEXT,
  task_kind TEXT NOT NULL DEFAULT 'individual' CHECK (
    task_kind IN ('individual','group','shared_responsibility','unknown')
  ),
  instruction_source TEXT,
  instruction_location TEXT,
  initiated_by TEXT,
  next_action TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT,
  archived_at TEXT
)''',
  '''
CREATE TABLE task_saved_items (
  task_id TEXT NOT NULL,
  saved_item_id TEXT NOT NULL,
  relation_note TEXT,
  PRIMARY KEY (task_id, saved_item_id),
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (saved_item_id) REFERENCES saved_items(id) ON DELETE CASCADE
)''',
  '''
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  starts_at TEXT NOT NULL,
  ends_at TEXT,
  location TEXT,
  event_type TEXT NOT NULL DEFAULT 'other' CHECK (
    event_type IN ('lecture','work','meeting','appointment','personal','other')
  ),
  linked_task_id TEXT,
  linked_saved_item_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (linked_task_id) REFERENCES tasks(id) ON DELETE SET NULL,
  FOREIGN KEY (linked_saved_item_id) REFERENCES saved_items(id) ON DELETE SET NULL
)''',
  '''
CREATE TABLE reminders (
  id TEXT PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (
    target_type IN ('task','event','bill','routine','saved_item')
  ),
  target_id TEXT NOT NULL,
  remind_at TEXT NOT NULL,
  repeat_rule TEXT,
  notification_id INTEGER NOT NULL UNIQUE,
  is_enabled INTEGER NOT NULL DEFAULT 1 CHECK (is_enabled IN (0,1)),
  last_scheduled_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  '''
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  account_type TEXT NOT NULL DEFAULT 'cash' CHECK (
    account_type IN ('cash','bank','e_wallet','other')
  ),
  confirmed_balance INTEGER NOT NULL DEFAULT 0 CHECK (confirmed_balance >= 0),
  balance_confirmed_at TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  '''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  direction TEXT NOT NULL CHECK (direction IN ('income','expense')),
  category TEXT NOT NULL,
  note TEXT,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
)''',
  '''
CREATE TABLE balance_adjustments (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  previous_balance INTEGER NOT NULL,
  corrected_balance INTEGER NOT NULL CHECK (corrected_balance >= 0),
  reason TEXT,
  adjusted_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
)''',
  '''
CREATE TABLE bills (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  due_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unpaid' CHECK (
    status IN ('unpaid','paid','cancelled')
  ),
  paid_at TEXT,
  account_id TEXT,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL
)''',
  '''
CREATE TABLE routines (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  recurrence_type TEXT NOT NULL CHECK (
    recurrence_type IN ('daily','weekly','interval')
  ),
  interval_days INTEGER,
  weekdays_json TEXT,
  preferred_time TEXT,
  next_due_at TEXT,
  last_completed_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  '''
CREATE TABLE routine_logs (
  id TEXT PRIMARY KEY,
  routine_id TEXT NOT NULL,
  completed_at TEXT NOT NULL,
  note TEXT,
  FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
)''',
  '''
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  'CREATE INDEX idx_saved_items_updated ON saved_items(updated_at DESC)',
  'CREATE INDEX idx_saved_items_review ON saved_items(review_status, created_at DESC)',
  'CREATE INDEX idx_tasks_due ON tasks(due_at, status)',
  'CREATE INDEX idx_tasks_status ON tasks(status, priority)',
  'CREATE INDEX idx_events_start ON events(starts_at)',
  'CREATE INDEX idx_reminders_time ON reminders(is_enabled, remind_at)',
  'CREATE INDEX idx_bills_due ON bills(status, due_at)',
  'CREATE INDEX idx_transactions_date ON transactions(occurred_at DESC)',
  'CREATE INDEX idx_routine_logs_date ON routine_logs(routine_id, completed_at DESC)',
];
