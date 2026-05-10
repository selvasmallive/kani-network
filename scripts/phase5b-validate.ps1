$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE5B_GKE_COST_RESOURCE_PLAN.md",
    "PHASE5B_GKE_TERRAFORM_DESIGN_PLAN.md",
    "PHASE5B_K8S_MANIFEST_DESIGN_PLAN.md",
    "PHASE5B_K8S_RENDER_DRY_RUN_EVIDENCE_PLAN.md",
    "PHASE5B_GKE_APPLY_READINESS_GATE.md",
    "PHASE5B_GKE_OPERATOR_APPROVAL_PACKET.md",
    "PHASE5B_WRAPUP.md",
    "config/phase5b-gke-cost-resource-plan.yaml",
    "config/phase5b-gke-terraform-design-plan.yaml",
    "config/phase5b-k8s-manifest-design-plan.yaml",
    "config/phase5b-k8s-render-dry-run-evidence-plan.yaml",
    "config/phase5b-gke-apply-readiness-gate.yaml",
    "config/phase5b-gke-operator-approval-packet.yaml",
    "config/phase5b-wrapup.yaml",
    "infra/terraform/phase5b_gke_terraform_design_plan.tf",
    "k8s/phase5b-validator-manifest-design.yaml",
    "k8s/phase5b-render-dry-run-evidence-plan.yaml",
    "scripts/phase5b-gke-cost-resource-plan.ps1",
    "scripts/phase5b-gke-terraform-design-plan.ps1",
    "scripts/phase5b-k8s-manifest-design-plan.ps1",
    "scripts/phase5b-k8s-render-dry-run-evidence-plan.ps1",
    "scripts/phase5b-gke-apply-readiness-gate.ps1",
    "scripts/phase5b-gke-operator-approval-packet.ps1",
    "scripts/phase5b-wrapup.ps1",
    "PHASE5A_WRAPUP.md",
    "config/phase5a-wrapup.yaml",
    "scripts/phase5a-validate.ps1",
    "PHASE4_WRAPUP.md",
    "config/phase4-wrapup.yaml",
    "scripts/phase4-validate.ps1",
    "scripts/phase3-validate.ps1",
    "scripts/phase2-validate.ps1"
)

$missing = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5B validation files: $($missing -join ', ')"
}

$plan = Get-Content "PHASE5B_GKE_COST_RESOURCE_PLAN.md" -Raw
foreach ($expected in @(
    "Status: GKE cost and resource planning checkpoint ready",
    "phase5b-gke-cost-resource-plan-rc1",
    "phase5b-gke-validator-ops",
    "phase5a-wrapup-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Pricing Source Inputs",
    "Candidate Resource Profiles",
    "lean_sandbox_standard_zonal",
    "validator_ops_standard_multizone",
    "autopilot_small_pod_request",
    "Required Approval Gates",
    "Implementation Plan",
    "No Google Cloud resources are created or changed"
)) {
    if ($plan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE cost/resource plan content: $expected"
    }
}

$terraformDesignPlan = Get-Content "PHASE5B_GKE_TERRAFORM_DESIGN_PLAN.md" -Raw
foreach ($expected in @(
    "Status: GKE Terraform design plan ready",
    "phase5b-gke-terraform-design-plan-rc1",
    "phase5b-gke-cost-resource-plan-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Terraform Boundary",
    "infra/terraform/phase5b_gke_terraform_design_plan.tf",
    "Design Objective",
    "Deferred Terraform Resource Families",
    "google_container_cluster",
    "google_container_node_pool",
    "Deferred Kubernetes Resource Families",
    "PodDisruptionBudget",
    "Required Design Sections",
    "Required Review Gates",
    "Implementation Stages",
    "No Google Cloud resources are created or changed"
)) {
    if ($terraformDesignPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE Terraform design plan content: $expected"
    }
}

$k8sManifestDesignPlan = Get-Content "PHASE5B_K8S_MANIFEST_DESIGN_PLAN.md" -Raw
foreach ($expected in @(
    "Status: Kubernetes manifest design plan ready",
    "phase5b-k8s-manifest-design-plan-rc1",
    "phase5b-gke-terraform-design-plan-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Manifest Boundary",
    "k8s/phase5b-validator-manifest-design.yaml",
    "Current Manifest Inventory",
    "Future Manifest Component Families",
    "SecretProviderClass",
    "PodDisruptionBudget",
    "ResourceQuota",
    "Required Design Sections",
    "Required Review Gates",
    "Implementation Stages",
    "No Kubernetes resources are deployed"
)) {
    if ($k8sManifestDesignPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes manifest design plan content: $expected"
    }
}

