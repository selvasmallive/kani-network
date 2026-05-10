ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS transactions_status_check;

ALTER TABLE transactions
  ADD CONSTRAINT transactions_status_check
  CHECK (status IN ('PENDING', 'HELD', 'FINALIZED', 'REJECTED'));

CREATE TABLE IF NOT EXISTS compliance_cases (
  id UUID PRIMARY KEY,
  payment_id UUID NOT NULL UNIQUE REFERENCES transactions(id),
  status TEXT NOT NULL CHECK (status IN (
    'OPENED',
    'ASSIGNED',
    'EVIDENCE_REQUESTED',
    'ESCALATED',
    'APPROVED',
    'REJECTED',
    'CLOSED'
  )),
  policy_version TEXT NOT NULL,
  rule_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  opened_by_institution TEXT NOT NULL,
  assigned_to TEXT,
  reviewer TEXT,
  resolution_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_compliance_cases_status ON compliance_cases(status);
CREATE INDEX IF NOT EXISTS idx_compliance_cases_payment ON compliance_cases(payment_id);
