# KANI Phase 3 Key Management Design

Status: design slice ready
Release candidate: `phase3-key-management-design-rc1`
Date: 2026-05-09
Scope: KMS/HSM key inventory, signing boundaries, rotation, revocation, and ceremony runbooks

This slice keeps the sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

It does not create KMS, HSM, or signing-service resources. It does not enable production signing, treasury custody, real money movement, fiat redemption, custody for others, trading, or GKE validator operations.

## Terraform Boundary

The Terraform scaffold is checked in at:

```text
infra/terraform/phase3_key_management_design.tf
```

It is intentionally design-only. `phase3_key_management_design_enabled` defaults to `false` and cannot be turned on in this slice. The file emits design outputs only; it does not declare Google Cloud resources.

## Key Inventory

The target key inventory is purpose-scoped:

- `validator_block_signing`: validator block and consensus signatures.
- `treasury_asset_authority`: sandbox mint, burn, and future tokenized fiat authority.
- `api_request_signing`: institution/API message signing and non-repudiation.
- `audit_log_signing`: immutable audit envelope signing.
- `iso20022_message_signing`: future ISO 20022 message authenticity.

Each key must track purpose, algorithm profile, active key version, status, owner, dual-control requirement, rotation cadence, and emergency revocation path.

## Signing Boundary

Private keys must not leave managed custody. Production signing should happen through a signing-service boundary that:

- receives a canonical signing request
- verifies purpose, caller, institution, key status, and crypto profile
- calls Cloud KMS or Cloud HSM
- returns the signature and key version
- writes an audit event for every approved or rejected signing attempt

Crypto profiles remain config-driven. Hybrid/PQC profile placeholders stay in configuration until supported by a reviewed key backend.

## Lifecycle States

Required key states:

- `pending`
- `active`
- `retiring`
- `retired`
- `compromised`
- `revoked`

Rotation must support overlap between active and pending keys so ledger replay can verify historic signatures by key version.

## Dual-Control Ceremony

Before production key activation:

- two approved operators must authorize key creation
- key purpose and crypto profile must be recorded
- activation must require separate approval from creation
- emergency revocation must have an explicit break-glass path
- ceremony evidence must be linked to audit records

## Deferred

- creating Cloud KMS key rings or keys
- creating Cloud HSM resources
- implementing a production signing service
- enabling validator HSM signing
- enabling treasury custody signing
- enabling PQC-backed production signatures
- changing sandbox validator signatures
- enabling real-value settlement

Current validator behavior remains Phase 1 PoA.

## Acceptance Evidence

The slice is accepted when these checks pass:

```powershell
terraform fmt -check
terraform validate
cargo fmt --check
cargo clippy --workspace -- -D warnings
cargo test --workspace -j 1
powershell -ExecutionPolicy Bypass -File .\scripts\phase3-validate.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\phase2-validate.ps1
```