$k8sRenderDryRunEvidencePlan = Get-Content "PHASE5B_K8S_RENDER_DRY_RUN_EVIDENCE_PLAN.md" -Raw
foreach ($expected in @(
    "Status: Kubernetes render and dry-run evidence plan ready",
    "phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "phase5b-k8s-manifest-design-plan-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Evidence Boundary",
    "k8s/phase5b-render-dry-run-evidence-plan.yaml",
    "Command Template Boundary",
    "kubectl apply --dry-run=client -k k8s",
    "kubectl apply --dry-run=server -k k8s",
    "Required Evidence Pack",
    "rendered_manifest_sha256",
    "Required Review Gates",
    "server_dry_run_reviewed",
    "Implementation Stages",
    "No render or dry-run command is executed"
)) {
    if ($k8sRenderDryRunEvidencePlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes render/dry-run evidence plan content: $expected"
    }
}

$gkeApplyReadinessGatePlan = Get-Content "PHASE5B_GKE_APPLY_READINESS_GATE.md" -Raw
foreach ($expected in @(
    "Status: GKE apply-readiness gate defined and blocked",
    "phase5b-gke-apply-readiness-gate-rc1",
    "phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Gate Outcome",
    "apply_readiness_gate_state = BLOCKED",
    "gke_apply_ready = FALSE",
    "Required Evidence Inputs",
    "terraform_plan_artifact_attached",
    "Required Review Gates",
    "terraform_apply_window_approved",
    "Implementation Stages",
    "stage_7_kubernetes_apply_candidate",
    "No Terraform plan, Terraform apply, render, dry-run"
)) {
    if ($gkeApplyReadinessGatePlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE apply-readiness gate content: $expected"
    }
}

$gkeOperatorApprovalPacketPlan = Get-Content "PHASE5B_GKE_OPERATOR_APPROVAL_PACKET.md" -Raw
foreach ($expected in @(
    "Status: GKE operator approval packet defined and blocked",
    "phase5b-gke-operator-approval-packet-rc1",
    "phase5b-gke-apply-readiness-gate-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Packet Outcome",
    "operator_approval_packet_state = BLOCKED",
    "operator_approval_packet_complete = FALSE",
    "Required Roles",
    "evidence_custodian",
    "Required Packet Sections",
    "terraform_plan_hash",
    "Required Signoffs",
    "no_real_value_capability_acknowledgement",
    "Implementation Stages",
    "stage_6_apply_readiness_re_evaluation_candidate",
    "No Terraform plan, Terraform apply, render, dry-run"
)) {
    if ($gkeOperatorApprovalPacketPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE operator approval packet content: $expected"
    }
}

$phase5bWrapupPlan = Get-Content "PHASE5B_WRAPUP.md" -Raw
foreach ($expected in @(
    "Status: GKE validator ops planning complete",
    "phase5b-wrapup-rc1",
    "phase5b-gke-operator-approval-packet-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Completed Phase 5B Checkpoints",
    "phase5b-gke-cost-resource-plan-rc1",
    "phase5b-gke-terraform-design-plan-rc1",
    "phase5b-k8s-manifest-design-plan-rc1",
    "phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "phase5b-gke-apply-readiness-gate-rc1",
    "phase5b-gke-operator-approval-packet-rc1",
    "Phase 5B Result",
    "Phase 5B can hand off to",
    "phase6-gke-apply-candidate",
    "Required Blocks That Remain",
    "No Google Cloud resources are created or changed"
)) {
    if ($phase5bWrapupPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B wrap-up content: $expected"
    }
}

$config = Get-Content "config/phase5b-gke-cost-resource-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-gke-cost-resource-plan-rc1",
    "status: gke_cost_resource_planning_checkpoint_ready",
    "inherits_from: phase5a-wrapup-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "pricing_inputs:",
    "cluster_management_fee_usd_per_cluster_hour: 0.10",
    "monthly_free_tier_credit_usd: 74.40",
    "operator_must_recalculate_in_pricing_calculator: true",
    "candidate_resource_profiles:",
    "lean_sandbox_standard_zonal:",
    "validator_ops_standard_multizone:",
    "autopilot_small_pod_request:",
    "required_estimate_inputs:",
    "required_approval_gates:",
    "implementation_plan:",
    "non_enablement:",
    "gke_cluster_enabled: false",
    "gke_resource_creation_allowed: false",
    "terraform_gke_apply_allowed: false",
    "kubernetes_manifest_deployment_enabled: false",
    "live_validator_operations_enabled: false",
    "phase5b_gke_cost_resource_plan_checked_in: true",
    "aggregate_phase5b_validator_includes_gke_cost_resource_plan: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE cost/resource plan config content: $expected"
    }
}

