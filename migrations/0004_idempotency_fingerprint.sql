ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS request_fingerprint TEXT;

CREATE INDEX IF NOT EXISTS idx_transactions_request_fingerprint
  ON transactions(request_fingerprint)
  WHERE request_fingerprint IS NOT NULL;
