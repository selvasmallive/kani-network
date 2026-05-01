CREATE TABLE IF NOT EXISTS validator_status (
  validator_id TEXT PRIMARY KEY,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_finalized_height BIGINT REFERENCES blocks(height),
  last_finalized_hash TEXT,
  last_finalized_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_validator_status_last_seen_at
  ON validator_status(last_seen_at);
