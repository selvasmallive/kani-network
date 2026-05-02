ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS client_reference_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_client_reference_id
  ON transactions(client_reference_id)
  WHERE client_reference_id IS NOT NULL;