$terraformDesignConfig = Get-Content "config/phase5b-gke-terraform-design-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-gke-terraform-design-plan-rc1",
    "status: gke_terraform_design_plan_ready",
    "inherits_from: phase5b-gke-cost-resource-plan-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "terraform_design_file: infra/terraform/phase5b_gke_terraform_design_plan.tf",
    "terraform_boundary:",
    "design_only: true",
    "phase5b_gke_terraform_design_enabled: false",
    "declares_google_resources: false",
    "declares_kubernetes_resources: false",
    "terraform_apply_allowed: false",
    "terraform_gke_apply_allowed: false",
    "gke_cluster_creation_deferred: true",
    "node_pool_creation_deferred: true",
    "selected_design_defaults:",
    "selected_resource_profile: lean_sandbox_standard_zonal",
    "cluster_mode: standard_zonal",
    "node_machine_type: e2-medium",
    "node_min_count: 1",
    "node_max_count: 3",
    "validator_replicas: 3",
    "deferred_google_resource_families:",
    "google_container_cluster: deferred",
    "google_container_node_pool: deferred",
    "deferred_kubernetes_resource_families:",
    "PodDisruptionBudget: deferred",
    "required_design_sections:",
    "selected_resource_profile: required",
    "workload_identity_model: required",
    "required_review_gates:",
    "cost_estimate_attached: blocked",
    "terraform_plan_reviewed: blocked",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_4_apply_candidate:",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "phase5b_gke_terraform_design_plan_checked_in: true",
    "aggregate_phase5b_validator_includes_gke_terraform_design_plan: true"
)) {
    if ($terraformDesignConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE Terraform design config content: $expected"
    }
}

$terraformDesignFile = Get-Content "infra/terraform/phase5b_gke_terraform_design_plan.tf" -Raw
foreach ($expected in @(
    'variable "phase5b_gke_terraform_design_enabled"',
    'default     = false',
    "phase5b-gke-terraform-design-plan-rc1 is design-only",
    'variable "phase5b_gke_selected_profile"',
    "lean_sandbox_standard_zonal",
    "validator_ops_standard_multizone",
    "autopilot_small_pod_request",
    "google_container_cluster",
    "google_container_node_pool",
    "PodDisruptionBudget",
    'output "phase5b_gke_terraform_design_plan"'
)) {
    if ($terraformDesignFile -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Terraform design file content: $expected"
    }
}

if ($terraformDesignFile -match '(?m)^\s*resource\s+"(google|kubernetes)_') {
    throw "Phase 5B Terraform design file must not declare google_* or kubernetes_* resources"
}

$k8sManifestDesignConfig = Get-Content "config/phase5b-k8s-manifest-design-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-manifest-design-plan-rc1",
    "status: k8s_manifest_design_plan_ready",
    "inherits_from: phase5b-gke-terraform-design-plan-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "manifest_design_file: k8s/phase5b-validator-manifest-design.yaml",
    "manifest_boundary:",
    "design_only: true",
    "kubernetes_manifest_deployment_enabled: false",
    "kubectl_apply_allowed: false",
    "kustomization_inclusion_allowed: false",
    "included_in_kustomization: false",
    "declares_top_level_api_version_or_kind: false",
    "selected_manifest_defaults:",
    "selected_resource_profile: lean_sandbox_standard_zonal",
    "validator_namespace: kani-validator",
    "kubernetes_service_account: kani-gke-validator",
    "validator_replicas: 3",
    "future_manifest_component_families:",
    "SecretProviderClass: deferred",
    "PodDisruptionBudget: deferred",
    "ResourceQuota: deferred",
    "required_design_sections:",
    "namespace_model: required",
    "workload_identity_annotation_model: required",
    "required_review_gates:",
    "manifest_design_reviewed: blocked",
    "manifest_dry_run_reviewed: blocked",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_4_apply_candidate:",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "phase5b_k8s_manifest_design_plan_checked_in: true",
    "aggregate_phase5b_validator_includes_k8s_manifest_design_plan: true"
)) {
    if ($k8sManifestDesignConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes manifest design config content: $expected"
    }
}

$manifestDesignFile = Get-Content "k8s/phase5b-validator-manifest-design.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-manifest-design-plan-rc1",
    "status: design_only_manifest_blueprint",
    "phase5b-gke-validator-ops",
    "phase2-lean-no-gke",
    "phase5b-gke-terraform-design-plan-rc1",
    "design_boundary:",
    "do_not_apply_with_kubectl: true",
    "not_included_in_kustomization: true",
    "contains_deployable_kubernetes_objects: false",
    "kubernetes_manifest_deployment_enabled: false",
    "kubectl_apply_allowed: false",
    "kustomization_inclusion_allowed: false",
    "future_manifest_blueprint:",
    "kubernetes_kind: Namespace",
    "kubernetes_kind: ServiceAccount",
    "kubernetes_kind: Deployment",
    "validator_id: validator-a",
    "validator_id: validator-b",
    "validator_id: validator-c",
    "kubernetes_kind: PodDisruptionBudget",
    "future_pod_requirements:",
    "pinned_digest_required_before_apply",
    "review_gates:",
    "manifest_dry_run_reviewed: blocked",
    "non_enablement:"
)) {
    if ($manifestDesignFile -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes manifest blueprint content: $expected"
    }
}

