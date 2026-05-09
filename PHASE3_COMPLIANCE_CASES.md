# KANI Phase 3 Compliance Cases

Status: implementation slice ready
Release candidate: `phase3-compliance-cases-rc1`
Date: 2026-05-09
Scope: sandbox-only manual-review cases and held-payment flow

This slice keeps the non-value-moving boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

It does not create cloud resources, enable production compliance operations, connect to external screening vendors, or authorize real-value movement.

## Implemented Flow

The sandbox compliance profile still allows straight-through processing for ordinary approved test transfers. When a payment receives `ComplianceDecision::Review`, the API now:

1. Records the `COMPLIANCE_DECISION` audit event.
2. Creates a payment with `TransactionStatus::HELD`.
3. Opens a `ComplianceCase` with status `OPENED`.
4. Keeps the transaction out of the validator pending queue.

Approved cases release the held transaction to `PENDING`, where the existing validator path can finalize it. Rejected cases mark the payment `REJECTED` and keep it out of settlement.

## Data Model

Shared types now include:

- `ComplianceCase`
- `ComplianceCaseOpen`
- `ComplianceCaseStatus`
- `TransactionStatus::HELD`

Migration `migrations/0009_phase3_compliance_cases.sql` adds `compliance_cases` and expands transaction status validation to include `HELD`.

## API

Sandbox admin credentials are required:

```text
GET  /v1/compliance/cases
GET  /v1/compliance/cases/{id}
POST /v1/compliance/cases/{id}/approve
POST /v1/compliance/cases/{id}/reject
```

The approval and rejection endpoints accept optional `reviewer` and `reason` fields. Case state changes are audit logged with payment, policy version, rule, reviewer, and resolution metadata.

## Acceptance Evidence

The slice is accepted when these checks pass:

```powershell
cargo fmt --check
cargo clippy --workspace -- -D warnings
cargo test --workspace -j 1
powershell -ExecutionPolicy Bypass -File .\scripts\phase3-validate.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-validate.ps1
```

## Deferred

- Vendor sanctions, PEP, and adverse-media integrations.
- Evidence file attachments.
- Case assignment queues and reviewer RBAC beyond sandbox admin.
- SLA timers and escalations.
- Production AML/KYC operating procedures.
