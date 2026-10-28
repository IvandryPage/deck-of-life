/// Migrasi v2: aturan berulang untuk tugas dan tagihan.
///
/// Hanya `ALTER TABLE ... ADD COLUMN` (nullable, tanpa default) sehingga semua baris
/// lama tetap utuh dan bernilai NULL (= tidak berulang). Tidak ada tabel yang dibuat
/// ulang. Indeks tambahan mempercepat pencarian/pembersihan pengingat per target.
const List<String> migrationV2 = [
  'ALTER TABLE tasks ADD COLUMN recurrence_rule TEXT',
  'ALTER TABLE bills ADD COLUMN recurrence_rule TEXT',
  'CREATE INDEX idx_reminders_target ON reminders(target_type, target_id)',
];
