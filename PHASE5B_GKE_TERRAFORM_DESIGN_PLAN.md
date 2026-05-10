# KANI Phase 5B GKE Terraform Design Plan

Status: GKE Terraform design plan ready
Release candidate: `phase5b-gke-terraform-design-plan-rc1`
Date: 2026-05-10

This checkpoint defines the design-only Terraform boundary for future GKE validator operations on the `phase5b-gke-validator-ops` track. It converts the Phase 5B GKE cost/resource planning checkpoint into a Terraform shape that can be reviewed without creating a cluster, node pool, IAM binding, Kubernetes workload, or paid Google Cloud resource.

This is a planning and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, enable GKE, deploy Kubernetes manifests, move validators off the current no-GKE runtime, expose production ingress, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke` until Phase 5B receives explicit implementation approval.

This checkpoint inherits from `phase5b-gke-cost-resource-plan-rc1`.

## Terraform Boundary

`infra/terraform/phase5b_gke_terraform_design_plan.tf` is design-only.

It must:

- Keep `phase5b_gke_terraform_design_enabled = false`.
- Declare no `resource "google_*"` blocks.
- Declare no Kubernetes provider resources.
- Produce only planning outputs.
- Keep GKE cluster creation deferred.
- Keep node pool creation deferred.
- Keep Workload Identity IAM mutation deferred.
- Keep Kubernetes manifest deployment deferred.
- Keep live validator operations disabled.

## Design Objective

The Terraform design must be reviewable before any apply step:

- Select one candidate resource profile from the cost plan.
- Define cluster mode and zone topology.
- Define node-pool sizing boundaries for Standard profiles.
- Define pod request boundaries for Autopilot profiles.
- Define validator namespace, service account, and identity model.
- Define secret and database access boundaries.
- Define observability labels, alerting handoff, and cost guardrails.
- Define teardown ownership and rollback path.
- Preserve no-GKE Cloud Run Job plus Cloud Scheduler as the active runtime.

## Deferred Terraform Resource Families

Future apply candidates may include:

- `google_container_cluster`
- `google_container_node_pool`
- `google_service_account`
- `google_project_iam_member`
- `google_service_account_iam_member`
- `google_artifact_registry_repository_iam_member`
- `google_secret_manager_secret_iam_member`
- `google_monitoring_alert_policy`
- `google_logging_metric`
- `google_billing_budget`

None of these are created by this checkpoint.

## Deferred Kubernetes Resource Families

Future apply candidates may include:

- `Namespace`
- `ServiceAccount`
- `ConfigMap`
- `SecretProviderClass`
- `Deployment`
- `StatefulSet`
- `PodDisruptionBudget`
- `NetworkPolicy`
- `Service`
- `CronJob`

None of these are deployed by this checkpoint.

## Required Design Sections

The Terraform design must document:

- `selected_resource_profile`
- `cluster_mode`
- `region`
- `zones`
- `cluster_name`
- `node_pool_name`
- `node_machine_type`
- `node_min_count`
- `node_max_count`
- `validator_replicas`
- `validator_namespace`
- `validator_service_account`
- `workload_identity_model`
- `secret_access_model`
- `database_access_model`
- `networking_model`
- `observability_model`
- `budget_guardrail_model`
- `teardown_model`

## Required Review Gates

Before any Terraform apply is considered, these gates must be completed outside this checkpoint:

- `cost_estimate_attached`
- `selected_profile_approved`
- `terraform_design_reviewed`
- `terraform_plan_reviewed`
- `security_architecture_reviewed`
- `iam_boundary_reviewed`
- `workload_identity_reviewed`
- `networking_reviewed`
- `secret_access_reviewed`
- `database_access_reviewed`
- `observability_reviewed`
- `budget_guardrail_reviewed`
- `quota_review_completed`
- `teardown_plan_approved`
- `rollback_plan_approved`
- `operator_assigned`
- `reviewer_assigned`
- `no_real_value_capability_enabled`

All gates remain blocked by this checkpoint.

## Implementation Stages

Phase 5B GKE Terraform implementation remains blocked until cost and design reviews are approved:

1. `stage_0_design_only`
2. `stage_1_cost_estimate_attached`
3. `stage_2_terraform_plan_draft`
4. `stage_3_security_review`
5. `stage_4_apply_candidate`
6. `stage_5_sandbox_gke_pilot`
7. `stage_6_validator_operations_rehearsal`
8. `stage_7_teardown_or_pause`

Only stages 0 through 3 are allowed by this checkpoint. Terraform apply, GKE resource creation, Kubernetes deployment, live validator operations, and GKE smoke tests remain blocked.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE cluster creation.
- GKE node pool creation.
- GKE resource creation approval.
- Terraform apply.
- Kubernetes manifest deployment.
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

- Phase 5B GKE Terraform design plan is checked in.
- Structured Phase 5B GKE Terraform design config exists.
- Design-only Terraform guard file exists.
- Static Phase 5B GKE Terraform design validator passes.
- Aggregate Phase 5B validator includes the Terraform design plan.
- Phase 5A, Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No GKE, node pool, IAM mutation, Kubernetes deployment, Terraform apply, live validator operations, production authorization, legal approval, or real-value capability is enabled.
