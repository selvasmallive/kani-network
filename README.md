# KANI Private Settlement Network

Phase 1 local MVP for a private, permissioned settlement network. Phase 2 cloud MVP scaffolding has started on a sandbox-only path. This implementation is sandbox-only and intentionally does not move real value.

## What Is Implemented

- Rust workspace with separate crates for API, node, ledger, consensus, crypto profiles, compliance, ISO 20022 ingestion, and shared types.
- In-memory Phase 1 ledger with accounts, balances, issuance tracking, journal entries, audit events, and immutable block append.
- Transaction support for sandbox mint, burn, and transfer.
- Proof-of-Authority block production with 3 validators, round-robin leadership, and 2-of-3 finality metadata.
- Phase 1 block integrity checks for leader identity, finality voters, block hash, and sandbox validator signature.
- Axum API for payments, payment lookup, account inventory, balances, issued supply, latest block, health, and sandbox minting.
- OpenAPI 3.1 contract for the Phase 1 API, served from `/openapi.json`.
- PostgreSQL migration schema for the production ledger tables.

## Phase 2 Cloud MVP

Phase 2 starts the Google Cloud sandbox deployment path while keeping real value disabled.

The starter cloud files are:

```text
PHASE2_CLOUD_MVP.md
cloudbuild.yaml
config/cloud-sandbox.yaml
infra/terraform/
k8s/
scripts/phase2-validate.ps1
```

The default Phase 2 topology is `phase2-lean-no-gke`: Cloud Run for `kani-api`, a Cloud Run Job for validator finality, Cloud Scheduler for periodic validator execution, Cloud SQL PostgreSQL for ledger state, Artifact Registry for images, Secret Manager for the generated database URL and sandbox API keys, Cloud SQL backups/PITR for sandbox recovery, basic sandbox compliance screening, ISO 20022 `pacs.008` sandbox ingestion, `pacs.002` status XML, `camt.053` account statements, admin audit/reporting endpoints, Cloud Monitoring alerts for operational signals, and a project-scoped Cloud Billing budget alert.

This skips GKE for now to minimize free-trial cost. The validator job runs `kani-node` in `sweep` mode across `validator-a`, `validator-b`, and `validator-c`, so the cloud MVP can still prove payment queueing, block finalization, balances, and audit persistence end to end. GKE manifests remain in `k8s/` for later validator operations testing.

