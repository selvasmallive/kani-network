CREATE TABLE IF NOT EXISTS institutions (
  id TEXT PRIMARY KEY,
  legal_name TEXT NOT NULL,
  institution_code TEXT NOT NULL UNIQUE,
  jurisdiction TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('REQUESTED', 'DUE_DILIGENCE', 'APPROVED', 'REJECTED', 'SUSPENDED', 'OFFBOARDED')),
  risk_tier TEXT NOT NULL CHECK (risk_tier IN ('LOW', 'MEDIUM', 'HIGH', 'RESTRICTED')),
  allowed_assets JSONB NOT NULL DEFAULT '[]'::jsonb,
  roles JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_at TIMESTAMPTZ,
  suspended_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS institution_credentials (
  id UUID PRIMARY KEY,
  institution_id TEXT NOT NULL REFERENCES institutions(id),
  credential_type TEXT NOT NULL CHECK (credential_type IN ('SANDBOX_API_KEY', 'MTLS_CERTIFICATE', 'OIDC_CLIENT')),
  label TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  issuer TEXT,
  subject TEXT,
  expires_at TIMESTAMPTZ,
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'ACTIVE', 'RETIRED', 'REVOKED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ,
  revocation_reason TEXT,
  UNIQUE (institution_id, credential_type, fingerprint)
);

CREATE TABLE IF NOT EXISTS institution_limits (
  institution_id TEXT NOT NULL REFERENCES institutions(id),
  asset TEXT NOT NULL,
  daily_limit NUMERIC(38, 0) NOT NULL CHECK (daily_limit >= 0),
  per_transaction_limit NUMERIC(38, 0) NOT NULL CHECK (per_transaction_limit >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (institution_id, asset)
);

CREATE INDEX IF NOT EXISTS idx_institutions_status ON institutions(status);
CREATE INDEX IF NOT EXISTS idx_institution_credentials_institution ON institution_credentials(institution_id);