if ((Get-Content "k8s/kustomization.yaml" -Raw) -match [regex]::Escape("phase5b-validator-manifest-design.yaml")) {
    throw "Phase 5B Kubernetes manifest design file must not be included in k8s/kustomization.yaml"
}

if ($manifestDesignFile -match "(?m)^(apiVersion|kind):") {
    throw "Phase 5B Kubernetes manifest design file must not declare top-level apiVersion or kind fields"
}

$k8sRenderDryRunEvidenceConfig = Get-Content "config/phase5b-k8s-render-dry-run-evidence-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "status: k8s_render_dry_run_evidence_plan_ready",
    "inherits_from: phase5b-k8s-manifest-design-plan-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "evidence_plan_file: k8s/phase5b-render-dry-run-evidence-plan.yaml",
    "evidence_boundary:",
    "design_only: true",
    "render_execution_enabled: false",
    "client_dry_run_execution_approved_by_this_checkpoint: false",
    "server_dry_run_execution_approved_by_this_checkpoint: false",
    "kubectl_apply_allowed: false",
    "kubernetes_manifest_deployment_enabled: false",
    "kustomization_inclusion_allowed: false",
    "included_in_kustomization: false",
    "kubeconfig_mutation_allowed: false",
    "cluster_context_mutation_allowed: false",
    "command_template_scope:",
    "commands_documented_only: true",
    "non_dry_run_apply_template_allowed: false",
    "required_evidence_pack_sections:",
    "operator_identity: required",
    "rendered_manifest_sha256: required",
    "server_dry_run_stderr_redacted: required",
    "secret_redaction_evidence: required",
    "required_review_gates:",
    "render_evidence_plan_reviewed: blocked",
    "server_dry_run_reviewed: blocked",
    "no_apply_command_confirmed: blocked",
    "implementation_stages:",
    "stage_0_evidence_plan_only:",
    "stage_7_apply_candidate:",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "phase5b_k8s_render_dry_run_evidence_plan_checked_in: true",
    "aggregate_phase5b_validator_includes_k8s_render_dry_run_evidence_plan: true"
)) {
    if ($k8sRenderDryRunEvidenceConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes render/dry-run evidence config content: $expected"
    }
}

$renderDryRunEvidenceFile = Get-Content "k8s/phase5b-render-dry-run-evidence-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "status: render_dry_run_evidence_contract",
    "phase5b-gke-validator-ops",
    "phase2-lean-no-gke",
    "phase5b-k8s-manifest-design-plan-rc1",
    "design_boundary:",
    "do_not_apply_with_kubectl: true",
    "not_included_in_kustomization: true",
    "contains_deployable_kubernetes_objects: false",
    "render_execution_enabled: false",
    "client_dry_run_execution_approved_by_this_checkpoint: false",
    "server_dry_run_execution_approved_by_this_checkpoint: false",
    "kubectl_apply_allowed: false",
    "future_command_templates:",
    "kubectl version --client --output=yaml",
    "kubectl kustomize k8s",
    "kubectl apply --dry-run=client -k k8s",
    "kubectl apply --dry-run=server -k k8s",
    "non_dry_run_apply:",
    "command_allowed: false",
    "future_evidence_pack:",
    "rendered_manifest_sha256: required",
    "server_dry_run_stderr_redacted: required",
    "secret_redaction_evidence: required",
    "redaction_rules:",
    "review_gates:",
    "server_dry_run_reviewed: blocked",
    "non_enablement:"
)) {
    if ($renderDryRunEvidenceFile -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B Kubernetes render/dry-run evidence contract content: $expected"
    }
}

if ((Get-Content "k8s/kustomization.yaml" -Raw) -match [regex]::Escape("phase5b-render-dry-run-evidence-plan.yaml")) {
    throw "Phase 5B render/dry-run evidence file must not be included in k8s/kustomization.yaml"
}

if ($renderDryRunEvidenceFile -match "(?m)^(apiVersion|kind):") {
    throw "Phase 5B render/dry-run evidence file must not declare top-level apiVersion or kind fields"
}

