# KANI Phase 3 Production Edge Design

Status: design slice ready
Release candidate: `phase3-prod-edge-design-rc1`
Date: 2026-05-09
Scope: production ingress, mTLS, WAF, private Cloud Run ingress, and admin identity design

This slice keeps the sandbox boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

It does not create paid edge resources. It does not enable real money movement, public customer access, production payment services, fiat redemption, custody, trading, or GKE validator operations.

## Terraform Boundary

The Terraform scaffold is checked in at:

```text
infra/terraform/phase3_prod_edge_design.tf
```

It is intentionally design-only. `phase3_prod_edge_design_enabled` defaults to `false` and cannot be turned on in this slice. The file emits design outputs only; it does not declare Google Cloud resources.

## Target Edge Architecture

The production edge target is:

```text
Institution client
  -> External HTTPS load balancer or API Gateway
  -> Certificate Manager TLS certificate
  -> mTLS trust config for institution certificates
  -> Cloud Armor WAF and rate limiting
  -> Serverless NEG or API backend
  -> Cloud Run kani-api with internal/load-balancer ingress
  -> Cloud SQL through private or managed connector path
```

Admin users should use OIDC with explicit roles. Institution API access should be authorized by institution identity, credential status, certificate fingerprint, and application-level role checks.

## Controls

Required controls before any production edge apply:

- no `allUsers` or `allAuthenticatedUsers` Cloud Run invoker grant
- institution mTLS trust anchor inventory
- certificate fingerprint mapped to `InstitutionCredential`
- Cloud Armor WAF policy with rate limiting
- private Cloud Run ingress mode
- separate admin OIDC identity path
- explicit audit events for edge authorization decisions
- security review and penetration test before real-value activity

## Deferred

- creating external load balancer resources
- creating API Gateway resources
- creating Cloud Armor policies
- creating Certificate Manager certificates or trust configs
- changing live Cloud Run ingress
- enabling production mTLS
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
