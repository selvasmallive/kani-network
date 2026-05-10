# KANI Phase 4 Cost Model

Status: cost model ready
Release candidate: `phase4-cost-model-rc1`
Date: 2026-05-10

This checkpoint defines cost-estimate inputs and approval gates for the Phase 4 no-GKE pre-production readiness track. It does not create Google Cloud resources, does not apply Terraform, does not enable GKE, and does not authorize production or real-value activity.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

## Cost Model Principle

The repository records cost-estimate inputs, assumptions, and gates. It does not record fixed live prices because cloud pricing changes over time and must be checked in the Google Cloud Pricing Calculator or billing console before any paid-resource decision.

Every cost estimate must include:

- Estimate owner.
- Estimate date.
- Billing account currency.
- Region.
- Monthly usage assumptions.
- Always-on versus scheduled usage assumptions.
- Minimum, expected, and stress-case scenarios.
- Approval record before Terraform apply.

## Current No-GKE Baseline

The current sandbox baseline to estimate is:

- Cloud Run API service.
- Cloud Run validator job.
- Cloud Scheduler validator trigger.
- Cloud SQL PostgreSQL ledger instance.
- Cloud SQL storage, backups, and point-in-time recovery.
- Artifact Registry image storage.
- Secret Manager secrets and versions.
- Cloud Monitoring alert policies and notification channels.
- Cloud Logging ingestion and retention.
- Pub/Sub budget notifications.
- Cost guard Cloud Run service.

This baseline is the only active cloud architecture for Phase 4.

## Deferred Production-Style Estimates

The following estimates are required before future implementation but remain deferred:

- Production ingress estimate: external HTTPS load balancer or API Gateway, Cloud Armor WAF, Certificate Manager, static IP, DNS, serverless NEG, and logging.
- HSM/KMS signing estimate: key rings, crypto keys, HSM-protected keys when selected, signing-service runtime, audit logging, and key-ceremony operations.
- GKE validator operations estimate: Standard or Autopilot cluster decision, node pool shape, node count, boot disks, logging/monitoring, private networking, Cloud NAT if needed, and pod-to-pod validator traffic.
- Disaster recovery estimate: restore targets, backup retention, test restore instances, storage, and operator drill time.
- Security review estimate: penetration test scope, external reviewer cost, remediation buffer, and retest window.

Each estimate must be separate so a future GKE decision does not block the current no-GKE Phase 4 work.

## Scenario Matrix

Required cost scenarios:

- `sandbox_minimal`: current no-GKE resources with low traffic and scheduled validator sweeps.
- `sandbox_extended`: current no-GKE resources with longer observation, higher log retention, and repeated smoke tests.
- `preprod_no_gke`: production-like API and database sizing without GKE validator operations.
- `preprod_with_hsm_kms`: preprod no-GKE plus managed signing resources.
- `preprod_with_prod_ingress`: preprod no-GKE plus production-style ingress.
- `validator_ops_gke_lab`: isolated GKE validator operations test, separate from the active API baseline.
- `validator_ops_gke_realistic`: multi-node validator operations estimate for later Phase 5B planning.

## Approval Gates

Before any paid production-style resource is applied:

1. Finance owner reviews estimate.
2. Technical owner reviews resource shape.
3. Security owner reviews exposure and network assumptions.
4. Operations owner reviews logging, monitoring, backup, and response burden.
5. Executive approver accepts expected monthly cost and overrun risk.
6. Terraform plan is reviewed and attached to evidence.

No cost approval may override the regulatory readiness gate or the real-value prohibition.

## GKE Estimate Boundary

GKE remains deferred to `phase5b-gke-validator-ops`.

The GKE estimate must be modeled separately with these dimensions:

- Cluster mode: Standard or Autopilot.
- Cluster location: zonal or regional.
- Node count.
- Machine type.
- Boot disk size and type.
- Private cluster or public cluster.
- Cloud NAT requirement.
- Internal load balancing requirement.
- Logging and monitoring volume.
- Validator pod resource requests and limits.
- Network traffic between validators.

Phase 5A remains no-GKE and can proceed with Cloud Run Job plus Cloud Scheduler validator hardening.

## Non-Enablement

This cost model keeps the following disabled:

- Terraform apply.
- Google Cloud resource creation.
- GKE cluster creation.
- Production ingress apply.
- HSM/KMS production signing.
- External institution onboarding.
- Real-value settlement.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- Cost model document is checked in.
- Structured cost model config exists.
- Static cost model validator passes.
- Phase 4 validator includes the cost model checkpoint.
- Phase 3 and Phase 2 validators still pass.
- No Google Cloud resources are created or changed.
- No GKE, HSM/KMS signing, production ingress, external institution onboarding, or real-value capability is enabled.
