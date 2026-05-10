# Sandbox MVP Evidence Appendix

## Evidence Status

This appendix summarizes the implemented end-to-end sandbox MVP as of May 10, 2026. It is intended to support a technical disclosure, not to prove production readiness.

Source evidence in the repository:

```text
PHASE5B_GKE_DAY0_OBSERVATION.md
config/phase5b-gke-day0-observation.yaml
config/phase5b-gke-apply-pilot-evidence.yaml
README.md
scripts/phase2-cloud-smoke.ps1
scripts/phase5b-gke-day0-observation.ps1
```

## Sandbox Boundary

The system was operated under:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The following remained disabled:

```text
production_value_movement_allowed: false
external_institution_onboarding_enabled: false
fiat_deposit_redemption_enabled: false
```

No real money, customer deposits, fiat redemption, custody, trading, production ingress, or external institutional onboarding was enabled.

## Implemented Components

The implemented sandbox includes:

- Rust workspace with crates for API, node, ledger, consensus, crypto profiles, compliance, ISO 20022, and shared types.
- Ledger accounts, balances, issuance tracking, journal entries, pending transactions, audit events, and finalized blocks.
- Mint, burn, transfer, and ISO-originated payment paths.
- Permissioned PoA validator finality with three validators.
- Axum HTTP API.
- PostgreSQL-backed ledger state.
- Cloud Run API service.
- Cloud SQL PostgreSQL database.
- Secret Manager-backed sandbox API keys and database URL.
- Artifact Registry image deployment.
- Cloud Scheduler and Cloud Run Job legacy validator path.
- GKE continuous validator pilot.
- Cloud Monitoring alert policies.
- Cloud Billing budget guardrail and cost-guard service.

## Day-Zero Cloud Runtime

Captured at:

```text
2026-05-10T02:16:43.2744836-04:00
```

Observation window:

```text
2026-05-10 through 2026-06-10
```

Cloud Run API:

```text
service_name: kani-sandbox-api
latest_ready_revision: kani-sandbox-api-00012-n46
traffic_percent_latest_revision: 100
```

Cost guard:

```text
service_name: kani-sandbox-cost-guard
latest_ready_revision: kani-sandbox-cost-guard-00011-nfc
traffic_percent_latest_revision: 100
```

Cloud SQL:

```text
instance: kani-sandbox-ledger
state: RUNNABLE
database_version: POSTGRES_16
region: northamerica-northeast1
tier: db-g1-small
disk_size_gb: 10
backups_enabled: true
point_in_time_recovery_enabled: true
```

GKE:

```text
cluster: kani-sandbox-validators
zone: northamerica-northeast1-a
status: RUNNING
kubernetes_version: 1.35.3-gke.1389000
node_count: 1
node_machine_type: e2-medium
workload_pool: kani-network-sandbox.svc.id.goog
```

Legacy validator Scheduler:

```text
job_name: kani-sandbox-validator-schedule
state: PAUSED
```

## Budget Guardrail

Verified budget:

```text
display_name: kani-sandbox-monthly-budget
currency: CAD
amount_units: 200
thresholds: 50%, 80%, 100%
threshold_amounts: CAD 100, CAD 160, CAD 200
hard_cap: false
```

The budget guardrail is for alerting and automation. It is not a hard cap. The cost guard pauses the legacy Scheduler validator path and does not stop the GKE cluster.

## Validator Health

Deployments ready:

```text
validator-a: 1/1
validator-b: 1/1
validator-c: 1/1
```

Pods:

```text
validator-a-5d9c6d7669-74mbn: 2/2 Running, 0 restarts
validator-b-5ffbf579d5-lf9ch: 2/2 Running, 0 restarts
validator-c-845b96c77c-xzsbm: 2/2 Running, 0 restarts
```

Resource usage:

```text
node_cpu: 201m, 21%
node_memory: 1343Mi, 47%
validator-a: 41m CPU, 12Mi memory
validator-b: 21m CPU, 12Mi memory
validator-c: 21m CPU, 13Mi memory
```

## End-To-End Smoke Test Result

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\phase2-cloud-smoke.ps1 -SkipValidatorJob -WaitForContinuousValidators
```

Observed result:

```text
profile: phase5b-gke-continuous-validators
health: ok
asset: KCAD_TEST_20260510021545
mint_transaction: c40bd07e-1bc5-4cc1-aa92-a8dd33f7e084
transfer_transaction: 02a141d0-6722-4c5e-9a56-e39168e83203
iso_transaction: bc4667c2-485a-49cb-b531-68e5a5ea5708
iso_message_id: phase2-cloud-iso-KCAD_TEST_20260510021545
iso_status: ACSC
corp_a_balance: 875000
corp_b_balance: 125000
latest_block_height: 42
latest_block_validator: validator-c
latest_block_finalized_by: validator-c, validator-a
pending_count: 0
audit_reports_verified: true
settlement_report_transactions: 42
compliance_report_events: 20
validator_report_finalized_blocks: 42
status: ok
```

## Functional Proof Points

The smoke evidence demonstrates:

1. API health.
2. Treasury mint of test asset.
3. Transfer between sandbox institutions.
4. ISO-originated transaction handling.
5. ISO status response of `ACSC`.
6. Compliance self-transfer block.
7. Finalized block append.
8. Validator finality metadata.
9. Zero pending transactions after finality.
10. Settlement report availability.
11. Compliance report availability.
12. Validator finality report availability.
13. Audit/report verification.

## Log Review

Application namespace query:

```text
resource.labels.namespace_name="kani-system" AND severity>=ERROR
freshness: 2h
result: no_rows
```

Broad project scan found GKE system component messages in `kube-system`, including `gke-metrics-agent` EOF messages and `metrics-server` kubelet scrape timeouts. Because validators were running, resource metrics were available, and the smoke test passed, these were recorded as watch items rather than blockers.

## Validation Commands

The following validation categories were executed around the day-zero checkpoint:

```text
phase5b-gke-day0-observation.ps1: passed
phase5b-validate.ps1: passed
phase2-validate.ps1: passed
terraform infra/terraform validate: passed
terraform infra/terraform-gke validate: passed
terraform infra/terraform plan: no changes
terraform infra/terraform-gke plan: no changes
git diff --check: no whitespace errors
```

## Limits And Non-Implemented Production Items

The sandbox MVP does not include:

- Real-money settlement.
- Fiat deposits or redemption.
- Custody for customers.
- External institution onboarding.
- Production mTLS ingress.
- Production OIDC administration.
- Production HSM/KMS signing.
- Production BFT validator network.
- Legal or regulatory production approval.

## Attorney Notes

The evidence appendix should be treated as implementation support. Counsel should decide whether to include raw operational identifiers in a provisional filing or retain them as internal corroborating engineering records.

