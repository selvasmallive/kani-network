# KANI Phase 5B GKE Apply-Readiness Gate

Status: GKE apply-readiness gate defined and blocked
Release candidate: `phase5b-gke-apply-readiness-gate-rc1`
Date: 2026-05-10

This checkpoint defines the blocked-by-default gate that must be satisfied before any future GKE validator infrastructure can move from planning to an apply candidate on the `phase5b-gke-validator-ops` track.

This is a planning and validation checkpoint only. It does not run `terraform plan`, run `terraform apply`, run `kubectl`, run `gcloud`, mutate kubeconfig, create GKE resources, deploy validators, change `k8s/kustomization.yaml`, move validators off the Cloud Run Job plus Cloud Scheduler runtime, expose production ingress, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke` until a later approved Phase 5B apply candidate explicitly changes it.

This checkpoint inherits from `phase5b-k8s-render-dry-run-evidence-plan-rc1`.

## Gate Outcome

The current gate outcome is:

```text
apply_readiness_gate_state = BLOCKED
gke_apply_ready = FALSE
terraform_apply_allowed = FALSE
kubectl_apply_allowed = FALSE
kubernetes_manifest_deployment_enabled = FALSE
```

The gate cannot pass inside this checkpoint. It can only be re-evaluated in a later checkpoint after the required evidence pack, reviews, operator assignments, budget confirmation, and rollback/teardown approvals are attached.

## Required Baselines

The gate depends on these existing release candidates:

- `phase5a-wrapup-rc1`
- `phase5b-gke-cost-resource-plan-rc1`
- `phase5b-gke-terraform-design-plan-rc1`
- `phase5b-k8s-manifest-design-plan-rc1`
- `phase5b-k8s-render-dry-run-evidence-plan-rc1`

## Required Evidence Inputs

The future apply-readiness evidence pack must include:

- `billing_account_confirmed`
- `cost_estimate_attached`
- `free_trial_credit_reviewed`
- `monthly_budget_limit_approved`
- `budget_alert_channel_verified`
- `cost_guardrail_behavior_reviewed`
- `selected_profile_approved`
- `quota_review_completed`
- `region_and_zone_selection_approved`
- `terraform_design_reviewed`
- `terraform_plan_artifact_attached`
- `terraform_plan_diff_reviewed`
- `terraform_state_backend_reviewed`
- `iam_boundary_reviewed`
- `workload_identity_reviewed`
- `artifact_registry_pull_access_reviewed`
- `secret_access_reviewed`
- `database_connectivity_reviewed`
- `networking_reviewed`
- `pod_security_reviewed`
- `resource_limits_reviewed`
- `manifest_design_reviewed`
- `render_evidence_reviewed`
- `client_dry_run_reviewed`
- `server_dry_run_reviewed`
- `schema_validation_reviewed`
- `policy_check_reviewed`
- `no_public_ingress_confirmed`
- `no_real_value_capability_enabled`
- `sandbox_runtime_flags_confirmed`
- `operator_assigned`
- `reviewer_assigned`
- `apply_window_approved`
- `rollback_plan_approved`
- `teardown_plan_approved`
- `incident_response_owner_assigned`
- `evidence_retention_location_defined`

No evidence input is approved by this checkpoint.

## Required Review Gates

Before a later apply candidate can be considered, these gates must be approved outside this checkpoint:

- `phase5b_cost_plan_approved`
- `phase5b_terraform_design_approved`
- `phase5b_manifest_design_approved`
- `phase5b_render_dry_run_evidence_approved`
- `billing_account_confirmed`
- `budget_limit_approved`
- `cost_guardrail_reviewed`
- `quota_review_completed`
- `selected_profile_approved`
- `terraform_plan_reviewed`
- `terraform_apply_window_approved`
- `iam_boundary_approved`
- `workload_identity_approved`
- `artifact_registry_access_approved`
- `secret_access_approved`
- `database_connectivity_approved`
- `networking_approved`
- `pod_security_approved`
- `resource_limits_approved`
- `manifest_dry_run_approved`
- `server_dry_run_approved`
- `policy_checks_approved`
- `no_public_ingress_approved`
- `sandbox_runtime_boundary_approved`
- `operator_assigned`
- `reviewer_assigned`
- `rollback_plan_approved`
- `teardown_plan_approved`
- `incident_response_owner_assigned`
- `evidence_retention_approved`
- `legal_boundary_acknowledged`
- `compliance_boundary_acknowledged`
- `no_external_institution_onboarding_enabled`
- `no_production_authorization_enabled`
- `no_real_value_capability_enabled`

All gates remain blocked by this checkpoint.

## Implementation Stages

Phase 5B GKE apply remains blocked until a later checkpoint explicitly promotes it:

1. `stage_0_apply_readiness_gate_defined`
2. `stage_1_prerequisite_inventory_review`
3. `stage_2_evidence_pack_review`
4. `stage_3_security_and_cost_review`
5. `stage_4_terraform_plan_candidate`
6. `stage_5_apply_window_candidate`
7. `stage_6_terraform_apply_candidate`
8. `stage_7_kubernetes_apply_candidate`
9. `stage_8_sandbox_gke_validator_pilot`
10. `stage_9_teardown_or_pause`

Only stages 0 through 3 are allowed by this checkpoint. Terraform plan execution, Terraform apply, Kubernetes apply, GKE resource creation, validator deployment, live validator operations, and smoke-test execution remain blocked.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE apply readiness.
- Apply window approval.
- Terraform plan execution.
- Terraform apply.
- GKE cluster creation.
- GKE node pool creation.
- Google Cloud mutation through `gcloud`.
- Kubernetes manifest deployment.
- `kubectl apply`.
- Render command execution.
- Client dry-run execution.
- Server dry-run execution.
- Kustomize inclusion.
- Kubeconfig mutation.
- Cluster context mutation.
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

- Phase 5B GKE apply-readiness gate is checked in.
- Structured Phase 5B GKE apply-readiness config exists.
- Static Phase 5B GKE apply-readiness validator passes.
- Aggregate Phase 5B validator includes the apply-readiness gate.
- The prior Phase 5B planning checkpoints remain checked in and valid.
- Phase 5A, Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No Kubernetes resources are deployed.
- No Terraform plan, Terraform apply, render, dry-run, or `kubectl apply` command is executed.
- No GKE, node pool, IAM mutation, Kubernetes deployment, live validator operations, production authorization, legal approval, or real-value capability is enabled.