$applyTemplateMatches = [regex]::Matches($renderDryRunEvidenceFile, "kubectl apply[^\r\n]*")
foreach ($match in $applyTemplateMatches) {
    if ($match.Value -notmatch "--dry-run=(client|server)") {
        throw "Phase 5B aggregate validator found non-dry-run kubectl apply template: $($match.Value)"
    }
}

$gkeApplyReadinessConfig = Get-Content "config/phase5b-gke-apply-readiness-gate.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-gke-apply-readiness-gate-rc1",
    "status: gke_apply_readiness_gate_defined_and_blocked",
    "inherits_from: phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_cost_resource_baseline: phase5b-gke-cost-resource-plan-rc1",
    "terraform_design_baseline: phase5b-gke-terraform-design-plan-rc1",
    "k8s_manifest_design_baseline: phase5b-k8s-manifest-design-plan-rc1",
    "k8s_render_dry_run_evidence_baseline: phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "gate_outcome:",
    "apply_readiness_gate_state: BLOCKED",
    "apply_readiness_gate_passed: false",
    "gke_apply_ready: false",
    "apply_window_approved: false",
    "terraform_plan_execution_approved_by_this_checkpoint: false",
    "terraform_apply_execution_approved_by_this_checkpoint: false",
    "kubernetes_apply_execution_approved_by_this_checkpoint: false",
    "required_baselines:",
    "k8s_render_dry_run_evidence_plan_rc1: required",
    "required_evidence_inputs:",
    "terraform_plan_artifact_attached: required",
    "server_dry_run_reviewed: required",
    "required_review_gates:",
    "terraform_apply_window_approved: blocked",
    "server_dry_run_approved: blocked",
    "no_real_value_capability_enabled: blocked",
    "implementation_stages:",
    "stage_0_apply_readiness_gate_defined:",
    "stage_7_kubernetes_apply_candidate:",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "gcloud_mutation_allowed: false",
    "phase5b_gke_apply_readiness_gate_checked_in: true",
    "aggregate_phase5b_validator_includes_gke_apply_readiness_gate: true"
)) {
    if ($gkeApplyReadinessConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE apply-readiness gate config content: $expected"
    }
}

$gkeOperatorApprovalConfig = Get-Content "config/phase5b-gke-operator-approval-packet.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-gke-operator-approval-packet-rc1",
    "status: gke_operator_approval_packet_defined_and_blocked",
    "inherits_from: phase5b-gke-apply-readiness-gate-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_apply_readiness_baseline: phase5b-gke-apply-readiness-gate-rc1",
    "packet_outcome:",
    "operator_approval_packet_state: BLOCKED",
    "operator_approval_packet_complete: false",
    "operator_signoff_approved: false",
    "reviewer_signoff_approved: false",
    "apply_candidate_authorized: false",
    "apply_readiness_gate_passed: false",
    "required_roles:",
    "primary_operator: required",
    "evidence_custodian: required",
    "required_packet_sections:",
    "terraform_plan_hash: required",
    "no_real_value_attestation: required",
    "required_signoffs:",
    "primary_operator_signoff: blocked",
    "no_real_value_capability_acknowledgement: blocked",
    "implementation_stages:",
    "stage_0_operator_packet_defined:",
    "stage_6_apply_readiness_re_evaluation_candidate:",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "phase5b_gke_operator_approval_packet_checked_in: true",
    "aggregate_phase5b_validator_includes_gke_operator_approval_packet: true"
)) {
    if ($gkeOperatorApprovalConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE operator approval packet config content: $expected"
    }
}

$phase5bWrapupConfig = Get-Content "config/phase5b-wrapup.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5b-wrapup-rc1",
    "status: gke_validator_ops_planning_complete",
    "inherits_from: phase5b-gke-operator-approval-packet-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "phase5a_baseline: phase5a-wrapup-rc1",
    "next_phase: phase6-gke-apply-candidate",
    "completed_release_candidates:",
    "phase5b_gke_cost_resource_plan_rc1: true",
    "phase5b_gke_terraform_design_plan_rc1: true",
    "phase5b_k8s_manifest_design_plan_rc1: true",
    "phase5b_k8s_render_dry_run_evidence_plan_rc1: true",
    "phase5b_gke_apply_readiness_gate_rc1: true",
    "phase5b_gke_operator_approval_packet_rc1: true",
    "phase_result:",
    "gke_validator_ops_planning_complete: true",
    "aggregate_phase5b_validator_coverage_complete: true",
    "phase5b_ready_to_close: true",
    "phase6_apply_candidate_deferred_until_explicit_approval: true",
    "phase6_handoff:",
    "handoff_allowed_only_after_explicit_approvals: true",
    "active_runtime_remains_no_gke_until_later_checkpoint: true",
    "remaining_blocked_gates:",
    "gke_resource_approval: blocked",
    "terraform_apply_approval: blocked",
    "operator_signoff_approval: blocked",
    "production_authorization: blocked",
    "real_value_settlement: blocked",
    "non_enablement:",
    "phase5b_wrapup_checked_in: true",
    "aggregate_phase5b_validator_includes_wrapup: true"
)) {
    if ($phase5bWrapupConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B wrap-up config content: $expected"
    }
}

