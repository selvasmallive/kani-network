# KANI Phase 5A Validator Reconciliation Evidence

Status: validator reconciliation checkpoint ready
Release candidate: `phase5a-validator-reconciliation-rc1`
Date: 2026-05-10

This checkpoint turns the first Phase 5A workstream, `validator_reconciliation_tests`, into a concrete evidence contract for the no-GKE validator model. It defines what operators must collect and prove after Cloud Run Job plus Cloud Scheduler validator sweeps.

This is still sandbox-only. It does not create Google Cloud resources, apply Terraform, change Cloud Scheduler, run live failure drills, enable GKE, enable production BFT networking, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase5a-validator-hardening-plan-rc1`.

## Reconciliation Objective

Validator reconciliation must prove that a sandbox settlement run is internally consistent after validator finality:

- Pending transactions drain to zero after validator sweeps.
- Fresh test asset issued supply matches the sum of the reconciled sandbox balances for the evidence run.
- Finalized blocks include the expected transactions.
- Finalized blocks have at least 2 of 3 finality votes from `validator-a`, `validator-b`, and `validator-c`.
- Validator reports show Phase 1 PoA finality with required finality votes of 2.
- Settlement reports agree with the mint and transfer evidence.
- Audit events show authorization, compliance, transaction, and block evidence.
- ISO 20022 `camt.053` statement entries agree with journal debits and credits for the reconciled asset.

## Evidence Sources

The reconciliation evidence pack must include responses from these sandbox APIs:

- `GET /health`
- `GET /v1/transactions/pending?limit=500&offset=0`
- `GET /v1/assets/{asset}/issued`
- `GET /v1/accounts/CORP_A/balances/{asset}`
- `GET /v1/accounts/CORP_B/balances/{asset}`
- `GET /v1/blocks/latest`
- `GET /v1/blocks?limit=500&offset=0`
- `GET /v1/audit-events?limit=500&offset=0`
- `GET /v1/reports/settlement-summary?limit=500&offset=0`
- `GET /v1/reports/compliance-decisions?limit=500&offset=0`
- `GET /v1/reports/validator-finality?limit=500&offset=0`
- `GET /v1/validators`
- `GET /v1/iso20022/camt053/accounts/CORP_A?asset={asset}&limit=500&offset=0`

## Required Reconciliation Checks

The evidence pack must record these checks:

1. `pending_transactions_zero_after_sweep`
2. `issued_supply_matches_reconciled_balances`
3. `latest_block_finality_votes_at_least_two`
4. `latest_block_validator_in_validator_set`
5. `validator_report_required_finality_votes_equals_two`
6. `validator_report_active_validator_count_equals_three`
7. `settlement_report_minted_amount_matches_issued_supply`
8. `settlement_report_transfer_amount_matches_payments`
9. `audit_events_include_authorization_and_finalization`
10. `camt053_entries_match_journal_debits_and_credits`

## Evidence Pack Schema

Each run must be saved as an evidence pack with these fields:

- `run_id`
- `environment`
- `operator`
- `started_at`
- `completed_at`
- `base_url`
- `asset`
- `validator_runtime`
- `validator_ids`
- `scheduler_cadence`
- `mint_transaction_id`
- `payment_transaction_id`
- `iso_transaction_id`
- `latest_block_height`
- `latest_block_hash`
- `latest_block_validator`
- `latest_block_finalized_by`
- `pending_count`
- `issued_supply`
- `corp_a_balance`
- `corp_b_balance`
- `settlement_report_snapshot`
- `compliance_report_snapshot`
- `validator_finality_report_snapshot`
- `validator_state_snapshot`
- `audit_event_snapshot`
- `camt053_statement_snapshot`
- `reconciliation_results`

The evidence pack must not include API keys, bearer tokens, Secret Manager values, raw private keys, customer data, or real-value records.

## Operator Procedure

The no-GKE reconciliation procedure is:

1. Confirm the sandbox boundary is active.
2. Run the sandbox payment and ISO 20022 flow against a fresh `KCAD_TEST_*` or `KUSD_TEST_*` asset.
3. Execute or wait for the Cloud Run Job validator sweep.
4. Collect every evidence source listed above.
5. Verify all required reconciliation checks.
6. Save the evidence pack to the operator evidence location.
7. Record failures as sandbox incidents and keep the validator Scheduler unchanged unless a separate approved change window exists.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE cluster creation.
- Terraform apply.
- Google Cloud resource creation or mutation.
- Cloud Scheduler mutation.
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

- Validator reconciliation evidence document is checked in.
- Structured reconciliation config exists.
- Static validator reconciliation script passes.
- Aggregate Phase 5A validator includes reconciliation.
- Phase 5A hardening plan validator still passes.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No GKE, Scheduler mutation, live failure drill, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
