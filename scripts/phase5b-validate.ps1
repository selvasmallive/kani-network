$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE5B_GKE_COST_RESOURCE_PLAN.md",
    "PHASE5B_GKE_TERRAFORM_DESIGN_PLAN.md",
    "config/phase5b-gke-cost-resource-plan.yaml",
    "config/phase5b-gke-terraform-design-plan.yaml",
    "infra/terraform/phase5b_gke_terraform_design_plan.tf",
    "scripts/phase5b-gke-cost-resource-plan.ps1",
    "scripts/phase5b-gke-terraform-design-plan.ps1",
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
        throw "Phase 5B aggregate validator must not allow $forbidden"
    }
    if ($terraformDesignConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B aggregate validator must not allow $forbidden in Terraform design"
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

[pscustomobject]@{
    phase = "phase-5b-gke-validator-ops"
    release_candidate = "phase5b-gke-cost-resource-plan-rc1"
    status = "gke-cost-resource-planning-ready"
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
    gke_enabled = $false
    gke_cluster_creation_enabled = $false
    gke_node_pool_creation_enabled = $false
    gke_resource_creation_allowed = $false
    workload_identity_iam_mutation_enabled = $false
    terraform_apply_allowed = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    google_cloud_resources_changed = $false
    production_authorization_enabled = $false
    legal_or_compliance_approval_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
