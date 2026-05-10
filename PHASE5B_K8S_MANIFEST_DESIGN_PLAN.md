# KANI Phase 5B Kubernetes Manifest Design Plan

Status: Kubernetes manifest design plan ready
Release candidate: `phase5b-k8s-manifest-design-plan-rc1`
Date: 2026-05-10

This checkpoint defines the design-only Kubernetes manifest boundary for future GKE validator operations on the `phase5b-gke-validator-ops` track. It converts the Phase 5B GKE cost/resource and Terraform design checkpoints into a reviewable manifest shape without deploying validators, changing the active no-GKE runtime, or creating Google Cloud resources.

This is a planning and validation checkpoint only. It does not run `kubectl apply`, include new resources in `k8s/kustomization.yaml`, create a GKE cluster, mutate IAM, deploy validator pods, move validators off the current Cloud Run Job plus Cloud Scheduler runtime, expose production ingress, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke` until Phase 5B receives explicit implementation approval.

This checkpoint inherits from `phase5b-gke-terraform-design-plan-rc1`.

## Manifest Boundary

`k8s/phase5b-validator-manifest-design.yaml` is a design contract, not a Kubernetes resource manifest.

It must:

- Keep `kubernetes_manifest_deployment_enabled = false`.
- Keep `kubectl_apply_allowed = false`.
- Keep `kustomization_inclusion_allowed = false`.
- Remain outside `k8s/kustomization.yaml`.
- Declare no top-level `apiVersion` or `kind` fields.
- Produce only planning metadata.
- Keep GKE validator workloads deferred.
- Keep Workload Identity IAM mutation deferred.
- Keep live validator operations disabled.
- Keep the active no-GKE runtime unchanged.

## Current Manifest Inventory

The existing `k8s/` directory still contains Phase 2-era sandbox validator manifests:

- `namespace.yaml`
- `validator-rbac.yaml`
- `validator-configmap.yaml`
- `validator-secret.example.yaml`
- `validators.yaml`
- `kustomization.yaml`

Those files remain placeholders for later validator operations testing. This checkpoint does not update `k8s/kustomization.yaml`, does not create a Phase 5B overlay, and does not approve the existing manifests for deployment.

## Design Objective

The Kubernetes design must be reviewable before any apply step:

- Define the future validator namespace model.
- Define the Kubernetes service account and Google service account mapping.
- Define Workload Identity annotation requirements.
- Define image pull, tag pinning, and artifact access boundaries.
- Define ConfigMap and Secret Manager integration boundaries.
- Define Cloud SQL connectivity through sidecar or connector model.
- Define validator identity mapping for `validator-a`, `validator-b`, and `validator-c`.
- Define scheduling, topology spread, anti-affinity, and disruption requirements.
- Define resource requests, limits, probes, and security context requirements.
- Define network policy and no-public-ingress boundaries.
- Define observability labels, logs, metrics, alerts, and evidence capture.
- Define rollout, rollback, smoke test, and teardown ownership.
- Preserve no-GKE Cloud Run Job plus Cloud Scheduler as the active runtime.

## Future Manifest Component Families

Future apply candidates may include:

- `Namespace`
- `ServiceAccount`
- `ConfigMap`
- `SecretProviderClass`
- `ExternalSecret`
- `Deployment`
- `StatefulSet`
- `PodDisruptionBudget`
- `NetworkPolicy`
- `ResourceQuota`
- `LimitRange`
- `Service`
- `CronJob`
- `Job`

None of these are deployed by this checkpoint.

## Required Design Sections

The Kubernetes manifest design must document:

- `namespace_model`
- `service_account_model`
- `workload_identity_annotation_model`
- `image_model`
- `config_model`
- `secret_model`
- `database_connectivity_model`
- `validator_identity_model`
- `replica_topology_model`
- `scheduling_model`
- `resource_request_model`
- `security_context_model`
- `network_policy_model`
- `disruption_budget_model`
- `health_probe_model`
- `observability_model`
- `rollout_model`
- `smoke_test_model`
- `rollback_model`
- `teardown_model`
- `evidence_model`

## Required Review Gates

Before any Kubernetes apply is considered, these gates must be completed outside this checkpoint:

- `cost_estimate_attached`
- `selected_profile_approved`
- `terraform_design_reviewed`
- `gke_cluster_available`
- `kubectl_context_verified`
- `manifest_design_reviewed`
- `manifest_dry_run_reviewed`
- `security_architecture_reviewed`
- `namespace_isolation_reviewed`
- `workload_identity_reviewed`
- `artifact_registry_pull_access_reviewed`
- `secret_access_reviewed`
- `database_connectivity_reviewed`
- `network_policy_reviewed`
- `pod_security_reviewed`
- `resource_limits_reviewed`
- `scheduling_reviewed`
- `observability_reviewed`
- `budget_guardrail_reviewed`
- `rollback_plan_approved`
- `teardown_plan_approved`
- `operator_assigned`
- `reviewer_assigned`
- `no_real_value_capability_enabled`

All gates remain blocked by this checkpoint.

## Implementation Stages

Phase 5B Kubernetes manifest implementation remains blocked until cost, Terraform, security, and manifest reviews are approved:

1. `stage_0_design_only`
2. `stage_1_manifest_blueprint_review`
3. `stage_2_kubectl_dry_run_candidate`
4. `stage_3_security_review`
5. `stage_4_apply_candidate`
6. `stage_5_sandbox_gke_validator_pilot`
7. `stage_6_validator_operations_rehearsal`
8. `stage_7_teardown_or_pause`

Only stages 0 through 3 are allowed by this checkpoint. Kubernetes apply, manifest inclusion in Kustomize, GKE validator deployment, live validator operations, and GKE smoke tests remain blocked.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE cluster creation.
- GKE node pool creation.
- GKE resource creation approval.
- Terraform apply.
- Kubernetes manifest deployment.
- `kubectl apply`.
- Kustomize inclusion.
- Live validator operations.
- Production BFT validator network.
- Production ingress.
- Public endpoint exposure.
- Cloud Armor WAF apply.
- mTLS trust config apply.
- HSM/KMS production signing.
- Scheduler mutation.
- Cloud Run Job execution approval.
- Secret rotation approval.
- Live failure drills.
- Live retry drills.
- Live recovery drills.
- Live sandbox smoke execution.
- Failure injection.
- Production replay.
- Restore drill execution.
- Production recovery execution.
- External evidence export.
- External institution onboarding.
- Production authorization.
- Legal or compliance approval.
- Real-value settlement.
- Fiat deposit or redemption.
- Custody for others.
- Trading.
- Google Cloud resource creation.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- Phase 5B Kubernetes manifest design plan is checked in.
- Structured Phase 5B Kubernetes manifest design config exists.
- Non-deployable Phase 5B manifest blueprint exists.
- Static Phase 5B Kubernetes manifest design validator passes.
- Aggregate Phase 5B validator includes the Kubernetes manifest design plan.
- The Phase 5B Terraform design plan remains checked in and valid.
- Phase 5A, Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No Kubernetes resources are deployed.
- No GKE, node pool, IAM mutation, Kubernetes deployment, Terraform apply, `kubectl apply`, live validator operations, production authorization, legal approval, or real-value capability is enabled.
