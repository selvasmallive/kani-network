# KANI Private Settlement Network

Phase 1 local MVP for a private, permissioned settlement network. This implementation is sandbox-only and intentionally does not move real value.

## What Is Implemented

- Rust workspace with separate crates for API, node, ledger, consensus, crypto profiles, compliance, ISO 20022 placeholders, and shared types.
- In-memory Phase 1 ledger with accounts, balances, issuance tracking, journal entries, audit events, and immutable block append.
- Transaction support for sandbox mint, burn, and transfer.
- Proof-of-Authority block production with 3 validators, round-robin leadership, and 2-of-3 finality metadata.
- Axum API for payments, payment lookup, account inventory, balances, issued supply, latest block, health, and sandbox minting.
- OpenAPI 3.1 contract for the Phase 1 API, served from `/openapi.json`.
- PostgreSQL migration schema for the production ledger tables.

## Sandbox Boundaries

The default runtime is:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The Phase 1 binaries fail startup unless these flags are set exactly to the sandbox/non-real-value boundary.

No real money, external customers, fiat deposits, redemption, custody, trading, or production payment services are supported by this phase.

## Run Locally

This environment needs Rust installed and available on `PATH`.

```bash
cargo fmt
cargo test
ENV=SANDBOX REAL_VALUE=FALSE REDEEMABLE=FALSE cargo run -p kani-api
```

The API binds to `127.0.0.1:8080` by default. Set `KANI_API_ADDR=0.0.0.0:8080` for container or LAN testing.

The default ledger mode is in-memory. To run with PostgreSQL persistence:

```bash
docker compose up -d postgres
set KANI_LEDGER_MODE=postgres
set DATABASE_URL=postgres://kani:kani@localhost:5432/kani
set ENV=SANDBOX
set REAL_VALUE=FALSE
set REDEEMABLE=FALSE
cargo run -p kani-api
```

In PowerShell:

```powershell
docker compose up -d postgres
$env:KANI_LEDGER_MODE = "postgres"
$env:DATABASE_URL = "postgres://kani:kani@localhost:5432/kani"
$env:ENV = "SANDBOX"
$env:REAL_VALUE = "FALSE"
$env:REDEEMABLE = "FALSE"
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
Network-wide read APIs such as accounts, blocks, audit events, validators, and pending transactions require sandbox admin headers:

```text
x-kani-institution-id: KANI_ADMIN
x-kani-api-key: sandbox-admin-token
```

Override the local admin key with `KANI_SANDBOX_ADMIN_API_KEY` when needed.
API authorization decisions are written to the audit log as `API_AUTHORIZATION_DECISION` events with structured metadata such as `decision`, `action`, `resource`, `institution_id`, `role`, and `status_code`. API keys are never written to audit events.
Admin block reads are paginated with `limit` and `offset`; the default limit is `100` and the maximum limit is `500`. In PostgreSQL mode, block pagination runs in SQL and loads only transactions for the selected block page.
Admin audit reads support filters: `event_type`, `decision`, `institution_id`, `created_from`, and `created_to`. Time filters must be RFC3339 timestamps. Audit reads are paginated with `limit` and `offset`; the default limit is `100` and the maximum limit is `500`. In PostgreSQL mode, audit filtering and pagination run in SQL with supporting indexes.
Paginated admin reads return an envelope with page metadata. `next_offset` is populated only when another page is available.
Pending transaction reads use the same envelope.

```json
{
  "items": [],
  "limit": 100,
  "offset": 0,
  "count": 0,
  "next_offset": null
}
```

The checked-in API contract is `openapi/kani-api.v1.json` and the running API serves the same contract at:

```bash
curl http://localhost:8080/openapi.json
```

```powershell
cd C:\dev\kani
docker compose up -d --build
```

Run the repeatable smoke test:

```powershell
.\scripts\smoke-test.ps1
```

Run a concise Phase 1 demo:

```powershell
.\scripts\demo-phase1.ps1
```

The smoke script defaults to `http://localhost:8080`, which is the most reliable Docker Desktop host route on Windows. Pass `-BaseUrl http://127.0.0.1:8080` if you want to force IPv4.

The demo script starts the stack, mints a fresh sandbox asset, transfers from `CORP_A` to `CORP_B`, and prints a compact proof object with balances, issued supply, latest block finality, validator count, pending transaction count, and finalized audit event count.

The smoke test mints a fresh test asset, waits for validator finality, transfers from `CORP_A` to `CORP_B`, verifies balances, checks rejected overdraw handling, request validation, and authorization failures, verifies block pagination plus authorization/rejection audit events, filters, and pagination, restarts `kani-api`, verifies persisted balances, and reads block/audit/validator listings.

To run the faster Postgres-backed API integration test, keep the compose Postgres service running and provide a test database URL. The test creates and drops an isolated temporary database on the same Postgres server, so the configured user must be allowed to create databases.

```powershell
docker compose up -d postgres
$env:KANI_TEST_DATABASE_URL = "postgres://kani:kani@localhost:5432/kani"
cargo test -p kani-api --test postgres_api -- --nocapture
```

## CI Checks

GitHub Actions runs the same Phase 1 guardrails in `.github/workflows/ci.yml`:

```text
cargo fmt --check
cargo test --workspace
cargo test -p kani-api --test postgres_api -- --nocapture
cargo clippy --workspace -- -D warnings
docker build --file docker/Dockerfile.api --tag kani-api:ci .
docker compose config
.\scripts\smoke-test.ps1
```

The CI workflow starts a Postgres 16 service for the API integration test, separately validates the API/validator container image build, validates the Compose file, and runs the Phase 1 smoke test against the Docker stack.

Run the core checks locally from PowerShell:

```powershell
.\scripts\ci-local.ps1
```

If Windows reports a locked Rust test binary, rerun with a clean target directory:

```powershell
.\scripts\ci-local.ps1 -Clean
```

Include the full Docker smoke test with:

```powershell
.\scripts\ci-local.ps1 -RunSmoke
```

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

curl "http://127.0.0.1:8080/v1/blocks?limit=100&offset=0" \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl "http://127.0.0.1:8080/v1/audit-events?limit=100&offset=0" \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl "http://127.0.0.1:8080/v1/audit-events?event_type=API_AUTHORIZATION_DECISION&decision=DENIED&institution_id=CORP_B&created_from=1970-01-01T00%3A00%3A00Z&limit=100&offset=0" \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl http://127.0.0.1:8080/v1/accounts \
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

Run:

```powershell
.\scripts\demo-phase1.ps1
.\scripts\smoke-test.ps1
```

Phase 1 is accepted when the demo and smoke outputs prove:

1. `ENV=SANDBOX`, `REAL_VALUE=false`, and `REDEEMABLE=false`.
2. `1_000_000` units of a fresh test asset are minted from `TREASURY_SANDBOX` to `CORP_A`.
3. `100_000` units transfer from `CORP_A` to `CORP_B`.
4. `CORP_A` balance is `900_000`, `CORP_B` balance is `100_000`, and issued supply is `1_000_000`.
5. The latest block has at least 2 finality votes from the validator set.
6. All 3 validators are running and reporting heartbeat state.
7. Pending transactions return to `0` after finality/rejection handling.
8. Finalized transaction, block, authorization, and rejection audit events are readable through the admin API.
9. Invalid payment input, authorization failures, idempotency conflicts, and overdrawn payments are rejected or denied without corrupting balances.
10. API state survives a `kani-api` restart in PostgreSQL mode.
