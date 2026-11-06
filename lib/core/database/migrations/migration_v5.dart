/// Checklist tugas dan metadata lampiran lokal untuk catatan.
const List<String> migrationV5 = [
  "ALTER TABLE tasks ADD COLUMN checklist_json TEXT NOT NULL DEFAULT '[]'",
  '''
CREATE TABLE saved_item_attachments (
  id TEXT PRIMARY KEY,
  saved_item_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  content_base64 TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes > 0),
  created_at TEXT NOT NULL,
  FOREIGN KEY (saved_item_id) REFERENCES saved_items(id) ON DELETE CASCADE
)''',
  'CREATE INDEX idx_saved_item_attachments_item ON saved_item_attachments(saved_item_id, created_at)',
];