$phase5aWrapup = Get-Content "config/phase5a-wrapup.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5a-wrapup-rc1",
    "status: no_gke_validator_hardening_complete",
    "next_phase: phase5b-gke-validator-ops",
    "phase5b_ready_for_planning: true",
    "phase5b_execution_deferred: true"
)) {
    if ($phase5aWrapup -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A handoff content: $expected"
    }
}

foreach ($forbidden in @(
    "apply_readiness_gate_passed",
    "operator_approval_packet_complete",
    "operator_signoff_approved",
    "reviewer_signoff_approved",
    "apply_candidate_authorized",
    "gke_apply_ready",
    "apply_window_approved",
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_plan_execution_approved_by_this_checkpoint",
    "terraform_apply_execution_approved_by_this_checkpoint",
    "kubernetes_apply_execution_approved_by_this_checkpoint",
    "terraform_apply_allowed",
    "terraform_gke_apply_allowed",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "cloud_billing_change_allowed",
    "gcloud_mutation_allowed",
    "gke_cluster_enabled",
    "gke_cluster_creation_enabled",
    "gke_node_pool_creation_enabled",
    "gke_resource_creation_allowed",
    "workload_identity_iam_mutation_enabled",
    "kubernetes_manifest_deployment_enabled",
    "kubectl_apply_allowed",
    "render_execution_enabled",
    "local_render_execution_approved_by_this_checkpoint",
    "client_dry_run_execution_approved_by_this_checkpoint",
    "server_dry_run_execution_approved_by_this_checkpoint",
    "kustomization_inclusion_allowed",
    "kubeconfig_mutation_allowed",
    "cluster_context_mutation_allowed",
    "live_validator_operations_enabled",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "hsm_kms_production_signing_enabled",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden"
    }
    if ($terraformDesignConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in Terraform design"
    }
    if ($k8sManifestDesignConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in Kubernetes manifest design"
    }
    if ($manifestDesignFile -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in Kubernetes manifest blueprint"
    }
    if ($k8sRenderDryRunEvidenceConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in render/dry-run evidence plan"
    }
    if ($renderDryRunEvidenceFile -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in render/dry-run evidence contract"
    }
    if ($gkeApplyReadinessConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in GKE apply-readiness gate"
    }
    if ($gkeOperatorApprovalConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in GKE operator approval packet"
    }
    if ($phase5bWrapupConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in Phase 5B wrap-up"
    }
}

$candidateProfileCount = ([regex]::Matches($config, "(?m)^\s{2}(lean_sandbox_standard_zonal|validator_ops_standard_multizone|autopilot_small_pod_request):\s*$")).Count
if ($candidateProfileCount -ne 3) {
    throw "Expected exactly 3 Phase 5B candidate resource profiles, found $candidateProfileCount"
}

$estimateInputCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($estimateInputCount -lt 19) {
    throw "Expected at least 19 Phase 5B estimate inputs, found $estimateInputCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 17) {
    throw "Expected at least 17 Phase 5B approval gates, found $blockedGateCount"
}

$blockedImplementationCount = ([regex]::Matches($config, "allowed_by_this_checkpoint:\s+false")).Count
if ($blockedImplementationCount -lt 5) {
    throw "Expected at least 5 blocked Phase 5B implementation steps, found $blockedImplementationCount"
}

$deferredGoogleResourceFamilyCount = ([regex]::Matches($terraformDesignConfig, "(?m)^\s{2}google_[a-z0-9_]+:\s+deferred\s*$")).Count
if ($deferredGoogleResourceFamilyCount -lt 10) {
    throw "Expected at least 10 deferred Phase 5B Google resource families, found $deferredGoogleResourceFamilyCount"
}

$deferredKubernetesResourceFamilyCount = ([regex]::Matches($terraformDesignConfig, "(?m)^\s{2}[A-Za-z0-9]+:\s+deferred\s*$")).Count
if ($deferredKubernetesResourceFamilyCount -lt 10) {
    throw "Expected at least 10 deferred Phase 5B Kubernetes resource families, found $deferredKubernetesResourceFamilyCount"
}

