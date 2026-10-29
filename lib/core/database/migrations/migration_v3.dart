/// Finance ledger columns. Existing transactions remain informational and do not
/// affect balances; only entries written after this migration are applied.
const List<String> migrationV3 = [
  'ALTER TABLE transactions ADD COLUMN transfer_id TEXT',
  'ALTER TABLE transactions ADD COLUMN bill_id TEXT REFERENCES bills(id) ON DELETE SET NULL',
  'ALTER TABLE transactions ADD COLUMN affects_balance INTEGER NOT NULL DEFAULT 0 CHECK (affects_balance IN (0,1))',
  'CREATE INDEX idx_transactions_bill ON transactions(bill_id)',
  'CREATE INDEX idx_transactions_transfer ON transactions(transfer_id)',
];
