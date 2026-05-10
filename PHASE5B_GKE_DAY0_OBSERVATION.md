# KANI Phase 5B GKE Day-Zero Observation

Release candidate: `phase5b-gke-day0-observation-rc1`

Status: `day_zero_observation_recorded`

Captured at: `2026-05-10T02:16:43.2744836-04:00`

Observation window: `2026-05-10` through `2026-06-10`

## Boundary

This checkpoint records the first observation baseline for the approved one-month sandbox GKE validator pilot.

The runtime remains sandbox-only:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

No production ingress, external institution onboarding, fiat deposit/redemption, custody, trading, real-value settlement, or production authorization is enabled by this checkpoint.

## Live Runtime

Cloud Run API:

```text
service: kani-sandbox-api
url: https://kani-sandbox-api-mlmnojda4a-nn.a.run.app
latest_ready_revision: kani-sandbox-api-00012-n46
traffic: 100% latest revision
```

Cost guard:

```text
service: kani-sandbox-cost-guard
latest_ready_revision: kani-sandbox-cost-guard-00011-nfc
traffic: 100% latest revision
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
version: 1.35.3-gke.1389000
node_count: 1
node_machine_type: e2-medium
workload_pool: kani-network-sandbox.svc.id.goog
```

Legacy validator Scheduler state:

```text
kani-sandbox-validator-schedule: PAUSED
```

## Budget Guardrail

The project budget guardrail was verified as:

```text
display_name: kani-sandbox-monthly-budget
currency: CAD
amount: 200
thresholds: 50%, 80%, 100%
```

This is an alerting and automation guardrail, not a hard spending cap. The connected cost guard pauses the legacy Cloud Scheduler validator path, but it does not stop the Phase 5B GKE cluster.

## Validator Health

Deployments:

```text
validator-a: 1/1 ready
validator-b: 1/1 ready
validator-c: 1/1 ready
```

Pods:

```text
validator-a-5d9c6d7669-74mbn: 2/2 Running, 0 restarts
validator-b-5ffbf579d5-lf9ch: 2/2 Running, 0 restarts
validator-c-845b96c77c-xzsbm: 2/2 Running, 0 restarts
```

Resource usage at capture:

```text
node_cpu: 201m, 21%
node_memory: 1343Mi, 47%
validator-a: 41m CPU, 12Mi memory
validator-b: 21m CPU, 12Mi memory
validator-c: 21m CPU, 13Mi memory
```

## Smoke Evidence

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\phase2-cloud-smoke.ps1 -SkipValidatorJob -WaitForContinuousValidators
```

Result:

```text
profile: phase5b-gke-continuous-validators
health: ok
asset: KCAD_TEST_20260510021545
mint_transaction: c40bd07e-1bc5-4cc1-aa92-a8dd33f7e084
transfer_transaction: 02a141d0-6722-4c5e-9a56-e39168e83203
iso_transaction: bc4667c2-485a-49cb-b531-68e5a5ea5708
iso_status: ACSC
corp_a_balance: 875000
corp_b_balance: 125000
latest_block_height: 42
latest_block_validator: validator-c
latest_block_finalized_by: validator-c, validator-a
pending_count: 0
audit_reports_verified: true
validator_report_finalized_blocks: 42
status: ok
```

## Log Review

Application namespace:

```text
query: resource.labels.namespace_name="kani-system" AND severity>=ERROR
freshness: 2h
result: no rows
```

Broad project scan found GKE system component entries from `kube-system`, including `gke-metrics-agent` UAS EOF messages and `metrics-server` kubelet scrape timeouts. The validators were healthy, `kubectl top` worked, and the smoke test passed, so this is recorded as a day-zero watch item rather than a release blocker.

Recent Kubernetes events also include early startup scheduling/resource warnings and one old non-numeric-user image check event. The live validator deployments now include explicit `runAsUser: 1000` and `runAsGroup: 1000`, and the current pods are running.

## Observation Plan

Next checks:

```text
first_billing_review: 2026-05-11 through 2026-05-13
weekly_runtime_review: every 7 days during the observation window
planned_end_review: 2026-06-10
```

Watch items:

```text
- Actual Google Cloud spend once billing data catches up.
- GKE system metrics stderr entries.
- Validator pod restarts.
- Pending transaction count.
- Block-finality progress.
- Budget alert delivery.
```

Teardown remains the default after the observation window or earlier if the validator pilot is idle.
