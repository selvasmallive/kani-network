# KANI Phase 4 Legal and Compliance Evidence Register

Status: evidence register ready
Release candidate: `phase4-legal-compliance-evidence-rc1`
Date: 2026-05-10

This checkpoint defines the evidence register for future legal, compliance, privacy, security, operations, finance, and executive review. It is not legal advice, does not complete any legal determination, does not approve production, and does not authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

## Evidence Objective

The goal is to make every production-readiness question auditable before any production-style change is considered. Each evidence item must have an owner, reviewer role, evidence location, review status, approval date, expiry date where applicable, and residual-risk decision.

This register does not replace qualified external legal, compliance, privacy, security, tax, or financial advice.

## Required Evidence Gates

Every evidence gate starts as `blocked` and must stay blocked until the required reviewer approves complete evidence:

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

No gate can authorize real-value movement by itself.

## Evidence Fields

Each register item must include:

- `gate_id`
- `owner`
- `required_reviewer`
- `evidence_required`
- `evidence_location`
- `approval_status`
- `approval_date`
- `expiry_or_review_date`
- `residual_risk`
- `notes`

The checked-in default for owner, evidence location, approval date, expiry date, and residual risk is intentionally unassigned or pending.

## Reviewer Requirements

Required reviewer roles:

- `qualified_external_legal_counsel`
- `compliance_officer`
- `privacy_officer`
- `security_lead`
- `independent_security_reviewer`
- `finance_reviewer`
- `operations_lead`
- `executive_approver`

Production approval requires named human reviewers and evidence links. Role names alone are not approval.

## Production Blockers

The following remain blocked:

- Legal classification.
- Registration or MSB analysis.
- AML/KYC program approval.
- Sanctions screening approval.
- Privacy and retention approval.
- Custody and safeguarding approval.
- Institution agreement approval.
- Penetration-test completion.
- Production cost approval.
- Terraform plan approval.
- Executive go-live approval.

## Non-Enablement

This checkpoint keeps the following disabled:

- Legal advice provided by the system.
- Legal classification approval.
- Registration approval.
- AML/KYC program approval.
- Sanctions screening approval.
- Privacy review approval.
- Custody safeguarding approval.
- Institution agreement approval.
- External institution onboarding.
- Production authorization.
- Real-value settlement.
- Fiat deposit or redemption.
- Custody for others.
- Trading.
- Terraform apply.
- Google Cloud resource creation.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- Legal/compliance evidence register is checked in.
- Structured evidence config exists.
- Static legal/compliance evidence validator passes.
- Phase 4 validator includes the legal/compliance evidence checkpoint.
- Phase 3 and Phase 2 validators still pass.
- No Google Cloud resources are created or changed.
- No legal approval, compliance approval, external institution onboarding, production authorization, production go-live, or real-value capability is enabled.
