$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_GKE_APPLY_READINESS_GATE.md"
$configPath = "config/phase5b-gke-apply-readiness-gate.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5B_K8S_RENDER_DRY_RUN_EVIDENCE_PLAN.md",
    "config/phase5b-k8s-render-dry-run-evidence-plan.yaml",
    "k8s/phase5b-render-dry-run-evidence-plan.yaml",
    "scripts/phase5b-k8s-render-dry-run-evidence-plan.ps1",
    "PHASE5B_K8S_MANIFEST_DESIGN_PLAN.md",
    "config/phase5b-k8s-manifest-design-plan.yaml",
    "k8s/phase5b-validator-manifest-design.yaml",
    "scripts/phase5b-k8s-manifest-design-plan.ps1",
    "PHASE5B_GKE_TERRAFORM_DESIGN_PLAN.md",
    "config/phase5b-gke-terraform-design-plan.yaml",
    "infra/terraform/phase5b_gke_terraform_design_plan.tf",
    "scripts/phase5b-gke-terraform-design-plan.ps1",
    "PHASE5B_GKE_COST_RESOURCE_PLAN.md",
    "config/phase5b-gke-cost-resource-plan.yaml",
    "scripts/phase5b-gke-cost-resource-plan.ps1",
    "PHASE5A_WRAPUP.md",
    "config/phase5a-wrapup.yaml",
    "scripts/phase5a-validate.ps1"
)

$missing = @()
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5B GKE apply-readiness gate artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: GKE apply-readiness gate defined and blocked",
    "phase5b-gke-apply-readiness-gate-rc1",
    "phase5b-k8s-render-dry-run-evidence-plan-rc1",
    "phase5b-gke-validator-ops",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Gate Outcome",
    "apply_readiness_gate_state = BLOCKED",
    "gke_apply_ready = FALSE",
    "terraform_apply_allowed = FALSE",
    "kubectl_apply_allowed = FALSE",
    "Required Baselines",
    "Required Evidence Inputs",
    "terraform_plan_artifact_attached",
    "server_dry_run_reviewed",
    "Required Review Gates",
    "terraform_apply_window_approved",
    "Implementation Stages",
    "stage_7_kubernetes_apply_candidate",
    "Non-Enablement",
    "No Terraform plan, Terraform apply, render, dry-run"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE apply-readiness gate doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
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
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
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
    "allowed_by_this_checkpoint: false",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "gcloud_mutation_allowed: false",
    "phase5b_gke_apply_readiness_gate_checked_in: true",
    "aggregate_phase5b_validator_includes_gke_apply_readiness_gate: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE apply-readiness gate config content: $expected"
    }
}

foreach ($forbidden in @(
    "apply_readiness_gate_passed",
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
        throw "Phase 5B GKE apply-readiness gate must not enable $forbidden"
    }
}

$requiredBaselineCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($requiredBaselineCount -lt 5) {
    throw "Expected at least 5 required Phase 5B apply-readiness baselines, found $requiredBaselineCount"
}

$requiredEvidenceInputCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($requiredEvidenceInputCount -lt 37) {
    throw "Expected at least 37 required Phase 5B apply-readiness evidence inputs, found $requiredEvidenceInputCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 35) {
    throw "Expected at least 35 blocked Phase 5B apply-readiness gates, found $blockedGateCount"
}

$blockedStageCount = ([regex]::Matches($config, "allowed_by_this_checkpoint:\s+false")).Count
if ($blockedStageCount -lt 6) {
    throw "Expected at least 6 blocked Phase 5B apply stages, found $blockedStageCount"
}

[pscustomobject]@{
    release_candidate = "phase5b-gke-apply-readiness-gate-rc1"
    status = "gke_apply_readiness_gate_defined_and_blocked"
    track = "phase5b-gke-validator-ops"
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5b_render_dry_run_baseline = "phase5b-k8s-render-dry-run-evidence-plan-rc1"
    required_evidence_input_count = $requiredEvidenceInputCount
    blocked_review_gate_count = $blockedGateCount
    blocked_apply_stage_count = $blockedStageCount
    apply_readiness_gate_passed = $false
    gke_apply_ready = $false
    apply_window_approved = $false
    terraform_plan_execution_approved = $false
    terraform_apply_allowed = $false
    kubectl_apply_allowed = $false
    gcloud_mutation_allowed = $false
    gke_enabled = $false
    gke_node_pool_creation_enabled = $false
    workload_identity_iam_mutation_enabled = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    google_cloud_resources_changed = $false
    kubernetes_resources_deployed = $false
    production_authorization_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
