# KANI Phase 5A Alert Response And Recovery

Status: alert response and recovery checkpoint ready
Release candidate: `phase5a-alert-response-recovery-rc1`
Date: 2026-05-10

This checkpoint turns the Phase 5A workstream `alert_response_and_recovery_drills` into a standard incident response and recovery evidence contract for the no-GKE validator hardening track. It defines alert classes, response stages, evidence sources, recovery action boundaries, approval gates, and acceptance criteria for sandbox-only operations.

This is a planning and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, change Cloud Scheduler, execute validator jobs, rotate secrets, inject failures, run live recovery drills, enable GKE, enable production BFT networking, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase5a-operator-evidence-packs-rc1`.

## Response Objective

Alert response and recovery packs must make every sandbox alert decision reviewable:

- Detect the alert source and bind it to a named sandbox incident.
- Classify the alert by operational impact, financial boundary risk, and validator finality risk.
- Contain the issue without changing production settings or enabling real-value capability.
- Collect evidence before any recovery action.
- Recover only through pre-approved manual steps.
- Reconcile ledger, validator, report, and audit state after recovery.
- Review residual risk and follow-up actions.
- Archive the evidence pack with redaction attestation.

## Alert Classes

Phase 5A tracks these sandbox alert classes:

1. `api_error_logs`
2. `validator_job_error_logs`
3. `scheduler_error_logs`
4. `cloud_sql_error_logs`
5. `budget_brake_activity_logs`
6. `validator_finality_gap`
7. `pending_transaction_backlog`
8. `ledger_reconciliation_discrepancy`

## Required Response Stages

Every alert response evidence pack must include these stages:

1. `detect`
2. `classify`
3. `contain`
4. `collect_evidence`
5. `recover`
6. `reconcile`
7. `review`
8. `archive`

## Evidence Sources

The operator must collect applicable evidence from:

- Cloud Monitoring alert incident.
- Cloud Logging query/export summary.
- Cloud Run service execution state.
- Cloud Run validator job execution state.
- Cloud Scheduler job state.
- Cloud SQL health and error evidence.
- Budget and cost-guard event evidence when relevant.
- `GET /health`
- `GET /v1/transactions/pending?limit=500&offset=0`
- `GET /v1/blocks/latest`
- `GET /v1/reports/validator-finality?limit=500&offset=0`
- `GET /v1/reports/settlement-summary?limit=500&offset=0`
- `GET /v1/reports/compliance-decisions?limit=500&offset=0`
- `GET /v1/audit-events?limit=500&offset=0`
- Prior operator evidence pack.

## Recovery Action Catalog

Phase 5A recovery actions are documented only and require explicit approval before execution:

- Acknowledge the incident.
- Collect baseline evidence.
- Manually execute the validator job if approved.
- Resume Scheduler if approved.
- Rotate the sandbox API key if the incident involves key exposure and rotation is approved.
- Run reconciliation evidence after the recovery action.
- Document residual risk and follow-up actions.

This checkpoint does not approve any manual Scheduler change, Cloud Run Job execution, secret rotation, failure injection, live recovery drill, restore drill, or production recovery.

## Required Gates Before Live Recovery Drill Or Action

Before any live recovery drill or mutating recovery action is considered, these gates must be completed outside this checkpoint:

- `sandbox_only_purpose_recorded`
- `incident_owner_assigned`
- `recovery_owner_assigned`
- `approver_identified`
- `change_window_approved`
- `expected_alert_signal_documented`
- `expected_recovery_signal_documented`
- `operator_evidence_pack_location_selected`
- `rollback_path_documented`
- `cost_impact_reviewed`
- `no_real_value_capability_enabled`

All gates remain blocked by this checkpoint.

## Non-Enablement

This checkpoint keeps the following disabled:

- Live recovery drills.
- Manual Scheduler action approval.
- Automatic Scheduler mutation.
- Cloud Run Job execution approval.
- Secret rotation approval.
- Failure injection.
- Restore drill execution.
- Production recovery execution.
- External evidence export.
- Production approval through evidence review.
- GKE cluster creation.
- Terraform apply.
- Google Cloud resource creation or mutation.
- Production BFT validator network.
- Production ingress.
- Public endpoint exposure.
- Cloud Armor WAF apply.
- mTLS trust config apply.
- HSM/KMS production signing.
- External institution onboarding.
- Production authorization.
- Real-value settlement.
- Fiat deposit or redemption.
- Custody for others.
- Trading.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- Alert response and recovery document is checked in.
- Structured alert response and recovery config exists.
- Static alert response and recovery validator passes.
- Aggregate Phase 5A validator includes alert response and recovery.
- Phase 5A operator evidence pack, ledger replay, failure/retry, scheduler, reconciliation, and hardening plan validators still pass.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No live recovery drills, Scheduler mutation, Cloud Run Job execution approval, secret rotation approval, failure injection, restore drill execution, production recovery, GKE, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