Run the static Phase 2 scaffold check from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-validate.ps1
```

Cloud SQL recovery settings, restore commands, and monitoring alert policies are documented in `PHASE2_CLOUD_MVP.md`.
The current lean no-GKE release-candidate status, live sandbox resources, verification evidence, and intentional deferrals are summarized in `PHASE2_LEAN_WRAPUP.md`.
The first post-wrap-up observation gate is recorded in `PHASE2_OBSERVATION_REPORT.md`.

## Phase 3 Enterprise

Phase 3 is complete for the sandbox enterprise track. `PHASE3_ENTERPRISE_PLAN.md` defines the enterprise roadmap, `PHASE3_INSTITUTION_MODEL.md` records the institution checkpoint, `PHASE3_COMPLIANCE_CASES.md` records the compliance-case checkpoint, `PHASE3_CONSENSUS_INTERFACE.md` records the consensus-interface checkpoint, `PHASE3_BFT_PROTOTYPE.md` records the sandbox BFT prototype checkpoint, `PHASE3_PROD_EDGE_DESIGN.md` records the production edge design checkpoint, `PHASE3_KEY_MANAGEMENT_DESIGN.md` records the KMS/HSM key management design checkpoint, `PHASE3_REGULATORY_READINESS_GATE.md` records the regulatory readiness gate checkpoint, `PHASE3_AUDIT_REPORTING_HARDENING.md` records the audit/reporting hardening checkpoint, `PHASE3_OPERATIONAL_RUNBOOKS.md` records the operational runbooks checkpoint, `PHASE3_WRAPUP.md` records the wrap-up checkpoint, and `config/phase3-enterprise.yaml` keeps the structured Phase 3 boundary. This still does not create GKE, HSM, production ingress, or real-value capabilities.

The first Phase 3 implementation slice adds institution records, credential metadata, per-institution limits, admin institution endpoints, and account-operation blocking for suspended institutions:

```text
GET  /v1/admin/institutions
POST /v1/admin/institutions
GET  /v1/admin/institutions/{id}
POST /v1/admin/institutions/{id}/credentials
POST /v1/admin/institutions/{id}/suspend
POST /v1/admin/institutions/{id}/limits
```

The second Phase 3 implementation slice turns manual-review compliance decisions into held payments and admin-review cases:

```text
GET  /v1/compliance/cases
GET  /v1/compliance/cases/{id}
POST /v1/compliance/cases/{id}/approve
POST /v1/compliance/cases/{id}/reject
```

The third Phase 3 implementation slice adds a `ConsensusEngine` abstraction and config-built `phase1-poa` adapter while preserving the existing sandbox validator behavior. Shared consensus proposal, vote, quorum-certificate, validator-set, and finality-proof types are now available for the later BFT prototype.

The fourth Phase 3 implementation slice adds a sandbox-only `BftConsensus` prototype behind `ConsensusEngineConfig::sandbox_bft_prototype()`. It simulates proposal, prevote, precommit, quorum-certificate, and finality-proof objects in tests, while the live node and validator runtime still default to `phase1-poa`.

The fifth Phase 3 implementation slice adds design-only Terraform scaffolding for the future production edge. `infra/terraform/phase3_prod_edge_design.tf` documents the external HTTPS load balancer or API Gateway, Certificate Manager, institution mTLS, Cloud Armor WAF, private Cloud Run ingress, and admin OIDC boundary. `phase3_prod_edge_design_enabled` defaults to `false` and this slice declares no Google Cloud resources.

The sixth Phase 3 implementation slice adds design-only Terraform scaffolding and runbook guidance for future KMS/HSM key management. `infra/terraform/phase3_key_management_design.tf` documents purpose-scoped keys, signing-service boundaries, dual-control ceremonies, key states, rotation, revocation, and audit requirements. `phase3_key_management_design_enabled` defaults to `false` and this slice declares no Google Cloud resources.

The seventh Phase 3 implementation slice adds a blocking regulatory readiness gate. `config/phase3-regulatory-readiness.yaml` and `scripts/phase3-regulatory-readiness-gate.ps1` require legal, compliance, privacy, security, and executive approval evidence before any production or real-value capability can be considered. The checked-in result remains `blocked`.

The eighth Phase 3 implementation slice hardens audit and reporting boundaries. `config/phase3-audit-reporting.yaml` and `scripts/phase3-audit-reporting-hardening.ps1` define immutable audit fields, reconciliation source tables, retention categories, and export controls. Production reporting, external delivery, and real-value reporting remain disabled.

The ninth Phase 3 implementation slice adds operational runbooks. `config/phase3-operational-runbooks.yaml` and `scripts/phase3-operational-runbooks.ps1` define sandbox daily operations, validator operations for the Cloud Run Job plus Cloud Scheduler no-GKE topology, incident response, release/rollback, backup/restore, credential rotation, and audit evidence packs. Production operations, GKE validator operations, and real-value operations remain disabled.

The tenth Phase 3 implementation slice closes the sandbox enterprise track. `config/phase3-wrapup.yaml` and `scripts/phase3-wrapup.ps1` confirm all Phase 3 release candidates are present, production and real-value capabilities remain disabled, GKE/HSM/production ingress remain deferred, and the next phase is `phase-4-pre-production-readiness`.

Run the static Phase 3 planning check from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase3-validate.ps1
```

## Phase 4 Pre-Production Readiness

Phase 4 is complete on the no-GKE track `phase4-no-gke-preprod-readiness`. `PHASE4_PRE_PRODUCTION_READINESS.md`, `config/phase4-pre-production-readiness.yaml`, and `scripts/phase4-validate.ps1` define the readiness gates, cost gate, Phase 5 split, and non-enablement controls for pre-production planning. This keeps the active runtime on `phase2-lean-no-gke` and does not create Google Cloud resources, enable GKE, apply production ingress, enable HSM/KMS production signing, onboard external institutions, or allow real-value settlement.

The Phase 4 cost model checkpoint is recorded in `PHASE4_COST_MODEL.md`, `config/phase4-cost-model.yaml`, and `scripts/phase4-cost-model.ps1`. It captures cost-estimate inputs for the current no-GKE baseline, future production ingress, future HSM/KMS signing, future disaster recovery, security review, and separate GKE validator operations. It intentionally records no fixed live prices and requires live pricing to be checked before any paid-resource apply.

The Phase 4 security review scope checkpoint is recorded in `PHASE4_SECURITY_REVIEW_SCOPE.md`, `config/phase4-security-review-scope.yaml`, and `scripts/phase4-security-review-scope.ps1`. It defines security review objectives, in-scope assets, out-of-scope testing, threat areas, evidence requirements, and blocked review workstreams without executing a penetration test or changing infrastructure.

