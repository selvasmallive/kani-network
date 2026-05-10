# KANI Phase 4 HSM/KMS Implementation Plan

Status: implementation plan ready
Release candidate: `phase4-hsm-kms-implementation-plan-rc1`
Date: 2026-05-10

This checkpoint defines the implementation plan for future managed signing with Cloud KMS/HSM patterns. It does not create key rings, keys, HSM resources, signing services, Google Cloud resources, or production signing capability.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

## Implementation Objective

The goal is to prepare a controlled path from profile-driven sandbox crypto to managed custody signing. The implementation must preserve ledger replay, validator determinism, auditability, and crypto agility.

This plan is not an approval to enable production signing.

## Target Signing Purposes

Future managed signing must be purpose-scoped:

- `validator_block_signing`
- `treasury_asset_authority`
- `api_request_signing`
- `audit_log_signing`
- `iso20022_message_signing`

Each purpose must define custody target, key algorithm, crypto profile, allowed callers, signing request schema, audit event type, rotation cadence, revocation path, and break-glass procedure.

## Implementation Stages

Recommended stages:

1. `stage_0_design_only`: keep Terraform design-only and no resource creation.
2. `stage_1_local_signing_adapter`: introduce signing-service interface while retaining sandbox local signing.
3. `stage_2_kms_mock_adapter`: test KMS-shaped requests with deterministic mock responses.
4. `stage_3_sandbox_kms_apply_candidate`: prepare Terraform resources behind a disabled apply gate.
5. `stage_4_sandbox_kms_pilot`: apply only after cost, security, operations, and Terraform review gates pass.
6. `stage_5_hsm_candidate`: evaluate HSM-backed key purposes after sandbox KMS evidence exists.
7. `stage_6_production_candidate`: blocked until legal, regulatory, security, operations, and executive readiness gates are approved.

Only stages 0 through 2 are appropriate before any paid-resource approval.

## Signing Request Contract

Every signing request must include:

- `request_id`
- `key_purpose`
- `crypto_profile`
- `payload_hash`
- `payload_type`
- `caller_principal`
- `institution_id`
- `approval_reference`
- `idempotency_key`
- `created_at`

The signing service must return:

- `request_id`
- `key_purpose`
- `key_version`
- `crypto_profile`
- `signature`
- `signature_algorithm`
- `signed_at`
- `audit_event_id`

Raw private keys must never leave managed custody once KMS/HSM is enabled.

## Key Lifecycle

Allowed future key states:

- `pending`
- `active`
- `retiring`
- `retired`
- `compromised`
- `revoked`

State transitions must be audit logged and dual-control approved for treasury, validator, audit, and ISO 20022 signing purposes.

## Required Gates Before Apply

Before any KMS/HSM Terraform apply:

- Cost estimate reviewed and approved.
- Security architecture review completed.
- Terraform plan reviewed.
- Dual-control approvers assigned.
- Key ceremony runbook approved.
- Break-glass revocation path approved.
- Signing service threat model reviewed.
- Audit event schema approved.
- Backup/recovery and ledger replay impact reviewed.
- Regulatory readiness remains non-overridden.

No gate can authorize real-value movement by itself.

## Terraform Boundary

`infra/terraform/phase4_hsm_kms_implementation_plan.tf` is design-only.

It must:

- Keep `phase4_hsm_kms_implementation_enabled = false`.
- Declare no `resource "google_*"` blocks.
- Produce only planning outputs.
- Keep all KMS/HSM apply actions deferred.
- Keep production signing disabled.

## Non-Enablement

This checkpoint keeps the following disabled:

- KMS key-ring creation.
- KMS crypto-key creation.
- HSM key creation.
- Signing service deployment.
- Validator KMS/HSM signing.
- Treasury KMS/HSM signing.
- Audit KMS/HSM signing.
- ISO 20022 KMS/HSM signing.
- Terraform apply.
- Google Cloud resource creation.
- Real-value settlement.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- HSM/KMS implementation plan is checked in.
- Structured HSM/KMS plan config exists.
- Design-only Terraform guard file exists.
- Static HSM/KMS plan validator passes.
- Phase 4 validator includes the HSM/KMS checkpoint.
- Phase 3 and Phase 2 validators still pass.
- Terraform validation passes.
- No Google Cloud resources are created or changed.
- No KMS/HSM resources, signing services, GKE, production ingress, or real-value capability are enabled.
