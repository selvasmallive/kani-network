# KANI Phase 5A Failure And Retry Drill Plan

Status: failure and retry drill plan ready
Release candidate: `phase5a-failure-retry-drills-rc1`
Date: 2026-05-10

This checkpoint turns the Phase 5A workstream `failure_and_retry_drills` into a sandbox-only drill design. It defines the failure modes, retry expectations, evidence requirements, and approval gates that must exist before any live failure drill can be executed.

This is a planning and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, change Cloud Scheduler, execute validator jobs, inject failures, run live drills, enable GKE, enable production BFT networking, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase5a-scheduler-runbooks-rc1`.

## Drill Objective

Failure and retry drills must prove that the no-GKE validator model can recover safely from controlled sandbox disruptions without corrupting ledger state:

- No double finalization.
- No duplicate payment settlement.
- Idempotent payment retry behavior remains intact.
- Pending transactions either finalize or remain visible for operator action.
- Validator sweep retries do not break PoA finality.
- Failed jobs produce observable evidence.
- Audit and reconciliation evidence remains complete.

## Drill Matrix

The planned drill matrix is:

1. `validator_job_retry_after_transient_failure`
   - Simulate or rehearse a validator job failure and retry path.
2. `scheduler_missed_trigger_detection`
   - Prove operators can detect a missed or delayed Scheduler trigger.
3. `manual_validator_rerun_after_pending_queue`
   - Prove approved manual execution can drain pending transactions.
4. `idempotent_payment_retry_after_client_timeout`
   - Prove duplicate client submissions with the same idempotency key do not double settle.
5. `compliance_hold_release_retry`
   - Prove held payments remain out of validator finality until approved.
6. `database_connectivity_transient_failure`
   - Rehearse the evidence expected when the ledger database is temporarily unavailable.
7. `cost_guard_scheduler_pause_recovery`
   - Rehearse evidence for budget brake pause handling without triggering real spend actions.
8. `validator_report_reconciliation_after_retry`
   - Prove validator finality reports still reconcile after a retry path.

## Required Gates Before Live Drill Execution

This checkpoint does not approve live drill execution. Before any live drill, the evidence pack must show:

- Sandbox-only purpose recorded.
- Drill owner assigned.
- Recovery owner assigned.
- Approver identified.
- Change window approved.
- Target drill selected from the drill matrix.
- Expected failure signal documented.
- Expected retry signal documented.
- Rollback path documented.
- Evidence pack location selected.
- Cost impact reviewed.
- Scheduler action approval recorded when relevant.
- Database impact approval recorded when relevant.
- Real-value capability confirmed disabled.

## Required Evidence

Every future live drill must collect:

- Pre-drill sandbox boundary confirmation.
- Pre-drill pending transaction count.
- Pre-drill latest block and validator finality report.
- Pre-drill validator state.
- Drill action log.
- Failure signal.
- Retry signal.
- Post-retry pending transaction count.
- Post-retry latest block and validator finality report.
- Post-retry validator state.
- Audit event sample.
- Settlement summary sample.
- Compliance decision sample where relevant.
- Reconciliation result from `phase5a-validator-reconciliation-rc1`.
- Scheduler evidence from `phase5a-scheduler-runbooks-rc1` when relevant.
- Operator conclusion.
- Residual risk.

The evidence pack must not include API keys, bearer tokens, Secret Manager values, raw private keys, customer data, or real-value records.

## Recovery Expectations

A drill can be marked successful only when:

- Pending transactions reach the expected terminal state.
- Finalized block height is monotonic.
- Finalized block hashes remain stable.
- Finality votes remain at least 2 of 3.
- Validator identities remain inside the configured validator set.
- Issued supply equals reconciled balances for the drill asset.
- Reports and audit evidence are readable.
- No production or real-value capability is enabled.

## Non-Enablement

This checkpoint keeps the following disabled:

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

- Failure and retry drill plan is checked in.
- Structured failure and retry drill config exists.
- Static failure and retry drill validator passes.
- Aggregate Phase 5A validator includes failure and retry drill planning.
- Phase 5A scheduler, reconciliation, and hardening plan validators still pass.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No failure injection, live drill execution, Scheduler mutation, GKE, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
