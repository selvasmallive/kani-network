# KANI Private Settlement Network

Phase 1 local MVP for a private, permissioned settlement network. This implementation is sandbox-only and intentionally does not move real value.

## What Is Implemented

- Rust workspace with separate crates for API, node, ledger, consensus, crypto profiles, compliance, ISO 20022 placeholders, and shared types.
- In-memory Phase 1 ledger with accounts, balances, issuance tracking, journal entries, audit events, and immutable block append.
- Transaction support for sandbox mint, burn, and transfer.
- Proof-of-Authority block production with 3 validators, round-robin leadership, and 2-of-3 finality metadata.
- Axum API for payments, payment lookup, balances, latest block, health, and sandbox minting.
- PostgreSQL migration schema for the production ledger tables.

## Sandbox Boundaries

The default runtime is:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

No real money, external customers, fiat deposits, redemption, custody, trading, or production payment services are supported by this phase.

## Run Locally

This environment needs Rust installed and available on `PATH`.

```bash
cargo fmt
cargo test
cargo run -p kani-api
```

The API binds to `127.0.0.1:8080` by default. Set `KANI_API_ADDR=0.0.0.0:8080` for container or LAN testing.

The default ledger mode is in-memory. To run with PostgreSQL persistence:

```bash
docker compose up -d postgres
set KANI_LEDGER_MODE=postgres
set DATABASE_URL=postgres://kani:kani@localhost:5432/kani
cargo run -p kani-api
```

In PowerShell:

```powershell
docker compose up -d postgres
$env:KANI_LEDGER_MODE = "postgres"
$env:DATABASE_URL = "postgres://kani:kani@localhost:5432/kani"
cargo run -p kani-api
```

PostgreSQL mode runs the migrations in `migrations/`, seeds sandbox accounts when the database is empty, and reloads finalized blocks, balances, transactions, journal entries, and audit events on restart.

## Run The Full Local Stack

The compose stack starts Postgres, `kani-api`, and three local validator processes:

```text
validator-a
validator-b
validator-c
```

In Postgres mode, `kani-api` queues pending transactions and the validator services finalize blocks in round-robin PoA order.
Validators also take a Postgres advisory lock during block production, so duplicate local validator processes do not finalize the same pending transactions concurrently.
Each validator writes heartbeat and last-finalized-block state to Postgres; read it from `GET /v1/validators`.
Payment requests may include `client_reference_id` or `idempotency_key`; retries with the same value return the original payment record.
If the same key is reused with different payment details, the API returns `409 Conflict`.
Sandbox write APIs and account-scoped read APIs require institution headers:

```text
x-kani-institution-id: CORP_A | CORP_B | KANI_TREASURY
x-kani-api-key: sandbox-corp-a-token | sandbox-corp-b-token | sandbox-treasury-token
```

These local keys are simulation-only. Override them with `KANI_SANDBOX_CORP_A_API_KEY`, `KANI_SANDBOX_CORP_B_API_KEY`, and `KANI_SANDBOX_TREASURY_API_KEY` when needed.
Balance reads require the institution that owns the account. Payment lookup is visible to the sending or receiving institution.
Network-wide read APIs such as blocks, audit events, validators, and pending transactions require sandbox admin headers:

```text
x-kani-institution-id: KANI_ADMIN
x-kani-api-key: sandbox-admin-token
```

Override the local admin key with `KANI_SANDBOX_ADMIN_API_KEY` when needed.
API authorization decisions are written to the audit log as `API_AUTHORIZATION_DECISION` events with structured metadata such as `decision`, `action`, `resource`, `institution_id`, `role`, and `status_code`. API keys are never written to audit events.
Admin audit reads support filters: `event_type`, `decision`, `institution_id`, `created_from`, and `created_to`. Time filters must be RFC3339 timestamps. Audit reads are paginated with `limit` and `offset`; the default limit is `100` and the maximum limit is `500`.

```powershell
cd C:\dev\kani
docker compose up -d --build
```

Run the repeatable smoke test:

```powershell
.\scripts\smoke-test.ps1
```

The smoke test mints a fresh test asset, waits for validator finality, transfers from `CORP_A` to `CORP_B`, verifies balances, checks authorization failures, verifies authorization audit events, filters, and pagination, restarts `kani-api`, verifies persisted balances, and reads block/audit/validator listings.

## Example Flow

Mint sandbox test value to Corp A:

```bash
curl -X POST http://127.0.0.1:8080/v1/sandbox/mint \
  -H "content-type: application/json" \
  -H "x-kani-institution-id: KANI_TREASURY" \
  -H "x-kani-api-key: sandbox-treasury-token" \
  -d '{"treasury":"TREASURY_SANDBOX","to":"CORP_A","asset":"KCAD_TEST","amount":1000000}'
```

Transfer from Corp A to Corp B:

```bash
curl -X POST http://127.0.0.1:8080/v1/payments \
  -H "content-type: application/json" \
  -H "x-kani-institution-id: CORP_A" \
  -H "x-kani-api-key: sandbox-corp-a-token" \
  -d '{"from":"CORP_A","to":"CORP_B","asset":"KCAD_TEST","amount":100000,"client_reference_id":"demo-transfer-001"}'
```

Check balances:

```bash
curl http://127.0.0.1:8080/v1/accounts/CORP_A/balances/KCAD_TEST \
  -H "x-kani-institution-id: CORP_A" \
  -H "x-kani-api-key: sandbox-corp-a-token"

curl http://127.0.0.1:8080/v1/accounts/CORP_B/balances/KCAD_TEST \
  -H "x-kani-institution-id: CORP_B" \
  -H "x-kani-api-key: sandbox-corp-b-token"

curl http://127.0.0.1:8080/v1/blocks \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl "http://127.0.0.1:8080/v1/audit-events?limit=100&offset=0" \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl "http://127.0.0.1:8080/v1/audit-events?event_type=API_AUTHORIZATION_DECISION&decision=DENIED&institution_id=CORP_B&created_from=1970-01-01T00%3A00%3A00Z&limit=100&offset=0" \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl http://127.0.0.1:8080/v1/validators \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl http://127.0.0.1:8080/v1/transactions/pending \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"
```

## Phase 1 Acceptance Path

1. Mint `1_000_000 KCAD_TEST` from `TREASURY_SANDBOX` to `CORP_A`.
2. Transfer `100_000 KCAD_TEST` from `CORP_A` to `CORP_B`.
3. Confirm `CORP_A = 900_000`, `CORP_B = 100_000`.
4. Confirm the latest block is finalized with 2 validator votes.
5. Confirm audit events are written for finalized transactions and blocks.
