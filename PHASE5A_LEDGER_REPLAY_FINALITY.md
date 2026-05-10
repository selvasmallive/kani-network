# KANI Phase 5A Ledger Replay And Finality Verification

Status: ledger replay and finality checkpoint ready
Release candidate: `phase5a-ledger-replay-finality-rc1`
Date: 2026-05-10

This checkpoint turns the Phase 5A workstream `ledger_replay_and_finality_verification` into a sandbox evidence contract. It defines how operators verify finalized blocks, replay ledger effects, and prove Phase 1 PoA finality without enabling GKE or live production validator operations.

This is a planning and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, change Cloud Scheduler, execute validator jobs, inject failures, run live drills, enable GKE, enable production BFT networking, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase5a-failure-retry-drills-rc1`.

## Verification Objective

Ledger replay and finality verification must prove that finalized settlement evidence is internally consistent:

- Finalized block heights are monotonic.
- Every finalized block links to the expected previous hash.
- Every finalized block hash is stable for the collected evidence.
- Every block validator is inside `validator-a`, `validator-b`, and `validator-c`.
- Every finalized block has at least 2 of 3 finality votes.
- Mint, burn, transfer, journal, balance, and issued-supply effects can be replayed.
- Replayed balances match API balances for the test asset.
- Replayed issued supply matches `/v1/assets/{asset}/issued`.
- Settlement reports match replayed mint and transfer totals.
- Audit evidence contains block finalization and transaction evidence.

## Replay Inputs

The replay evidence pack must include:

- `GET /v1/blocks?limit=500&offset=0`
- `GET /v1/blocks/latest`
- `GET /v1/transactions/{id}` for sampled finalized transactions
- `GET /v1/assets/{asset}/issued`
- `GET /v1/accounts/CORP_A/balances/{asset}`
- `GET /v1/accounts/CORP_B/balances/{asset}`
- `GET /v1/audit-events?limit=500&offset=0`
- `GET /v1/reports/settlement-summary?limit=500&offset=0`
- `GET /v1/reports/validator-finality?limit=500&offset=0`
- `GET /v1/validators`
- `GET /v1/iso20022/camt053/accounts/CORP_A?asset={asset}&limit=500&offset=0`

## Replay Procedure

The no-GKE replay procedure is:

1. Select a fresh sandbox evidence asset such as `KCAD_TEST_*`.
2. Collect all replay inputs.
3. Sort finalized blocks by height.
4. Verify the genesis or first collected `prev_hash` boundary is documented.
5. Verify every following block references the previous collected block hash.
6. Verify block hash stability against the collected block payload.
7. Verify each block validator belongs to the configured validator set.
8. Verify each block has at least 2 finality votes from the configured validator set.
9. Replay mint, burn, and transfer effects for the selected asset.
10. Reconcile replayed balances, issued supply, settlement reports, audit evidence, and `camt.053` journal entries.

## Required Replay Checks

The evidence pack must record these checks:

1. `block_heights_are_monotonic`
2. `block_prev_hash_chain_is_contiguous`
3. `block_hashes_are_stable`
4. `block_validators_are_in_validator_set`
5. `finality_votes_are_at_least_two_of_three`
6. `finality_votes_are_in_validator_set`
7. `replayed_balances_match_account_balances`
8. `replayed_issued_supply_matches_asset_supply`
9. `settlement_report_matches_replayed_totals`
10. `audit_events_include_block_and_transaction_evidence`
11. `camt053_entries_match_replayed_journal_entries`
12. `pending_transactions_zero_or_explained`

## Replay Evidence Pack Schema

Each run must be saved as an evidence pack with these fields:

- `run_id`
- `operator`
- `environment`
- `asset`
- `started_at`
- `completed_at`
- `block_page_snapshot`
- `latest_block_snapshot`
- `sampled_transaction_snapshots`
- `validator_set`
- `validator_finality_report_snapshot`
- `validator_state_snapshot`
- `issued_supply_snapshot`
- `account_balance_snapshots`
- `settlement_report_snapshot`
- `audit_event_snapshot`
- `camt053_statement_snapshot`
- `replayed_balance_result`
- `replayed_supply_result`
- `finality_verification_result`
- `hash_chain_verification_result`
- `replay_discrepancies`
- `operator_conclusion`

The evidence pack must not include API keys, bearer tokens, Secret Manager values, raw private keys, customer data, or real-value records.

## Non-Enablement

This checkpoint keeps the following disabled:

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

- Ledger replay and finality verification document is checked in.
- Structured ledger replay and finality config exists.
- Static ledger replay and finality validator passes.
- Aggregate Phase 5A validator includes ledger replay and finality verification.
- Phase 5A failure/retry, scheduler, reconciliation, and hardening plan validators still pass.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No production replay, failure injection, live drill execution, Scheduler mutation, GKE, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
