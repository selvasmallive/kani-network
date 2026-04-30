CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  account_type TEXT NOT NULL CHECK (account_type IN ('TREASURY', 'INSTITUTION', 'SETTLEMENT', 'FEE')),
  institution_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS balances (
  account_id TEXT NOT NULL REFERENCES accounts(id),
  asset TEXT NOT NULL,
  amount NUMERIC(38, 0) NOT NULL DEFAULT 0 CHECK (amount >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, asset)
);

CREATE TABLE IF NOT EXISTS blocks (
  height BIGINT PRIMARY KEY,
  prev_hash TEXT NOT NULL,
  hash TEXT NOT NULL UNIQUE,
  validator TEXT NOT NULL,
  signature BYTEA NOT NULL,
  finalized_by JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY,
  block_height BIGINT REFERENCES blocks(height),
  from_account TEXT NOT NULL REFERENCES accounts(id),
  to_account TEXT NOT NULL REFERENCES accounts(id),
  asset TEXT NOT NULL,
  amount NUMERIC(38, 0) NOT NULL CHECK (amount > 0),
  nonce BIGINT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('MINT', 'BURN', 'TRANSFER')),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'FINALIZED', 'REJECTED')),
  signatures JSONB NOT NULL DEFAULT '[]'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (from_account, nonce)
);

CREATE TABLE IF NOT EXISTS journal_entries (
  id UUID PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES transactions(id),
  account_id TEXT NOT NULL REFERENCES accounts(id),
  asset TEXT NOT NULL,
  amount NUMERIC(38, 0) NOT NULL CHECK (amount > 0),
  direction TEXT NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
  block_height BIGINT NOT NULL REFERENCES blocks(height),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_events (
  id UUID PRIMARY KEY,
  event_type TEXT NOT NULL,
  message TEXT NOT NULL,
  block_height BIGINT REFERENCES blocks(height),
  transaction_id UUID REFERENCES transactions(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactions_block_height ON transactions(block_height);
CREATE INDEX IF NOT EXISTS idx_journal_entries_account_asset ON journal_entries(account_id, asset);
CREATE INDEX IF NOT EXISTS idx_audit_events_created_at ON audit_events(created_at);
