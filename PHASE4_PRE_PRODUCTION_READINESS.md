# KANI Phase 4 Pre-Production Readiness

Status: readiness planning started
Release candidate: `phase4-pre-production-readiness-rc1`
Date: 2026-05-10

Phase 4 prepares the project for a future production-readiness decision. It does not deploy production infrastructure, does not enable GKE, does not enable HSM/KMS production signing, and does not authorize real-value settlement.

## Runtime Boundary

Phase 4 starts from the same sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

No production deployment, customer onboarding, fiat deposit, redemption, custody, trading, external institution access, or regulated payment service is authorized by this phase.

## No-GKE Decision

The active Phase 4 track is `phase4-no-gke-preprod-readiness`.

GKE remains deferred until a later validator-operations checkpoint, currently planned as `phase5b-gke-validator-ops`. Phase 4 keeps the current `phase2-lean-no-gke` runtime baseline:

- Cloud Run for `kani-api`.
- Cloud Run Job plus Cloud Scheduler for validator sweeps.
- Cloud SQL PostgreSQL for ledger state.
- Secret Manager for sandbox credentials.
- Cloud Monitoring and budget guardrails.
- No GKE cluster creation.
- No Kubernetes validator runtime promotion.

## Phase 4 Objectives

1. Convert Phase 3 design boundaries into explicit pre-production gates.
2. Assign owners and required evidence for legal, compliance, security, operations, finance, and executive approval.
3. Define paid-resource cost gates before any Terraform apply.
4. Keep GKE, production ingress, and HSM/KMS production signing as deferred implementation decisions.
5. Prepare security review and penetration-test scope.
6. Prepare disaster recovery targets without changing the active sandbox ledger.
7. Build a Phase 5 split: no-GKE validator hardening first, GKE validator operations later.

## Readiness Gates

Every gate must have an owner, reviewer, evidence link, target date, approval date, and status before production enablement can be considered.

Required gates:

- `legal_classification_review`
- `registration_and_msb_analysis`
- `aml_kyc_program_review`
- `sanctions_screening_review`
- `privacy_and_data_retention_review`
- `custody_and_safeguarding_review`
- `institution_agreement_review`
- `security_architecture_review`
- `penetration_test_scope`
- `incident_response_and_dr_review`
- `production_cost_estimate_review`
- `terraform_plan_review`
- `executive_go_live_approval`

All gates start as `blocked`.

## Cost Gate

Phase 4 must not create paid production-style resources until a cost estimate is reviewed and accepted.

Cost estimate must include:

- Existing Cloud Run API and validator job baseline.
- Existing Cloud SQL instance and backups.
- Artifact Registry storage.
- Secret Manager versions.
- Cloud Monitoring, Logging, alerting, and budget notifications.
- Future production ingress resources.
- Future HSM/KMS signing resources.
- Future GKE validator operations as a separate estimate.
- Network egress, Cloud NAT, load balancer, and static IP assumptions when applicable.

The GKE estimate remains separate so the current no-GKE path can continue without pulling validator-cluster cost into Phase 4.

## Phase 5 Split

Phase 4 records the next implementation split:

- `phase5a-no-gke-validator-hardening`: stronger validator tests, reconciliation, failure drills, observability, and Cloud Run Job runbooks.
- `phase5b-gke-validator-ops`: GKE cluster, long-running validator pods, pod-to-pod networking, BFT transport, node isolation, and Kubernetes observability.

This keeps Phase 5A available without GKE and reserves GKE for the moment when real validator operations are worth the added cost.

## Non-Enablement

This checkpoint explicitly keeps the following disabled:

- GKE cluster creation.
- Production BFT validator network.
- Production ingress.
- Cloud Armor WAF apply.
- mTLS trust config apply.
- HSM/KMS production signing.
- External institution onboarding.
- Real-value settlement.
- Fiat deposit or redemption.
- Custody for others.
- Trading.
- Production go-live.

## Acceptance Criteria

This Phase 4 checkpoint is accepted when:

- Phase 4 readiness plan is checked in.
- Structured Phase 4 config exists.
- Static Phase 4 validator passes.
- Phase 3 and Phase 2 validators still pass.
- No Google Cloud resources are created.
- No paid production-style resources are enabled.
- No GKE, HSM/KMS production signing, production ingress, or real-value capability is enabled.

## Next Checkpoints

Recommended Phase 4 slices:

1. `phase4-pre-production-readiness-rc1`: no-GKE readiness gates, cost gate, and Phase 5 split.
2. `phase4-cost-model-rc1`: production and GKE cost estimate inputs, still no Terraform apply.
3. `phase4-security-review-scope-rc1`: security architecture and penetration-test scope.
4. `phase4-hsm-kms-implementation-plan-rc1`: implementation plan and Terraform design guard for signing resources.
5. `phase4-prod-ingress-implementation-plan-rc1`: implementation plan and Terraform design guard for ingress resources.
6. `phase4-dr-readiness-rc1`: backup, restore, RTO/RPO, and evidence drills.
7. `phase4-legal-compliance-evidence-rc1`: evidence register for external legal/compliance review.

Phase 4 remains planning and readiness until every gate has reviewed evidence.

## Implementation Progress

`phase4-cost-model-rc1` adds cost-estimate input structure for the current no-GKE baseline, deferred production ingress, deferred HSM/KMS signing, deferred GKE validator operations, disaster recovery, and security review. It records no fixed live prices, creates no Google Cloud resources, and keeps GKE deferred to `phase5b-gke-validator-ops`. Details are recorded in `PHASE4_COST_MODEL.md`.

`phase4-security-review-scope-rc1` defines the security architecture review and penetration-test scope for the no-GKE readiness track. It identifies in-scope assets, out-of-scope test classes, threat areas, evidence requirements, and blocked review workstreams without running a penetration test or changing infrastructure. Details are recorded in `PHASE4_SECURITY_REVIEW_SCOPE.md`.

`phase4-hsm-kms-implementation-plan-rc1` defines the future managed signing path for Cloud KMS/HSM custody, signing purposes, staged adapters, signing request contracts, key lifecycle, required apply gates, and a design-only Terraform guard. It creates no KMS/HSM resources, deploys no signing service, and enables no production signing. Details are recorded in `PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md`.
