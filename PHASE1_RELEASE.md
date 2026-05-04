# KANI Phase 1 Release Candidate

Release candidate: `phase1-rc1`
Date: 2026-05-04
Scope: Local sandbox MVP only

## Status

Phase 1 is release-candidate complete for internal simulation.

This release does not move real value and is not production payment infrastructure.

## Included

- Rust workspace with API, node, ledger, consensus, crypto profile, compliance placeholder, ISO 20022 placeholder, and shared types crates.
- Sandbox-only runtime guardrails for `ENV=SANDBOX`, `REAL_VALUE=FALSE`, and `REDEEMABLE=FALSE`.
- PostgreSQL-backed ledger persistence with migrations and sandbox seed accounts.
- Accounts, balances, issued supply, journal entries, finalized blocks, payments, validator status, and audit events.
- Sandbox mint, transfer, and burn transaction model.
- Proof-of-Authority block production with 3 validators, round-robin leadership, and 2-of-3 finality metadata.
- Block integrity checks for leader identity, finality voters, block hash, sandbox validator signature, and transaction batch validity.
- Pending transaction rejection with persisted `REJECTED` status, failure reason, and `TRANSACTION_REJECTED` audit events.
- Authenticated sandbox institution/admin API using local simulation headers.
- OpenAPI 3.1 contract served at `/openapi.json`.
- Docker Compose local stack for Postgres, `kani-api`, and 3 validators.
- Local demo, smoke, and CI helper scripts.

## Acceptance Evidence

Run these from `C:\dev\kani`:

```powershell
cargo fmt --check
cargo test --workspace
cargo clippy --workspace -- -D warnings
.\scripts\demo-phase1.ps1
.\scripts\smoke-test.ps1
```

The latest verification pass completed with:

- workspace tests passing
- clippy passing with `-D warnings`
- rebuilt Docker smoke test passing
- `kani-api` healthy
- Postgres healthy
- `validator-a`, `validator-b`, and `validator-c` running

The demo and smoke scripts verify:

- sandbox runtime flags are enforced
- mint of `1_000_000` test units finalizes
- transfer of `100_000` test units finalizes
- `CORP_A` balance is `900_000`
- `CORP_B` balance is `100_000`
- issued supply is `1_000_000`
- latest block has 2 finality votes
- all 3 validators report heartbeat state
- pending transactions return to `0`
- finalized transaction, authorization, and rejection audit events are readable
- overdrawn payments are rejected without corrupting balances
- API state survives a `kani-api` restart in PostgreSQL mode

## Sandbox Boundary

This release is restricted to internal simulation:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

Not supported:

- real money movement
- fiat deposit or redemption
- customer access
- custody for others
- production payment services
- trading or exchange activity

## Known Limits

- Authentication uses local sandbox headers, not production mTLS/OIDC.
- Validator signatures use deterministic sandbox signatures, not production HSM/KMS keys.
- Consensus is Phase 1 PoA, not BFT.
- ISO 20022 and compliance crates remain placeholders for later phases.
- Deployment is local Docker Compose, not GCP Cloud Run/GKE.

## Next Phase

Phase 2 should focus on:

- GCP deployment path
- production-grade key management integration
- mTLS/API gateway boundary
- ISO 20022 pacs.008 parsing and validation
- compliance workflow expansion
- BFT consensus evaluation
