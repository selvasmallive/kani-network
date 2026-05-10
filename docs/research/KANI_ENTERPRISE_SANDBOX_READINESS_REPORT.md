# KANI Enterprise Sandbox Readiness Report

Release candidate: `enterprise-sandbox-evidence-pack-rc1`

Status: `sandbox_enterprise_readiness_evidence_pack_ready`

Captured from implemented sandbox evidence through: `2026-05-10`

## Executive Finding

The KANI sandbox is implemented as an end-to-end settlement MVP and has enough evidence to support an enterprise sandbox review. It should be described as:

```text
Enterprise-ready sandbox evidence pack: ready for review
Production-ready settlement network: not yet
Real-value settlement: disabled
```

The sandbox proves that a payment can be accepted, screened, recorded, finalized by permissioned validators, audited, reported, and observed in Google Cloud. The current evidence also proves that the live GKE validator path can finalize transactions while the legacy Scheduler validator path remains paused.

## Implemented Sandbox Capabilities

| Capability | Status | Evidence |
|---|---:|---|
| Rust workspace and modular crates | Implemented | `README.md`, `crates/` |
| Ledger accounts, balances, journal, blocks | Implemented | `crates/kani-ledger`, migrations |
| Test asset mint and transfer | Implemented | cloud smoke test |
| No-negative-balance enforcement | Implemented | local and cloud smoke tests |
| Permissioned PoA validators | Implemented | validator reports, GKE pods |
| 2-of-3 finality metadata | Implemented | latest block finality evidence |
| ISO 20022 sandbox flow | Implemented | `pacs.008`, `pacs.002`, `camt.053` endpoints |
| Sandbox compliance profile | Implemented | compliance decisions and blocked self-transfer |
| Audit and reporting endpoints | Implemented | settlement, compliance, validator-finality reports |
| Cloud Run API | Implemented | `kani-sandbox-api` ready revision |
| Cloud SQL PostgreSQL | Implemented | `kani-sandbox-ledger` RUNNABLE |
| GKE validator pilot | Implemented | `validator-a/b/c` pods running |
| Budget guardrail | Implemented | CAD 200 monthly alert guardrail |
| Patent/research documentation | Implemented | `docs/patent/` |

## Day-Zero Proof Snapshot

The day-zero observation checkpoint captured the following live sandbox proof:

```text
observation_window: 2026-05-10 through 2026-06-10
cloud_run_api: kani-sandbox-api
cloud_sql: kani-sandbox-ledger, POSTGRES_16, RUNNABLE
gke_cluster: kani-sandbox-validators, RUNNING
node_profile: 1 x e2-medium
validator_pods: 3 running, 0 restarts
legacy_scheduler: PAUSED
budget_guardrail: CAD 200
```

The cloud smoke test result was:

```text
profile: phase5b-gke-continuous-validators
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
status: ok
```

## Enterprise Sandbox Readiness Assessment

The sandbox is ready for enterprise-style review across the following domains:

1. Functional settlement proof.
2. Ledger consistency proof.
3. Validator finality proof.
4. ISO/payment-message compatibility proof.
5. Compliance-decision proof.
6. Audit/reporting proof.
7. Cloud deployment proof.
8. Secret-management proof.
9. Budget/monitoring proof.
10. Sandbox boundary proof.

The main remaining enterprise-hardening work is operational evidence depth, not core MVP capability. The next hardening steps are:

```text
1. Complete the one-month GKE observation window.
2. Capture first actual billing review after cloud billing data catches up.
3. Run a controlled validator restart/failure drill.
4. Run a backup/restore or restore-to-separate-target drill.
5. Add a recurring observation report for runtime, billing, finality, and logs.
6. Add evidence signoff fields for operator and reviewer.
7. Add a formal security review and remediation register.
8. Keep production and real-value gates blocked.
```

## Control-Domain Summary

| Domain | Enterprise sandbox status | Next hardening action |
|---|---:|---|
| Sandbox legal boundary | Ready | Add counsel-reviewed filing/status notes |
| Ledger integrity | Ready | Add replay drill evidence |
| Validator operations | Ready for observation | Add restart/failure drill |
| Cloud runtime | Ready for observation | Add weekly run report |
| Security controls | Partially ready | Add formal review and penetration-test scope |
| Recovery controls | Partially ready | Execute restore drill |
| Key management | Design-only | Do not enable HSM/KMS until approved |
| Production ingress | Design-only | Keep blocked |
| Real-value settlement | Blocked | Requires legal, compliance, and executive approvals |

## Research And Presentation File Map

The PowerPoint and research data set use these files:

```text
docs/research/KANI_ENTERPRISE_SANDBOX_READINESS_REPORT.md
docs/research/data/enterprise_readiness_controls.csv
docs/research/data/enterprise_readiness_metrics.csv
docs/research/data/enterprise_evidence_index.csv
docs/research/data/enterprise_readiness_summary.yaml
docs/presentations/kani_enterprise_sandbox_proof_deck.pptx
```

## Non-Claims

This report does not claim:

- Production readiness.
- Regulatory approval.
- FINTRAC, MSB, AML/KYC, or money transmission authorization.
- Real-value asset issuance.
- Fiat deposit or redemption.
- Customer custody.
- External institution onboarding.
- HSM-backed production signing.
- Production mTLS ingress.

## Recommended Presentation Positioning

Use this framing in presentations:

```text
KANI has an implemented, observable sandbox MVP.
The sandbox proves the settlement lifecycle end to end.
Enterprise readiness work is now about evidence depth, drills, controls, and approvals.
Production and real-value settlement remain deliberately blocked.
```

