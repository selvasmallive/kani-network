# KANI Phase 5B GKE Cost And Resource Plan

Status: GKE cost and resource planning checkpoint ready
Release candidate: `phase5b-gke-cost-resource-plan-rc1`
Date: 2026-05-10

Phase 5B starts the `phase5b-gke-validator-ops` track. This first checkpoint defines the Google Kubernetes Engine cost and resource estimate inputs needed before any GKE validator resources are created.

This is a planning and validation checkpoint only. It does not create Google Cloud resources, apply Terraform, enable GKE, deploy Kubernetes manifests, move validators off the current no-GKE runtime, expose production ingress, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke` until Phase 5B receives explicit implementation approval.

This checkpoint inherits from `phase5a-wrapup-rc1`.

## Pricing Source Inputs

Use the official Google Cloud GKE pricing page and Google Cloud Pricing Calculator for the actual estimate. The working estimate must record:

- GKE cluster management fee input.
- GKE free-tier credit input.
- Whether the free tier can apply to the selected cluster mode.
- Standard node pool Compute Engine instance cost.
- Autopilot pod request cost, if Autopilot is selected.
- Boot disk cost.
- Load balancing cost, if any Service or ingress is planned.
- Cloud Logging and Cloud Monitoring cost impact.
- Artifact Registry pull and storage cost impact.
- Cloud NAT or static IP cost, if private nodes or egress controls are planned.
- Budget alert and cost-guard threshold.
- Free trial credit impact.
- Teardown and scale-down procedure.

The plan must not rely on hardcoded historical pricing. The operator must calculate the estimate for the selected region, zone topology, node size, disk size, logging volume, and runtime duration.

## Candidate Resource Profiles

Phase 5B estimates three candidate profiles before choosing one:

1. `lean_sandbox_standard_zonal`
2. `validator_ops_standard_multizone`
3. `autopilot_small_pod_request`

### Lean Sandbox Standard Zonal

Purpose: lowest-cost GKE learning environment for sandbox validator operations.

Planned shape:

- One zonal Standard cluster.
- One autoscaled node pool.
- Minimum one node.
- Maximum three nodes.
- Small general-purpose machine family candidates.
- Three validator pods for behavior testing.
- No production fault-domain guarantee.
- No public production ingress.
- Explicit teardown after each approved test window.

### Validator Ops Standard Multizone

Purpose: closer operational rehearsal for three validator pods across failure domains.

Planned shape:

- One Standard cluster with multiple zones.
- One or more node pools.
- Minimum three nodes.
- Maximum six nodes.
- One validator pod per preferred zone when capacity allows.
- Pod disruption budgets and anti-affinity.
- Higher cost than the lean sandbox profile.
- Still sandbox-only and not production authorized.

### Autopilot Small Pod Request

Purpose: compare a pod-request billing model against Standard node-pool billing.

Planned shape:

- One Autopilot cluster.
- Three validator pods with explicit CPU, memory, and ephemeral storage requests.
- No manual node-pool sizing.
- Workload identity and namespace isolation.
- Cost estimate driven by requested resources and runtime duration.
- Still sandbox-only and not production authorized.

## Required Estimate Inputs

The estimate pack must include:

- Billing account and project.
- Region and selected zones.
- Cluster mode.
- Cluster count.
- Node pool count.
- Minimum nodes.
- Maximum nodes.
- Machine type candidates.
- Boot disk type and size.
- Validator replica count.
- Validator CPU and memory request per pod.
- Expected daily runtime hours.
- Expected monthly runtime hours.
- Logging retention and expected ingestion.
- Monitoring metrics and alerting scope.
- Load balancer requirement.
- Private cluster, Cloud NAT, or static IP requirement.
- Artifact Registry image pull/storage assumptions.
- Budget threshold.
- Teardown owner and teardown command plan.

## Required Approval Gates

Before GKE is created, these gates must be completed outside this checkpoint:

- `billing_account_confirmed`
- `free_trial_credit_reviewed`
- `pricing_calculator_estimate_saved`
- `selected_resource_profile_approved`
- `monthly_budget_limit_approved`
- `quota_review_completed`
- `region_and_zone_selection_approved`
- `terraform_plan_reviewed`
- `terraform_apply_window_approved`
- `teardown_plan_approved`
- `operator_assigned`
- `reviewer_assigned`
- `security_boundary_reviewed`
- `workload_identity_plan_reviewed`
- `networking_plan_reviewed`
- `observability_plan_reviewed`
- `no_real_value_capability_enabled`

All gates remain blocked by this checkpoint.

## Implementation Plan

Phase 5B implementation remains blocked until a resource profile and cost estimate are approved:

1. `estimate_profiles`
2. `select_profile`
3. `draft_terraform`
4. `terraform_plan_review`
5. `apply_gke_resources`
6. `deploy_validator_manifests`
7. `run_gke_smoke_tests`
8. `observe_cost_and_health`
9. `teardown_or_pause`

Only the planning stages are allowed by this checkpoint. Terraform apply, GKE resource creation, validator deployment, smoke execution, and live validator operations remain blocked.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE cluster creation.
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

- Phase 5B GKE cost and resource plan is checked in.
- Structured Phase 5B GKE cost and resource config exists.
- Static Phase 5B GKE cost and resource validator passes.
- Aggregate Phase 5B validator includes the cost and resource plan.
- Phase 5A, Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No GKE, Terraform apply, Kubernetes deployment, live validator operations, production ingress, production authorization, legal approval, or real-value capability is enabled.
