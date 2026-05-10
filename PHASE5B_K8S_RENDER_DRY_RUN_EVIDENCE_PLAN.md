# KANI Phase 5B Kubernetes Render And Dry-Run Evidence Plan

Status: Kubernetes render and dry-run evidence plan ready
Release candidate: `phase5b-k8s-render-dry-run-evidence-plan-rc1`
Date: 2026-05-10

This checkpoint defines the evidence contract for future Kubernetes manifest render and dry-run review on the `phase5b-gke-validator-ops` track. It specifies what operators must capture before any GKE validator manifest can be applied, while keeping the current no-GKE runtime unchanged.

This is a planning and validation checkpoint only. It does not run `kubectl`, render manifests, connect to a Kubernetes cluster, mutate kubeconfig, create GKE resources, deploy validators, change `k8s/kustomization.yaml`, move validators off the Cloud Run Job plus Cloud Scheduler runtime, expose production ingress, or authorize real-value settlement.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke` until Phase 5B receives explicit implementation approval.

This checkpoint inherits from `phase5b-k8s-manifest-design-plan-rc1`.

## Evidence Boundary

`k8s/phase5b-render-dry-run-evidence-plan.yaml` is an evidence contract, not a Kubernetes resource manifest.

It must:

- Keep `render_execution_enabled = false`.
- Keep `client_dry_run_execution_approved_by_this_checkpoint = false`.
- Keep `server_dry_run_execution_approved_by_this_checkpoint = false`.
- Keep `kubectl_apply_allowed = false`.
- Keep `kubernetes_manifest_deployment_enabled = false`.
- Keep `kustomization_inclusion_allowed = false`.
- Remain outside `k8s/kustomization.yaml`.
- Declare no top-level `apiVersion` or `kind` fields.
- Produce only planning metadata.
- Keep GKE validator workloads deferred.
- Keep live validator operations disabled.
- Keep the active no-GKE runtime unchanged.

## Command Template Boundary

Future operators may use command templates only after the required review gates are approved outside this checkpoint:

- `kubectl version --client --output=yaml`
- `kubectl kustomize k8s`
- `kubectl apply --dry-run=client -k k8s`
- `kubectl apply --dry-run=server -k k8s`

The templates are documented for future evidence collection only. This checkpoint does not execute them, does not approve cluster access, and does not approve any non-dry-run `kubectl apply`.

## Required Evidence Pack

The render and dry-run evidence pack must include:

- `operator_identity`
- `reviewer_identity`
- `approval_reference`
- `repo_commit`
- `release_candidate`
- `tool_versions`
- `kube_context_name`
- `target_project`
- `target_cluster`
- `target_namespace`
- `manifest_source_inventory`
- `placeholder_replacement_evidence`
- `kustomization_inventory`
- `render_command`
- `render_stdout_redacted`
- `render_stderr_redacted`
- `rendered_manifest_sha256`
- `client_dry_run_command`
- `client_dry_run_stdout_redacted`
- `client_dry_run_stderr_redacted`
- `server_dry_run_command`
- `server_dry_run_stdout_redacted`
- `server_dry_run_stderr_redacted`
- `schema_validation_output`
- `policy_check_output`
- `secret_redaction_evidence`
- `no_apply_confirmation`
- `no_live_validator_confirmation`
- `rollback_notes`
- `teardown_notes`
- `reviewer_signoff`

No secrets, database URLs, API keys, private keys, bearer tokens, or raw credentials may be stored in the evidence pack.

## Required Review Gates

Before any render or dry-run command is executed, these gates must be completed outside this checkpoint:

- `cost_estimate_attached`
- `selected_profile_approved`
- `terraform_design_reviewed`
- `manifest_design_reviewed`
- `render_evidence_plan_reviewed`
- `gke_cluster_available`
- `kubectl_installed`
- `kubectl_context_verified`
- `kubeconfig_access_reviewed`
- `operator_identity_verified`
- `reviewer_assigned`
- `namespace_isolation_reviewed`
- `placeholder_values_prepared`
- `secret_redaction_reviewed`
- `artifact_registry_pull_access_reviewed`
- `workload_identity_reviewed`
- `database_connectivity_reviewed`
- `network_policy_reviewed`
- `pod_security_reviewed`
- `resource_limits_reviewed`
- `schema_validation_reviewed`
- `policy_check_reviewed`
- `client_dry_run_reviewed`
- `server_dry_run_reviewed`
- `no_apply_command_confirmed`
- `rollback_plan_approved`
- `teardown_plan_approved`
- `no_real_value_capability_enabled`

All gates remain blocked by this checkpoint.

## Implementation Stages

Phase 5B render and dry-run execution remains blocked until cost, Terraform, manifest, security, and operator reviews are approved:

1. `stage_0_evidence_plan_only`
2. `stage_1_command_template_review`
3. `stage_2_evidence_pack_template_review`
4. `stage_3_security_review`
5. `stage_4_local_render_candidate`
6. `stage_5_client_dry_run_candidate`
7. `stage_6_server_dry_run_candidate`
8. `stage_7_apply_candidate`
9. `stage_8_sandbox_gke_validator_pilot`
10. `stage_9_teardown_or_pause`

Only stages 0 through 3 are allowed by this checkpoint. Render execution, client dry-run execution, server dry-run execution, Kubernetes apply, manifest inclusion in Kustomize, GKE validator deployment, live validator operations, and GKE smoke tests remain blocked.

## Non-Enablement

This checkpoint keeps the following disabled:

- GKE cluster creation.
- GKE node pool creation.
- GKE resource creation approval.
- Terraform apply.
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

- Phase 5B Kubernetes render and dry-run evidence plan is checked in.
- Structured Phase 5B Kubernetes render and dry-run evidence config exists.
- Non-deployable Phase 5B render and dry-run evidence contract exists.
- Static Phase 5B render and dry-run evidence validator passes.
- Aggregate Phase 5B validator includes the render and dry-run evidence plan.
- The Phase 5B Kubernetes manifest design plan remains checked in and valid.
- Phase 5A, Phase 4, Phase 3, and Phase 2 validators still pass.
- Terraform validation still passes.
- Rust workspace checks still pass.
- No Google Cloud resources are created or changed.
- No Kubernetes resources are deployed.
- No render or dry-run command is executed.
- No GKE, node pool, IAM mutation, Kubernetes deployment, Terraform apply, `kubectl apply`, live validator operations, production authorization, legal approval, or real-value capability is enabled.
