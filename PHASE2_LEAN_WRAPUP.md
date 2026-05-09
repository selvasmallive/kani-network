# KANI Phase 2 Lean No-GKE Wrap-Up

Status: release candidate
Date: 2026-05-09
Scope: `phase2-lean-no-gke`

Observation report: `PHASE2_OBSERVATION_REPORT.md`

Phase 2 lean has reached an end-to-end sandbox cloud MVP without GKE. The system still runs only as an internal simulation and must not be used for real money movement, customer funds, fiat redemption, custody, trading, or production payment services.

## Runtime Boundary

Every deployed Phase 2 workload keeps the sandbox flags:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The Cloud Run API also requires configured sandbox API keys from Secret Manager:

```text
KANI_REQUIRE_CONFIGURED_SANDBOX_API_KEYS = TRUE
```

## Completion Snapshot

| Area | Status | Notes |
| --- | --- | --- |
| Rust workspace and local ledger | Complete | Phase 1 workspace, accounts, transactions, PoA finality, API, PostgreSQL mode, Docker stack, and smoke tests are in place. |
| Cloud foundation | Complete | Terraform provisions the lean sandbox on Google Cloud without GKE. |
| API deployment | Complete | `kani-api` runs on Cloud Run with Cloud SQL PostgreSQL persistence. |
| Validator finality | Complete for lean MVP | `kani-node` runs as a Cloud Run Job in `sweep` mode across `validator-a`, `validator-b`, and `validator-c`. |
| Scheduled finality | Complete | Cloud Scheduler triggers the validator job every 15 minutes. |
| Secret handling | Complete | Database URL and sandbox API keys are Terraform-managed Secret Manager versions. |
| Sandbox API auth | Complete | Cloud Run IAM is required and app-level sandbox institution/API-key checks remain active. |
| Compliance | Complete for sandbox MVP | `sandbox-stp-v1` blocks out-of-bound payments and records compliance decisions. |
| ISO 20022 | Complete for initial MVP | `pacs.008`, `pacs.002`, and `camt.053` sandbox paths are implemented and smoke-tested. |
| Audit and reporting | Complete for sandbox MVP | Settlement, compliance, validator finality, journal, and audit data are queryable. |
| Recovery | Complete for sandbox MVP | Cloud SQL backups and point-in-time recovery are enabled. |
| Budget guardrails | Complete | Billing budget, email channel, Pub/Sub notifications, and a cost-guard service are provisioned. |
| Monitoring | Complete for sandbox MVP | Log-based alert policies cover API, validator, Scheduler, Cloud SQL, and budget-brake events. |
| Security smoke | Complete | Public Cloud Run invokers and public Secret Manager access are checked by script. |

## Live Sandbox Resources

These are the current Terraform outputs for the lean sandbox. Secret values are intentionally not listed.

| Resource | Value |
| --- | --- |
| Project | `kani-network-sandbox` |
| Region | `northamerica-northeast1` |
| Artifact Registry repository | `kani` |
| Cloud Run API service | `kani-sandbox-api` |
| Cloud Run API URI | `https://kani-sandbox-api-mlmnojda4a-nn.a.run.app` |
| Cloud SQL connection | `kani-network-sandbox:northamerica-northeast1:kani-sandbox-ledger` |
| Database URL secret | `kani-sandbox-database-url` |
| Sandbox key secrets | `kani-sandbox-treasury-api-key`, `kani-sandbox-corp-a-api-key`, `kani-sandbox-corp-b-api-key`, `kani-sandbox-admin-api-key` |
| Validator job | `kani-sandbox-validator` |
| Validator service account | `kani-sandbox-validator@kani-network-sandbox.iam.gserviceaccount.com` |
| Validator scheduler | `kani-sandbox-validator-schedule` |
| Budget guardrail ID | `4f249fd0-801d-42f6-8070-5646e83cd305` |
| Budget Pub/Sub topic | `projects/kani-network-sandbox/topics/kani-sandbox-budget-notifications` |
| Cost guard service | `kani-sandbox-cost-guard` |
| Cost guard URI | `https://kani-sandbox-cost-guard-mlmnojda4a-nn.a.run.app` |
| Cloud SQL recovery | Backups enabled, PITR enabled, 7 retained backups, 7 days transaction-log retention, 07:00 UTC backup window |

## Verification Evidence

Last verified from the workstation on 2026-05-09:

| Check | Result |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\phase2-validate.ps1` | `status = ok` |
| `terraform fmt -check` | Passed |
| `terraform validate` | Passed |
| `terraform plan -detailed-exitcode` | No changes |
| `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\phase2-security-smoke.ps1` | `status = ok` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\phase2-cloud-smoke.ps1` | `status = ok` |

Security smoke evidence:

```text
api_public_invoker_absent = True
cost_guard_public_invoker_absent = True
validator_job_public_invoker_absent = True
secret_public_access_absent = True
secret_backed_api_env_verified = True
unauthenticated_health_denied_status = 403
invalid_sandbox_key_denied_status = 401
```

Cloud smoke evidence:

```text
asset = KCAD_TEST_20260509083119
iso_status = ACSC
compliance_blocked_self_transfer = True
corp_a_balance = 875000
corp_b_balance = 125000
latest_block_height = 33
latest_block_validator = validator-c
latest_block_finalized_by = validator-c,validator-a
pending_count = 0
audit_reports_verified = True
settlement_report_transactions = 33
compliance_report_events = 11
validator_report_finalized_blocks = 33
```

## Acceptance Criteria

| Criterion | Result |
| --- | --- |
| Payment processed end to end | Passed |
| Ledger consistent | Passed |
| Block finalized | Passed |
| Audit logged | Passed |
| Validators running | Passed for lean profile via Cloud Run Job |
| Sandbox-only runtime enforced | Passed |
| No public API invocation | Passed |
| No public Secret Manager access | Passed |
| Budget guardrail present | Passed |

## Intentional Deferrals

These items are intentionally outside `phase2-lean-no-gke` and should come back when the project is ready for higher-cost or production-like validation:

- GKE validator cluster and node pool.
- Independent validator host isolation and multi-zone validator operations.
- Cloud Storage block archive.
- Cloud KMS/HSM key ceremonies.
- API Gateway, Cloud Armor, institution mTLS, and production ingress design.
- BFT consensus.
- Multi-institution onboarding workflow.
- Full AML/KYC compliance program integration.
- Legal review, FINTRAC/MSB readiness, and any real-value settlement capability.

## Residual Risks

- Cloud Billing budgets are alerts, not hard caps.
- The automated budget brake only pauses the validator Scheduler job; it does not stop Cloud SQL, Artifact Registry storage, or all possible charges.
- The Cloud Monitoring email notification channel may require recipient verification before email delivery is reliable.
- Cloud Run ingress is still direct Cloud Run ingress for sandbox testing; IAM and app credentials protect it, but this is not the final production network edge.
- The validator job proves finality mechanics, but it is not a distributed validator network.

## Next Gate

Phase 2 lean is ready for a short observation window:

1. Confirm the Cloud Monitoring email channel for `selva@kani.network` is verified.
2. Let the 15-minute scheduler run through several validator cycles.
3. Review Cloud Run, Scheduler, Cloud SQL, and cost-guard logs for alert noise.
4. Re-run `scripts\phase2-security-smoke.ps1` and `scripts\phase2-cloud-smoke.ps1`.
5. Decide whether the next track is Phase 3 application features or a later Phase 2 GKE validator-operations profile.
