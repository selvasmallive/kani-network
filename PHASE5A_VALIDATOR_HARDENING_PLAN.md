# KANI Phase 5A Validator Hardening Plan

Status: validator hardening plan ready
Release candidate: `phase5a-validator-hardening-plan-rc1`
Date: 2026-05-10

Phase 5A starts the no-GKE validator hardening track. This checkpoint defines the work plan and guardrails for strengthening the current Cloud Run Job plus Cloud Scheduler validator model before any real validator operations lab is attempted.

This is a planning checkpoint only. It does not create Google Cloud resources, does not apply Terraform, does not change Scheduler jobs, does not run live failure drills, does not enable GKE, does not enable production BFT networking, and does not authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase4-wrapup-rc1`.

## Track

Phase 5A track:

```text
phase5a-no-gke-validator-hardening
```

GKE remains deferred to:

```text
phase5b-gke-validator-ops
```

## Validator Model

Phase 5A hardens the existing sandbox validator model:

- Runtime: Cloud Run Job plus Cloud Scheduler.
- Run mode: `sweep`.
- Validator set: `validator-a`, `validator-b`, `validator-c`.
- Consensus: Phase 1 PoA.
- Finality target: 2 of 3 validator finality.
- Scheduler cadence: 15-minute cadence from the Phase 2 lean no-GKE baseline.

This model is sufficient for sandbox end-to-end evidence while GKE remains deferred.

## Hardening Workstreams

Phase 5A will use these seven workstreams:

1. `validator_reconciliation_tests`
   - Prove pending transactions, finalized blocks, balances, issued supply, audit events, and validator state reconcile after validator sweeps.
2. `failure_and_retry_drills`
   - Define controlled sandbox-only failure and retry evidence before any live drill is enabled.
3. `scheduler_pause_resume_runbooks`
   - Document how operators pause, resume, and manually trigger the validator Scheduler path without changing production posture.
4. `ledger_replay_and_finality_verification`
   - Rebuild ledger evidence from finalized blocks and verify PoA finality metadata.
5. `operator_evidence_packs`
   - Standardize the evidence bundle operators collect for each sandbox validator check.
6. `alert_response_and_recovery_drills`
   - Connect Cloud Monitoring alert evidence to response and recovery runbooks without executing production recovery.
7. `complete_sandbox_smoke_tests`
   - Expand sandbox smoke coverage for payments, ISO 20022, compliance holds/rejections, reports, validators, and audit trails.

## Future Implementation Gates

Before any live Phase 5A drill can be run, these gates must be explicitly satisfied:

- Cost reviewed if any paid resources or higher runtime usage are required.
- Scheduler change window approved by the sandbox operator.
- Failure drill owner assigned.
- Recovery owner assigned.
- Rollback path documented.
- Evidence pack location selected.
- No real-value, redemption, custody, trading, or external institution capability enabled.

These gates are not approved by this checkpoint.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE cluster creation.
- Terraform apply.
- Google Cloud resource creation or mutation.
- Validator Scheduler changes.
- Live failure drills.
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

- Phase 5A validator hardening plan is checked in.
- Structured Phase 5A config exists.
- Static Phase 5A validator hardening plan script passes.
- Aggregate Phase 5A validator passes.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No GKE, live failure drill, Scheduler mutation, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
