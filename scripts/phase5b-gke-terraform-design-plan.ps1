$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_GKE_TERRAFORM_DESIGN_PLAN.md"
$configPath = "config/phase5b-gke-terraform-design-plan.yaml"
$terraformPath = "infra/terraform/phase5b_gke_terraform_design_plan.tf"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    $terraformPath,
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
    throw "Missing Phase 5B GKE Terraform design artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: GKE Terraform design plan ready",
    "phase5b-gke-terraform-design-plan-rc1",
    "phase5b-gke-cost-resource-plan-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Terraform Boundary",
    "infra/terraform/phase5b_gke_terraform_design_plan.tf",
    'phase5b_gke_terraform_design_enabled = false',
    'Declare no `resource "google_*"` blocks',
    "Design Objective",
    "Deferred Terraform Resource Families",
    "google_container_cluster",
    "google_container_node_pool",
    "Deferred Kubernetes Resource Families",
    "PodDisruptionBudget",
    "Required Design Sections",
    "workload_identity_model",
    "Required Review Gates",
    "terraform_plan_reviewed",
    "Implementation Stages",
    "stage_4_apply_candidate",
    "Non-Enablement",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE Terraform design doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-gke-terraform-design-plan-rc1",
    "status: gke_terraform_design_plan_ready",
    "inherits_from: phase5b-gke-cost-resource-plan-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "terraform_design_file: infra/terraform/phase5b_gke_terraform_design_plan.tf",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
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
    "region: northamerica-northeast1",
    "cluster_name: kani-sandbox-gke-validator",
    "node_machine_type: e2-small",
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
    "no_real_value_capability_enabled: blocked",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_4_apply_candidate:",
    "allowed_by_this_checkpoint: false",
    "non_enablement:",
    "gke_cluster_creation_enabled: false",
    "gke_node_pool_creation_enabled: false",
    "workload_identity_iam_mutation_enabled: false",
    "phase5b_gke_terraform_design_plan_checked_in: true",
    "aggregate_phase5b_validator_includes_gke_terraform_design_plan: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE Terraform design config content: $expected"
    }
}

$terraform = Get-Content $terraformPath -Raw
foreach ($expected in @(
    'variable "phase5b_gke_terraform_design_enabled"',
    'default     = false',
    "phase5b-gke-terraform-design-plan-rc1 is design-only",
    'variable "phase5b_gke_selected_profile"',
    "lean_sandbox_standard_zonal",
    "validator_ops_standard_multizone",
    "autopilot_small_pod_request",
    'local.phase5b_gke_terraform_design_plan',
    "google_container_cluster",
    "google_container_node_pool",
    "PodDisruptionBudget",
    'output "phase5b_gke_terraform_design_plan"'
)) {
    if ($terraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE Terraform design file content: $expected"
    }
}

if ($terraform -match '(?m)^\s*resource\s+"(google|kubernetes)_') {
    throw "Phase 5B GKE Terraform design file must not declare google_* or kubernetes_* resources"
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "terraform_gke_apply_allowed",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "gke_cluster_enabled",
    "gke_cluster_creation_enabled",
    "gke_node_pool_creation_enabled",
    "gke_resource_creation_allowed",
    "workload_identity_iam_mutation_enabled",
    "kubernetes_manifest_deployment_enabled",
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
        throw "Phase 5B GKE Terraform design must not enable $forbidden"
    }
}

$deferredGoogleCount = ([regex]::Matches($config, "(?m)^\s{2}google_[a-z0-9_]+:\s+deferred\s*$")).Count
if ($deferredGoogleCount -lt 10) {
    throw "Expected at least 10 deferred Google resource families, found $deferredGoogleCount"
}

$deferredKubernetesCount = ([regex]::Matches($config, "(?m)^\s{2}[A-Za-z0-9]+:\s+deferred\s*$")).Count
if ($deferredKubernetesCount -lt 10) {
    throw "Expected at least 10 deferred Kubernetes resource families, found $deferredKubernetesCount"
}

$designSectionCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($designSectionCount -lt 19) {
    throw "Expected at least 19 required design sections, found $designSectionCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 18) {
    throw "Expected at least 18 blocked Phase 5B Terraform design gates, found $blockedGateCount"
}

$blockedStageCount = ([regex]::Matches($config, "allowed_by_this_checkpoint:\s+false")).Count
if ($blockedStageCount -lt 4) {
    throw "Expected at least 4 blocked Phase 5B Terraform implementation stages, found $blockedStageCount"
}

[pscustomobject]@{
    release_candidate = "phase5b-gke-terraform-design-plan-rc1"
    status = "gke_terraform_design_plan_ready"
    track = "phase5b-gke-validator-ops"
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5b_cost_resource_baseline = "phase5b-gke-cost-resource-plan-rc1"
    terraform_design_file = $terraformPath
    deferred_google_resource_family_count = $deferredGoogleCount
    deferred_kubernetes_resource_family_count = $deferredKubernetesCount
    required_design_section_count = $designSectionCount
    blocked_review_gate_count = $blockedGateCount
    blocked_implementation_stage_count = $blockedStageCount
    design_only_terraform_guard_enabled = $false
    gke_enabled = $false
    gke_node_pool_creation_enabled = $false
    workload_identity_iam_mutation_enabled = $false
    terraform_apply_allowed = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    google_cloud_resources_changed = $false
    production_authorization_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