The Phase 4 HSM/KMS implementation plan checkpoint is recorded in `PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md`, `config/phase4-hsm-kms-implementation-plan.yaml`, `infra/terraform/phase4_hsm_kms_implementation_plan.tf`, and `scripts/phase4-hsm-kms-implementation-plan.ps1`. It defines future signing purposes, key lifecycle, staged adapters, signing request contracts, required apply gates, and design-only Terraform outputs without creating key rings, keys, HSM resources, signing services, or production signing capability.

The Phase 4 production ingress implementation plan checkpoint is recorded in `PHASE4_PROD_INGRESS_IMPLEMENTATION_PLAN.md`, `config/phase4-prod-ingress-implementation-plan.yaml`, `infra/terraform/phase4_prod_ingress_implementation_plan.tf`, and `scripts/phase4-prod-ingress-implementation-plan.ps1`. It defines future edge components, request paths, mTLS trust, Cloud Armor, admin OIDC, Cloud Run ingress rollback gates, and design-only Terraform outputs without creating load balancers, API Gateway resources, DNS records, certificates, trust configs, Cloud Armor policies, public endpoint exposure, or production ingress capability.

The Phase 4 disaster recovery readiness checkpoint is recorded in `PHASE4_DR_READINESS.md`, `config/phase4-dr-readiness.yaml`, `infra/terraform/phase4_dr_readiness.tf`, and `scripts/phase4-dr-readiness.ps1`. It defines recovery domains, sandbox/preprod RTO/RPO targets, restore-to-separate-target evidence drills, ledger reconciliation checks, validator recovery checks, secret recovery checks, and design-only Terraform outputs without executing restore drills, creating restore instances, changing backup settings, or enabling production recovery.

The Phase 4 legal/compliance evidence checkpoint is recorded in `PHASE4_LEGAL_COMPLIANCE_EVIDENCE.md`, `config/phase4-legal-compliance-evidence.yaml`, and `scripts/phase4-legal-compliance-evidence.ps1`. It defines the evidence register for legal classification, registration/MSB analysis, AML/KYC, sanctions, privacy, custody, institution agreements, security, penetration testing, incident response, cost, Terraform plan, and executive go-live review without giving legal advice, approving any gate, onboarding external institutions, or enabling production or real-value capability.

The Phase 4 wrap-up checkpoint is recorded in `PHASE4_WRAPUP.md`, `config/phase4-wrapup.yaml`, and `scripts/phase4-wrapup.ps1`. It confirms all Phase 4 release candidates are present, all production and real-value gates remain blocked, GKE remains deferred to `phase5b-gke-validator-ops`, and the next track is `phase5a-no-gke-validator-hardening`.

The planned validator-operations split is:

```text
phase5a-no-gke-validator-hardening
phase5b-gke-validator-ops
```

GKE is deferred to `phase5b-gke-validator-ops`; Phase 5A can still proceed without GKE by strengthening the Cloud Run Job plus Cloud Scheduler validator model.

Run the static Phase 4 readiness check from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-validate.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-cost-model.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-security-review-scope.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-hsm-kms-implementation-plan.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-prod-ingress-implementation-plan.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-dr-readiness.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-legal-compliance-evidence.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase4-wrapup.ps1
```

## Phase 5A No-GKE Validator Hardening

Phase 5A has started on the `phase5a-no-gke-validator-hardening` track. `PHASE5A_VALIDATOR_HARDENING_PLAN.md`, `config/phase5a-validator-hardening-plan.yaml`, and `scripts/phase5a-validator-hardening-plan.ps1` define the first validator hardening checkpoint for the existing Cloud Run Job plus Cloud Scheduler model.

The first Phase 5A implementation checkpoint is `phase5a-validator-reconciliation-rc1`. `PHASE5A_VALIDATOR_RECONCILIATION.md`, `config/phase5a-validator-reconciliation.yaml`, and `scripts/phase5a-validator-reconciliation.ps1` define the reconciliation evidence contract for pending transactions, issued supply, account balances, finalized blocks, audit events, settlement reports, compliance reports, validator finality reports, validator state, and `camt.053` journal evidence.

The second Phase 5A implementation checkpoint is `phase5a-scheduler-runbooks-rc1`. `PHASE5A_SCHEDULER_RUNBOOKS.md`, `config/phase5a-scheduler-runbooks.yaml`, and `scripts/phase5a-scheduler-runbooks.ps1` define the approved-operator evidence requirements and command templates for pausing, manually executing, and resuming the no-GKE validator Scheduler path. The checkpoint documents the procedure but does not execute or approve Scheduler changes.

The third Phase 5A implementation checkpoint is `phase5a-failure-retry-drills-rc1`. `PHASE5A_FAILURE_RETRY_DRILLS.md`, `config/phase5a-failure-retry-drills.yaml`, and `scripts/phase5a-failure-retry-drills.ps1` define the sandbox failure/retry drill matrix, approval gates, evidence requirements, and recovery expectations without enabling failure injection or live drill execution.

This checkpoint does not create Google Cloud resources, apply Terraform, change Scheduler jobs, run live failure drills, enable GKE, enable production BFT networking, onboard external institutions, or allow real-value settlement. It keeps the active runtime on `phase2-lean-no-gke` and carries forward the sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The Phase 5A plan hardens these areas before any live drill is enabled:

```text
validator_reconciliation_tests
failure_and_retry_drills
scheduler_pause_resume_runbooks
ledger_replay_and_finality_verification
operator_evidence_packs
alert_response_and_recovery_drills
complete_sandbox_smoke_tests
```

Run the Phase 5A checks from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase5a-validator-hardening-plan.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase5a-validator-reconciliation.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase5a-scheduler-runbooks.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase5a-failure-retry-drills.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase5a-validate.ps1
```