$requiredDesignSectionCount = ([regex]::Matches($terraformDesignConfig, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($requiredDesignSectionCount -lt 19) {
    throw "Expected at least 19 Phase 5B Terraform design sections, found $requiredDesignSectionCount"
}

$terraformDesignBlockedGateCount = ([regex]::Matches($terraformDesignConfig, ":\s+blocked")).Count
if ($terraformDesignBlockedGateCount -lt 18) {
    throw "Expected at least 18 Phase 5B Terraform design approval gates, found $terraformDesignBlockedGateCount"
}

$terraformDesignBlockedStageCount = ([regex]::Matches($terraformDesignConfig, "allowed_by_this_checkpoint:\s+false")).Count
if ($terraformDesignBlockedStageCount -lt 4) {
    throw "Expected at least 4 blocked Phase 5B Terraform implementation stages, found $terraformDesignBlockedStageCount"
}

$futureManifestComponentCount = ([regex]::Matches($k8sManifestDesignConfig, "(?m)^\s{2}[A-Za-z0-9]+:\s+deferred\s*$")).Count
if ($futureManifestComponentCount -lt 14) {
    throw "Expected at least 14 future Phase 5B Kubernetes manifest component families, found $futureManifestComponentCount"
}

$k8sRequiredDesignSectionCount = ([regex]::Matches($k8sManifestDesignConfig, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($k8sRequiredDesignSectionCount -lt 21) {
    throw "Expected at least 21 Phase 5B Kubernetes manifest design sections, found $k8sRequiredDesignSectionCount"
}

$k8sDesignBlockedGateCount = ([regex]::Matches($k8sManifestDesignConfig, ":\s+blocked")).Count
if ($k8sDesignBlockedGateCount -lt 24) {
    throw "Expected at least 24 Phase 5B Kubernetes manifest design approval gates, found $k8sDesignBlockedGateCount"
}

$k8sDesignBlockedStageCount = ([regex]::Matches($k8sManifestDesignConfig, "allowed_by_this_checkpoint:\s+false")).Count
if ($k8sDesignBlockedStageCount -lt 4) {
    throw "Expected at least 4 blocked Phase 5B Kubernetes manifest implementation stages, found $k8sDesignBlockedStageCount"
}

$renderDryRunEvidenceSectionCount = ([regex]::Matches($k8sRenderDryRunEvidenceConfig, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($renderDryRunEvidenceSectionCount -lt 31) {
    throw "Expected at least 31 Phase 5B render/dry-run evidence sections, found $renderDryRunEvidenceSectionCount"
}

$renderDryRunBlockedGateCount = ([regex]::Matches($k8sRenderDryRunEvidenceConfig, ":\s+blocked")).Count
if ($renderDryRunBlockedGateCount -lt 28) {
    throw "Expected at least 28 Phase 5B render/dry-run evidence gates, found $renderDryRunBlockedGateCount"
}

$renderDryRunBlockedStageCount = ([regex]::Matches($k8sRenderDryRunEvidenceConfig, "allowed_by_this_checkpoint:\s+false")).Count
if ($renderDryRunBlockedStageCount -lt 6) {
    throw "Expected at least 6 blocked Phase 5B render/dry-run execution stages, found $renderDryRunBlockedStageCount"
}

$applyReadinessEvidenceInputCount = ([regex]::Matches($gkeApplyReadinessConfig, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($applyReadinessEvidenceInputCount -lt 37) {
    throw "Expected at least 37 Phase 5B apply-readiness evidence inputs, found $applyReadinessEvidenceInputCount"
}

$applyReadinessBlockedGateCount = ([regex]::Matches($gkeApplyReadinessConfig, ":\s+blocked")).Count
if ($applyReadinessBlockedGateCount -lt 35) {
    throw "Expected at least 35 Phase 5B apply-readiness gates, found $applyReadinessBlockedGateCount"
}

$applyReadinessBlockedStageCount = ([regex]::Matches($gkeApplyReadinessConfig, "allowed_by_this_checkpoint:\s+false")).Count
if ($applyReadinessBlockedStageCount -lt 6) {
    throw "Expected at least 6 blocked Phase 5B apply-readiness stages, found $applyReadinessBlockedStageCount"
}

$operatorPacketRequiredCount = ([regex]::Matches($gkeOperatorApprovalConfig, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($operatorPacketRequiredCount -lt 52) {
    throw "Expected at least 52 Phase 5B operator approval required fields, found $operatorPacketRequiredCount"
}

$operatorPacketBlockedSignoffCount = ([regex]::Matches($gkeOperatorApprovalConfig, ":\s+blocked")).Count
if ($operatorPacketBlockedSignoffCount -lt 23) {
    throw "Expected at least 23 blocked Phase 5B operator approval signoffs, found $operatorPacketBlockedSignoffCount"
}

$operatorPacketBlockedStageCount = ([regex]::Matches($gkeOperatorApprovalConfig, "allowed_by_this_checkpoint:\s+false")).Count
if ($operatorPacketBlockedStageCount -lt 6) {
    throw "Expected at least 6 blocked Phase 5B operator approval stages, found $operatorPacketBlockedStageCount"
}

$phase5bWrapupCompletedCount = ([regex]::Matches($phase5bWrapupConfig, "phase5b_[a-z0-9_]+_rc1:\s+true")).Count
if ($phase5bWrapupCompletedCount -lt 6) {
    throw "Expected at least 6 completed Phase 5B release candidates, found $phase5bWrapupCompletedCount"
}

$phase5bWrapupBlockedGateCount = ([regex]::Matches($phase5bWrapupConfig, ":\s+blocked")).Count
if ($phase5bWrapupBlockedGateCount -lt 30) {
    throw "Expected at least 30 blocked Phase 5B wrap-up gates, found $phase5bWrapupBlockedGateCount"
}

$phase5bWrapupHandoffFocusCount = ([regex]::Matches($phase5bWrapupConfig, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($phase5bWrapupHandoffFocusCount -lt 8) {
    throw "Expected at least 8 Phase 5B wrap-up handoff focus items, found $phase5bWrapupHandoffFocusCount"
}

[pscustomobject]@{
    phase = "phase-5b-gke-validator-ops"
    release_candidate = "phase5b-wrapup-rc1"
    status = "gke-validator-ops-planning-complete"
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5a_baseline = "phase5a-wrapup-rc1"
    candidate_resource_profile_count = $candidateProfileCount
    estimate_input_count = $estimateInputCount
    blocked_approval_gate_count = $blockedGateCount
    blocked_implementation_step_count = $blockedImplementationCount
    terraform_design_plan_rc1 = $true
    deferred_google_resource_family_count = $deferredGoogleResourceFamilyCount
    deferred_kubernetes_resource_family_count = $deferredKubernetesResourceFamilyCount
    required_terraform_design_section_count = $requiredDesignSectionCount
    terraform_design_blocked_gate_count = $terraformDesignBlockedGateCount
    terraform_design_blocked_stage_count = $terraformDesignBlockedStageCount
    k8s_manifest_design_plan_rc1 = $true
    future_k8s_manifest_component_family_count = $futureManifestComponentCount
    required_k8s_manifest_design_section_count = $k8sRequiredDesignSectionCount
    k8s_manifest_design_blocked_gate_count = $k8sDesignBlockedGateCount
    k8s_manifest_design_blocked_stage_count = $k8sDesignBlockedStageCount
    k8s_render_dry_run_evidence_plan_rc1 = $true
    render_dry_run_required_evidence_section_count = $renderDryRunEvidenceSectionCount
    render_dry_run_blocked_gate_count = $renderDryRunBlockedGateCount
    render_dry_run_blocked_stage_count = $renderDryRunBlockedStageCount
    gke_apply_readiness_gate_rc1 = $true
    apply_readiness_required_evidence_input_count = $applyReadinessEvidenceInputCount
    apply_readiness_blocked_gate_count = $applyReadinessBlockedGateCount
    apply_readiness_blocked_stage_count = $applyReadinessBlockedStageCount
    gke_operator_approval_packet_rc1 = $true
    operator_packet_required_field_count = $operatorPacketRequiredCount
    operator_packet_blocked_signoff_count = $operatorPacketBlockedSignoffCount
    operator_packet_blocked_stage_count = $operatorPacketBlockedStageCount
    phase5b_wrapup_rc1 = $true
    completed_phase5b_release_candidate_count = $phase5bWrapupCompletedCount
    phase5b_wrapup_blocked_gate_count = $phase5bWrapupBlockedGateCount
    phase5b_wrapup_handoff_focus_count = $phase5bWrapupHandoffFocusCount
    phase5b_ready_to_close = $true
    next_phase = "phase6-gke-apply-candidate"
    operator_approval_packet_complete = $false
    operator_signoff_approved = $false
    reviewer_signoff_approved = $false
    apply_candidate_authorized = $false
    apply_readiness_gate_passed = $false
    gke_apply_ready = $false
    apply_window_approved = $false
    gke_enabled = $false
    gke_cluster_creation_enabled = $false
    gke_node_pool_creation_enabled = $false
    gke_resource_creation_allowed = $false
    workload_identity_iam_mutation_enabled = $false
    terraform_plan_execution_approved = $false
    terraform_apply_allowed = $false
    kubectl_apply_allowed = $false
    render_execution_enabled = $false
    client_dry_run_execution_enabled = $false
    server_dry_run_execution_enabled = $false
    kustomization_inclusion_allowed = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    google_cloud_resources_changed = $false
    production_authorization_enabled = $false
    legal_or_compliance_approval_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
