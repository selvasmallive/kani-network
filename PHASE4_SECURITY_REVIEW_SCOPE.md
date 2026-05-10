# KANI Phase 4 Security Review Scope

Status: security scope ready
Release candidate: `phase4-security-review-scope-rc1`
Date: 2026-05-10

This checkpoint defines the security architecture review and penetration-test scope for the Phase 4 no-GKE pre-production readiness track. It does not run a penetration test, does not authorize testing against production systems, does not create Google Cloud resources, and does not enable real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

## Review Objectives

Security review must determine whether the sandbox architecture is ready for later pre-production implementation planning. It does not approve production launch.

Required objectives:

- Confirm sandbox runtime flags prevent real-value use.
- Review institutional API authorization and admin authorization.
- Review account ownership, suspended-institution blocking, and manual-review payment flow.
- Review Cloud Run IAM, Secret Manager access, Cloud SQL access, and budget guardrails.
- Review audit-event coverage for authorization, compliance, ledger, validator, and reporting decisions.
- Review ISO 20022 XML parsing boundary and request-validation controls.
- Review validator job execution, scheduler controls, and no-GKE validator limitations.
- Review crypto-agility and signing-service boundaries.
- Review production ingress and HSM/KMS plans as deferred design only.
- Confirm GKE validator operations remain deferred to `phase5b-gke-validator-ops`.

## In-Scope Assets

Review scope includes:

- `kani-api` institution and admin endpoints.
- `kani-node` validator sweep behavior.
- Ledger accounting invariants and PostgreSQL persistence.
- Compliance decisions and manual-review cases.
- ISO 20022 `pacs.008`, `pacs.002`, and `camt.053` handlers.
- Sandbox API key handling and Secret Manager wiring.
- Cloud Run IAM assumptions and no-public-invoker controls.
- Cloud SQL connectivity, backup, PITR, and restore evidence.
- Cloud Monitoring alert and budget guardrail wiring.
- Terraform design boundaries for production ingress and key management.
- Operational runbooks, incident response, and evidence packs.

## Out-Of-Scope Until Explicit Approval

The following are out of scope for this checkpoint:

- Testing against production resources.
- Testing against external customer or institution systems.
- Social engineering.
- Denial-of-service or stress testing against Google Cloud services.
- Real money, fiat, custody, redemption, or trading flows.
- Bypassing Google Cloud account controls.
- GKE validator cluster testing.
- HSM/KMS production key operations.
- Production mTLS trust-chain testing.
- Public internet exposure testing.

## Threat Areas

Required threat areas:

- Broken object-level authorization between institutions.
- Admin privilege escalation.
- API key leakage, replay, or audit exposure.
- Payment idempotency abuse.
- Ledger integrity violations, double spending, and negative balances.
- Manual-review bypass for held or rejected payments.
- Validator duplicate finalization or stale block finality.
- ISO 20022 XML parser abuse, oversized payloads, and malformed input.
- Cloud SQL credential exposure and connection-string leakage.
- Inadequate audit logging or mutable evidence.
- Misconfigured Cloud Run invoker permissions.
- Secret Manager over-permissioning.
- Monitoring, alerting, and budget guardrail blind spots.
- Terraform drift or accidental paid-resource enablement.

## Test Evidence Requirements

Every reviewed control must produce evidence:

- Control id.
- Test owner.
- Test date.
- Environment and project id.
- Commit and image digest when applicable.
- Request or command summary.
- Expected result.
- Actual result.
- Pass/fail status.
- Evidence link or artifact path.
- Residual risk note.
- Follow-up owner and due date.

No sensitive secrets, API keys, private keys, bearer tokens, or raw credentials may be stored in evidence.

## Required Review Workstreams

Workstreams:

- `api_authorization_review`
- `ledger_integrity_review`
- `compliance_workflow_review`
- `validator_operations_review`
- `iso20022_input_review`
- `secret_management_review`
- `cloud_iam_review`
- `database_security_review`
- `audit_reporting_review`
- `monitoring_budget_guardrail_review`
- `terraform_change_control_review`
- `incident_response_review`
- `deferred_gke_hsm_ingress_review`

Each workstream starts as `blocked` until an owner, reviewer, evidence link, and closure decision are recorded.

## Non-Enablement

This checkpoint keeps the following disabled:

- Penetration test execution.
- Production target testing.
- External institution testing.
- GKE cluster creation.
- HSM/KMS production signing.
- Production ingress apply.
- Public endpoint exposure.
- Real-value settlement.
- Terraform apply.

## Acceptance Criteria

This checkpoint is accepted when:

- Security review scope document is checked in.
- Structured security review config exists.
- Static security review validator passes.
- Phase 4 validator includes the security review checkpoint.
- Phase 3 and Phase 2 validators still pass.
- No Google Cloud resources are created or changed.
- No GKE, HSM/KMS signing, production ingress, public exposure, penetration-test execution, external institution testing, or real-value capability is enabled.
