# KANI Phase 3 Audit And Reporting Hardening

Status: hardening slice ready
Release candidate: `phase3-audit-reporting-hardening-rc1`
Date: 2026-05-09
Scope: immutable audit contract, reconciliation boundaries, retention matrix, and export controls

This slice keeps the sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

It does not create paid resources, export regulated data, enable real money movement, or authorize production reporting.

## Hardening Goals

The Phase 2 sandbox already exposes audit events and reporting endpoints. This slice makes the enterprise reporting contract explicit before any production or real-value capability is considered.

Required reporting surfaces:

- settlement summary by asset, institution, block height, and settlement day
- compliance decision report by policy version, rule, decision, and institution
- validator finality report by validator, block height, and vote coverage
- audit event export with immutable event identifiers and hash-chain readiness
- reconciliation report comparing issued supply, account balances, journal entries, and finalized blocks

## Immutable Audit Contract

Audit events must preserve:

- `event_id`
- `event_type`
- `created_at`
- `actor_institution_id`
- `resource_type`
- `resource_id`
- `decision`
- `block_height`
- `transaction_id`
- `metadata_hash`
- `previous_event_hash`
- `event_hash`

The sandbox implementation currently stores audit events without hash-chain enforcement. Production hash-chain signing remains deferred until the signing-service and key-management boundary is implemented.

## Reconciliation Boundary

Daily reconciliation must be reproducible from canonical ledger state:

- finalized blocks
- finalized transactions
- journal entries
- account balances
- issued supply
- compliance decisions
- validator finality records

Any discrepancy must create an audit event and a manual operations case before production use.

## Retention Matrix

Minimum target retention categories:

- ledger state: long-lived financial record
- audit events: long-lived compliance record
- compliance cases: long-lived compliance record
- API access decisions: security and compliance record
- validator finality records: operational integrity record
- Cloud Run logs: operational support record
- Cloud SQL backups: recovery record

Actual retention periods require legal, privacy, and compliance approval through the regulatory readiness gate.

## Export Controls

Report exports must:

- require admin authorization
- include export purpose and requester identity
- redact secrets and API keys
- record export audit events
- include deterministic filters and time windows
- avoid external delivery by default
- remain sandbox-only until privacy/legal review approves production handling

## Deferred

- production immutable hash-chain enforcement
- signed audit envelope implementation
- external report delivery
- SIEM export
- data warehouse replication
- legal-approved retention periods
- production reconciliation operations
- real-value reporting

Current validator behavior remains Phase 1 PoA.

## Acceptance Evidence

The slice is accepted when these checks pass:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase3-audit-reporting-hardening.ps1
cargo fmt --check
cargo clippy --workspace -- -D warnings
cargo test --workspace -j 1
powershell -ExecutionPolicy Bypass -File .\scripts\phase3-validate.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-validate.ps1
```
