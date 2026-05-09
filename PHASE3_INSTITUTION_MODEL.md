# KANI Phase 3 Institution Model

Status: implementation slice ready
Release candidate: `phase3-institution-model-rc1`
Date: 2026-05-09
Scope: sandbox-only institution onboarding model, storage, and admin API

This slice starts Phase 3 implementation without changing the sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

It does not create Google Cloud resources, enable GKE, enable production ingress, or authorize real-value movement.

## Implemented Model

Shared types now include:

- `Institution`: legal name, code, jurisdiction, approval/suspension state, risk tier, allowed assets, roles, and timestamps.
- `InstitutionCredential`: sandbox API key, future mTLS/OIDC metadata, credential status, fingerprint, subject, issuer, expiry, and revocation reason.
- `InstitutionLimit`: per-institution, per-asset transaction and daily limits.
- `OnboardingCase`: requested, due-diligence, approved, rejected, suspended, and offboarded lifecycle states.

The default sandbox seed now creates approved institution records for:

```text
KANI_TREASURY
CORP_A
CORP_B
KANI
```

## Storage

Migration `migrations/0002_phase3_institutions.sql` adds:

- `institutions`
- `institution_credentials`
- `institution_limits`

The in-memory ledger and PostgreSQL store both load and persist the new institution model. Existing sandbox databases are upgraded by seeding missing institution records without overwriting account balances.

## Admin API

Sandbox admin credentials are required for all endpoints:

```text
GET  /v1/admin/institutions
POST /v1/admin/institutions
GET  /v1/admin/institutions/{id}
POST /v1/admin/institutions/{id}/credentials
POST /v1/admin/institutions/{id}/suspend
POST /v1/admin/institutions/{id}/limits
```

Institution profile responses include the institution record, credential metadata, and configured limits.

## Enforcement

Account-scoped API authorization now checks both the sandbox credential headers and the institution status. Suspended or otherwise non-approved institutions cannot operate accounts or submit payments.

Credential creation, institution suspension, and limit updates are audit logged as admin events. API keys and credential secrets are not written to audit metadata.

## Acceptance Evidence

The slice is accepted when these checks pass:

```powershell
cargo fmt --check
cargo test -p kani-types
cargo test -p kani-ledger
cargo test -p kani-node
cargo test -p kani-api --lib
powershell -ExecutionPolicy Bypass -File .\scripts\phase3-validate.ps1
```

If Windows keeps a stale Rust test executable locked, rerun tests with a fresh `CARGO_TARGET_DIR`.

## Deferred

- Real institution onboarding and customer access.
- Production mTLS enforcement.
- Credential secret storage beyond sandbox metadata.
- Compliance case workflow.
- BFT validator operations.
- GKE validator deployment.
