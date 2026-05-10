# KANI Phase 5A Sandbox Smoke Coverage

Status: sandbox smoke coverage checkpoint ready
Release candidate: `phase5a-sandbox-smoke-coverage-rc1`
Date: 2026-05-10

This checkpoint turns the Phase 5A workstream `complete_sandbox_smoke_tests` into a standard coverage and evidence contract for the no-GKE validator hardening track. It defines the sandbox smoke controls, evidence sources, execution gates, expected outcomes, and operator evidence pack requirements for local and lean-cloud smoke tests.

This is a planning and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, execute cloud smoke tests, execute local smoke tests, change Cloud Scheduler, execute validator jobs, inject failures, run live recovery drills, enable GKE, enable production BFT networking, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

This checkpoint inherits from `phase5a-alert-response-recovery-rc1`.

## Coverage Objective

Sandbox smoke coverage must prove that the end-to-end MVP path still works before Phase 5A is wrapped up:

- API health responds successfully.
- Sandbox treasury mint creates test-only issued supply.
- A permitted `CORP_A` to `CORP_B` payment is accepted.
- Validator sweep finalizes pending ledger activity.
- Pending transactions are cleared or explicitly explained.
- PoA finality has at least 2 of 3 validator votes.
- Account balances reconcile to minted supply and transfers.
- ISO 20022 `pacs.008`, `pacs.002`, and `camt.053` paths match the ledger path.
- Compliance rejects a sandbox self-transfer and records the decision.
- Settlement, compliance, validator finality, and audit reports contain the expected evidence.
- The operator evidence pack records all smoke inputs, outputs, failures, and residual risk.

## Required Smoke Controls

Phase 5A requires smoke coverage for:

1. `runtime_health`
2. `sandbox_mint`
3. `payment_transfer`
4. `validator_sweep`
5. `pending_queue_clearance`
6. `poa_finality`
7. `balance_reconciliation`
8. `issued_supply_reconciliation`
9. `iso_pacs008_submission`
10. `iso_pacs002_status`
11. `iso_camt053_statement`
12. `compliance_self_transfer_rejection`
13. `settlement_reporting`
14. `compliance_reporting`
15. `validator_finality_reporting`
16. `audit_event_reporting`

## Evidence Sources

The operator must collect applicable evidence from:

- `scripts/smoke-test.ps1`
- `scripts/phase2-cloud-smoke.ps1`
- `scripts/phase2-security-smoke.ps1`
- `GET /health`
- `POST /v1/sandbox/mint`
- `POST /v1/payments`
- `POST /v1/iso20022/pacs008`
- `GET /v1/iso20022/pacs002/{payment_id}`
- `GET /v1/iso20022/camt053/accounts/CORP_A?asset={asset}&limit=20&offset=0`
- `GET /v1/transactions/pending?limit=100&offset=0`
- `GET /v1/blocks/latest`
- `GET /v1/accounts/CORP_A/balances/{asset}`
- `GET /v1/accounts/CORP_B/balances/{asset}`
- `GET /v1/assets/{asset}/issued`
- `GET /v1/reports/settlement-summary?limit=500&offset=0`
- `GET /v1/reports/compliance-decisions?limit=500&offset=0`
- `GET /v1/reports/validator-finality?limit=500&offset=0`
- `GET /v1/audit-events?limit=500&offset=0`
- Cloud Run service execution state when the cloud smoke test is approved.
- Cloud Run validator job execution state when the cloud smoke test is approved.
- Cloud Scheduler job state when the cloud smoke test is approved.
- Prior operator evidence pack.

## Execution Gates

Before any smoke execution is considered, these gates must be completed outside this checkpoint:

- `sandbox_only_purpose_recorded`
- `operator_assigned`
- `reviewer_assigned`
- `evidence_pack_location_selected`
- `base_url_confirmed`
- `sandbox_api_keys_confirmed_available`
- `test_asset_prefix_confirmed`
- `validator_run_mode_confirmed`
- `expected_balance_math_documented`
- `expected_iso_evidence_documented`
- `expected_report_evidence_documented`
- `no_real_value_capability_enabled`

All gates remain blocked by this checkpoint.

## Expected Outcomes

The smoke evidence pack must show:

- `/health` returns `ok`.
- A fresh `KCAD_TEST_*` or `KUSD_TEST_*` asset is used.
- Mint amount is `1000000` minor units.
- Direct payment amount is `100000` minor units.
- ISO payment amount is `25000` minor units.
- `CORP_A` final balance is `875000` minor units.
- `CORP_B` final balance is `125000` minor units.
- Pending transaction count is `0` or explicitly explained.
- Latest block finality includes at least two validators.
- Settlement report minted amount is `1000000` for the test asset.
- Settlement report transfer amount is `125000` for the test asset.
- Compliance report includes `NO_SELF_TRANSFER`.
- `pacs.002` reports `ACSC` for the ISO payment.
- `camt.053` includes debit and credit entries for the test asset.

## Non-Enablement

This checkpoint keeps the following disabled:

- Live sandbox smoke execution approval.
- Cloud smoke execution approval.
- Local smoke execution approval.
- Destructive smoke reset.
- External endpoint smoke outside the sandbox project.
- Cloud Scheduler mutation.
- Cloud Run Job execution approval.
- Secret rotation approval.
- Failure injection.
- Live recovery drills.
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

- Sandbox smoke coverage document is checked in.
- Structured sandbox smoke coverage config exists.
- Static sandbox smoke coverage validator passes.
- Aggregate Phase 5A validator includes sandbox smoke coverage.
- Phase 5A alert response, operator evidence pack, ledger replay, failure/retry, scheduler, reconciliation, and hardening plan validators still pass.
- Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No live sandbox smoke execution, cloud smoke execution approval, local smoke execution approval, Scheduler mutation, Cloud Run Job execution approval, secret rotation approval, failure injection, restore drill execution, production recovery, GKE, production BFT network, production ingress, HSM/KMS production signing, external institution onboarding, production authorization, or real-value capability is enabled.