GKE remains deferred to `phase5b-gke-validator-ops`.

After cloud resources are applied and the image is deployed, run the no-GKE cloud smoke test:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-cloud-smoke.ps1
```

The lean cloud guardrails use a 15-minute validator schedule and a `50` unit monthly budget alert in the billing account currency. The current sandbox billing account reports `CAD`, and the budget is an alerting guardrail, not a hard cap. The budget also links an explicit Cloud Monitoring email notification channel for `selva@kani.network`; Google may require the recipient to verify that email channel before it can receive alerts. Pub/Sub and the `kani-cost-guard` Cloud Run service are connected for programmatic budget notifications, with the cost guard set to pause the validator Scheduler job if actual spend crosses `80%`.

Cloud Run sets `KANI_REQUIRE_CONFIGURED_SANDBOX_API_KEYS=TRUE` and loads all sandbox API keys from Secret Manager. The checked-in default keys remain only for local simulation; the cloud smoke test reads the live keys from Secret Manager.
The lean sandbox also has a security smoke test that verifies the API, validator job, cost-guard service, and Secret Manager keys are not publicly invokable/readable:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-security-smoke.ps1
```

Sandbox API keys are Terraform-managed Secret Manager versions. Rotate one with `scripts\rotate-sandbox-api-key.ps1 -Key corp_a -Apply`, then rerun the security and cloud smoke tests.

The initial ISO 20022 endpoints are `POST /v1/iso20022/pacs008`, `GET /v1/iso20022/pacs002/{payment_id}`, and `GET /v1/iso20022/camt053/accounts/{account_id}?asset=KCAD_TEST`. They accept a single-transfer `pacs.008` XML document, map debtor and creditor account identifiers to sandbox accounts, submit the payment through the same ledger path as `POST /v1/payments`, return a basic `pacs.002` XML status report, and produce a sandbox `camt.053` XML account statement from finalized journal entries.

The Phase 2 sandbox compliance profile is `sandbox-stp-v1`. It allows straight-through processing only between `CORP_A` and `CORP_B`, only for `KCAD_TEST*` and `KUSD_TEST*` assets, blocks self-transfers, flags payments above `500000` minor units for manual review, and records every payment-screening decision as a `COMPLIANCE_DECISION` audit event.

Admin reporting endpoints are `GET /v1/reports/settlement-summary`, `GET /v1/reports/compliance-decisions`, and `GET /v1/reports/validator-finality`. They summarize finalized settlement volume by asset, compliance decisions by rule/institution, and validator production/finality vote coverage for the sandbox operator.

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
Network-wide read APIs such as accounts, blocks, audit events, reports, validators, and pending transactions require sandbox admin headers:

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

curl "http://127.0.0.1:8080/v1/reports/settlement-summary?limit=500&offset=0" \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl "http://127.0.0.1:8080/v1/reports/compliance-decisions?limit=500&offset=0" \
  -H "x-kani-institution-id: KANI_ADMIN" \
  -H "x-kani-api-key: sandbox-admin-token"

curl "http://127.0.0.1:8080/v1/reports/validator-finality?limit=500&offset=0" \
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
