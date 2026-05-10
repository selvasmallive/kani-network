# KANI Phase 5A Scheduler Pause/Resume Runbooks

Status: scheduler runbooks checkpoint ready
Release candidate: `phase5a-scheduler-runbooks-rc1`
Date: 2026-05-10

This checkpoint turns the Phase 5A workstream `scheduler_pause_resume_runbooks` into an operator runbook for the no-GKE validator path. It covers the Cloud Scheduler job that triggers the Cloud Run validator job in `sweep` mode.

This is a documentation and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, change Cloud Scheduler, execute validator jobs, run live failure drills, enable GKE, enable production BFT networking, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase5a-validator-reconciliation-rc1`.

## Scheduler Model

The active no-GKE scheduler model is:

- Scheduler job: `kani-sandbox-validator-scheduler`
- Validator job: `kani-sandbox-validator`
- Project: `kani-network-sandbox`
- Region and Scheduler location: `northamerica-northeast1`
- Cadence: `*/15 * * * *`
- Validator run mode: `sweep`
- Validator set: `validator-a`, `validator-b`, `validator-c`
- Consensus: Phase 1 PoA
- Finality target: 2 of 3 validator finality

## Required Approvals Before Any Manual Scheduler Action

This checkpoint does not approve manual Scheduler actions. Before an operator pauses, resumes, or manually executes the validator job, the evidence pack must show:

- Sandbox-only purpose recorded.
- Operator and approver identified.
- Change window approved.
- Reason for action recorded.
- Current Scheduler state captured.
- Current validator job state captured.
- Current pending transaction count captured.
- Current latest block and validator finality report captured.
- Rollback path identified.
- Real-value capability confirmed disabled.

## Runbook Steps

### 1. Pre-Pause Checks

Collect baseline evidence before any Scheduler action:

```powershell
gcloud scheduler jobs describe kani-sandbox-validator-scheduler --location northamerica-northeast1 --project kani-network-sandbox
gcloud run jobs describe kani-sandbox-validator --region northamerica-northeast1 --project kani-network-sandbox
```

Also collect sandbox API evidence from `/health`, `/v1/transactions/pending`, `/v1/blocks/latest`, `/v1/reports/validator-finality`, and `/v1/validators`.

### 2. Pause Scheduler

Use only inside an approved sandbox change window:

```powershell
gcloud scheduler jobs pause kani-sandbox-validator-scheduler --location northamerica-northeast1 --project kani-network-sandbox
```

Record the command output and immediately re-run `gcloud scheduler jobs describe`.

### 3. Manual Validator Execution

Use only when manual validator sweep execution is approved:

```powershell
gcloud run jobs execute kani-sandbox-validator --region northamerica-northeast1 --project kani-network-sandbox --wait
```

After execution, run the Phase 5A validator reconciliation evidence procedure and verify pending transactions drain to zero.

### 4. Resume Scheduler

Use only after reconciliation is successful or rollback is approved:

```powershell
gcloud scheduler jobs resume kani-sandbox-validator-scheduler --location northamerica-northeast1 --project kani-network-sandbox
```

Record the command output and immediately re-run `gcloud scheduler jobs describe`.

### 5. Post-Resume Reconciliation

Collect the same evidence as the pre-pause baseline and compare:

- Scheduler state.
- Validator state.
- Pending transactions.
- Latest block height and hash.
- Finality vote count.
- Validator finality report.
- Audit events.

### 6. Rollback And Escalation

If the Scheduler cannot resume, the validator job fails, or pending transactions do not drain:

- Keep the incident sandbox-only.
- Do not create new cloud resources.
- Do not apply Terraform.
- Do not modify production ingress, HSM/KMS signing, or GKE settings.
- Escalate to the sandbox technical operator and settlement operator.
- Preserve command output and API evidence.
- Resume Scheduler only after the rollback owner approves.

### 7. Evidence Pack

The operator evidence pack must include:

- `run_id`
- `operator`
- `approver`
- `change_window`
- `reason`
- `scheduler_state_before`
- `validator_job_state_before`
- `pending_count_before`
- `latest_block_before`
- `validator_finality_before`
- `pause_command_output`
- `manual_execute_command_output`
- `resume_command_output`
- `scheduler_state_after`
- `validator_job_state_after`
- `pending_count_after`
- `latest_block_after`
- `validator_finality_after`
- `reconciliation_result`
- `rollback_required`
- `incident_reference`

The evidence pack must not include API keys, bearer tokens, Secret Manager values, raw private keys, customer data, or real-value records.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE cluster creation.
- Terraform apply.
- Google Cloud resource creation or mutation.
- Automatic Scheduler mutation.
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

- Scheduler pause/resume runbook is checked in.
- Structured scheduler runbook config exists.
- Static scheduler runbook validator passes.
- Aggregate Phase 5A validator includes scheduler runbooks.
- Phase 5A reconciliation and hardening plan validators still pass.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No automatic Scheduler mutation, live failure drill, GKE, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
