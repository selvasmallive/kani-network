# KANI Phase 5A Operator Evidence Packs

Status: operator evidence packs checkpoint ready
Release candidate: `phase5a-operator-evidence-packs-rc1`
Date: 2026-05-10

This checkpoint turns the Phase 5A workstream `operator_evidence_packs` into a standard evidence contract. It defines the pack types, required metadata, required snapshots, redaction rules, review workflow, and acceptance criteria that operators use for the no-GKE validator hardening track.

This is a planning and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, change Cloud Scheduler, execute validator jobs, inject failures, run live drills, enable GKE, enable production BFT networking, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase5a-ledger-replay-finality-rc1`.

## Evidence Pack Objective

Operator evidence packs must make each sandbox validator hardening action reviewable and repeatable:

- Record who ran the check, when it ran, and why it ran.
- Bind evidence to a fresh sandbox asset or named sandbox incident.
- Capture the validator runtime, scheduler state, validator state, block state, reports, audit evidence, and reconciliation result.
- Record the expected outcome and actual outcome.
- Record residual risk and follow-up actions.
- Preserve proof that real-value and production capabilities remained disabled.
- Exclude secrets, private keys, raw tokens, and real customer data.

## Evidence Pack Types

Phase 5A uses these pack types:

1. `validator_reconciliation_pack`
2. `scheduler_pause_resume_pack`
3. `failure_retry_drill_pack`
4. `ledger_replay_finality_pack`
5. `alert_response_recovery_pack`
6. `sandbox_smoke_test_pack`
7. `phase5a_wrapup_pack`

## Required Common Metadata

Every evidence pack must include:

- `pack_id`
- `pack_type`
- `release_candidate`
- `environment`
- `real_value`
- `redeemable`
- `operator`
- `reviewer`
- `started_at`
- `completed_at`
- `base_url`
- `project_id`
- `region`
- `asset`
- `purpose`
- `change_window`
- `related_incident`
- `source_scripts`
- `source_commit`
- `source_tag`
- `result`
- `residual_risk`
- `follow_up_actions`

## Required Evidence Sections

Every evidence pack must include:

- `sandbox_boundary`
- `runtime_context`
- `validator_context`
- `scheduler_context`
- `block_context`
- `ledger_context`
- `reporting_context`
- `audit_context`
- `reconciliation_context`
- `operator_decision`
- `reviewer_decision`
- `redaction_attestation`

## Redaction Rules

Evidence packs must not include:

- API keys.
- Bearer tokens.
- Secret Manager values.
- Raw private keys.
- Signing material.
- Customer data.
- Real-value records.
- Terraform state secrets.
- Database passwords.

The operator must attest that the pack was reviewed for secret leakage before it is marked complete.

## Review Workflow

Each pack moves through these review states:

```text
draft -> operator_complete -> reviewer_approved -> archived
```

If evidence is missing or inconsistent, the pack moves to:

```text
returned_for_correction
```

Production approval is not a valid Phase 5A evidence pack state.

## Retention Labels

Evidence packs must be labeled as:

- `sandbox_only`
- `no_real_value`
- `no_gke`
- `no_production_authorization`
- `phase5a_no_gke_validator_hardening`

## Non-Enablement

This checkpoint keeps the following disabled:

- Evidence export to external institutions.
- Production approval through evidence pack review.
- Live replay execution against production data.
- Failure injection.
- Live drill execution.
- GKE cluster creation.
- Terraform apply.
- Google Cloud resource creation or mutation.
- Cloud Scheduler mutation.
- Production BFT validator network.
- Production ingress.
- Public endpoint exposure.
- Cloud Armor WAF apply.
- mTLS trust config apply.
- HSM/KMS production signing.
- Restore drill execution.
- Production recovery execution.
- External institution onboarding.
- Production authorization.
- Real-value settlement.
- Fiat deposit or redemption.
- Custody for others.
- Trading.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- Operator evidence pack document is checked in.
- Structured operator evidence pack config exists.
- Static operator evidence pack validator passes.
- Aggregate Phase 5A validator includes operator evidence packs.
- Phase 5A ledger replay, failure/retry, scheduler, reconciliation, and hardening plan validators still pass.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No external evidence export, production approval, production replay, failure injection, live drill execution, Scheduler mutation, GKE, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
