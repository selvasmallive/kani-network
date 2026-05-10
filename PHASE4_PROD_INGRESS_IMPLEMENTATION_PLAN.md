# KANI Phase 4 Production Ingress Implementation Plan

Status: implementation plan ready
Release candidate: `phase4-prod-ingress-implementation-plan-rc1`
Date: 2026-05-10

This checkpoint defines the implementation plan for a future production-grade ingress path. It does not create load balancers, API Gateway resources, certificates, trust configs, DNS records, Cloud Armor policies, Google Cloud resources, or public endpoint exposure.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

## Implementation Objective

The goal is to prepare a controlled path from the current lean Cloud Run sandbox to a production edge with authenticated institution access, admin isolation, audited request paths, and explicit rollback controls.

This plan is not an approval to enable production ingress.

## Target Components

Future production ingress must be assembled from reviewed components:

- `external_https_load_balancer_or_api_gateway_decision`
- `serverless_neg_to_cloud_run_api`
- `certificate_manager_tls_certificate`
- `certificate_manager_trust_config`
- `private_ca_or_institution_trust_bundle`
- `institution_mtls`
- `cloud_armor_waf`
- `cloud_armor_rate_limits`
- `admin_oidc`
- `private_cloud_run_ingress`
- `private_api_to_database_path`
- `managed_dns_record`
- `reserved_static_ip`
- `request_and_security_logging`

The implementation choice between external HTTPS load balancer and API Gateway must be documented before any Terraform apply.

## Request Paths

Future ingress must keep request classes separate:

- `institution_api_path`: mTLS institution traffic to settlement and ISO 20022 APIs.
- `admin_api_path`: OIDC-protected operator traffic to admin, reporting, and review APIs.
- `validator_internal_path`: internal-only validator and job traffic, not exposed through the public edge.
- `health_path`: minimal health checks with no ledger, account, secret, or institution data.

Every path must define allowed methods, authentication boundary, rate limits, audit event expectations, and rollback behavior.

## Implementation Stages

Recommended stages:

1. `stage_0_design_only`: keep Terraform design-only and no resource creation.
2. `stage_1_domain_and_cert_design`: document DNS owner, certificate type, renewal path, and validation method.
3. `stage_2_waf_policy_design`: define Cloud Armor rules, rate limits, deny lists, logging, and false-positive review.
4. `stage_3_mtls_trust_design`: define institution certificate issuance, revocation, trust bundle, and rotation.
5. `stage_4_sandbox_edge_apply_candidate`: prepare Terraform resources behind a disabled apply gate.
6. `stage_5_preprod_edge_pilot`: apply only after cost, security, operations, DNS, certificate, and Terraform gates pass.
7. `stage_6_production_candidate`: blocked until legal, regulatory, security, penetration-test, operations, and executive readiness gates are approved.

Only stages 0 through 3 are appropriate before any paid-resource approval.

## Required Gates Before Apply

Before any production ingress Terraform apply:

- Cost estimate reviewed and approved.
- Security architecture review completed.
- Terraform plan reviewed.
- DNS owner approval recorded.
- Certificate and trust config owner assigned.
- Cloud Run ingress rollback plan approved.
- Cloud Armor policy reviewed.
- Admin OIDC review completed.
- Smoke and security test plan approved.
- Penetration test scope approved.
- Logging, retention, and incident response review completed.
- Regulatory readiness remains non-overridden.

No gate can authorize real-value movement by itself.

## Terraform Boundary

`infra/terraform/phase4_prod_ingress_implementation_plan.tf` is design-only.

It must:

- Keep `phase4_prod_ingress_implementation_enabled = false`.
- Declare no `resource "google_*"` blocks.
- Produce only planning outputs.
- Keep load balancer, API Gateway, DNS, certificate, trust config, mTLS, Cloud Armor, and Cloud Run ingress changes deferred.
- Keep public endpoint exposure disabled.

## IAM Boundary

Future public invocation must never use these principals:

- `allUsers`
- `allAuthenticatedUsers`

Institution access must be identity-bound and certificate-bound. Admin access must use OIDC and operator authorization. Validator traffic must remain internal.

## Non-Enablement

This checkpoint keeps the following disabled:

- External HTTPS load balancer creation.
- API Gateway creation.
- Reserved static IP creation.
- DNS record creation.
- Certificate Manager certificate creation.
- Certificate Manager trust config creation.
- Institution mTLS enforcement.
- Cloud Armor WAF apply.
- Cloud Armor rate-limit apply.
- Cloud Run ingress changes.
- Public endpoint exposure.
- Terraform apply.
- Google Cloud resource creation.
- Real-value settlement.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- Production ingress implementation plan is checked in.
- Structured production ingress plan config exists.
- Design-only Terraform guard file exists.
- Static production ingress plan validator passes.
- Phase 4 validator includes the production ingress checkpoint.
- Phase 3 and Phase 2 validators still pass.
- Terraform validation passes.
- No Google Cloud resources are created or changed.
- No load balancer, API Gateway, DNS, certificate, trust config, mTLS, Cloud Armor, Cloud Run ingress change, public endpoint exposure, GKE, HSM/KMS production signing, or real-value capability is enabled.
