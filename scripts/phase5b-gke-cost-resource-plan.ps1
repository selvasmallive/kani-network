$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_GKE_COST_RESOURCE_PLAN.md"
$configPath = "config/phase5b-gke-cost-resource-plan.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
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
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5B GKE cost/resource planning artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: GKE cost and resource planning checkpoint ready",
    "phase5b-gke-cost-resource-plan-rc1",
    "phase5b-gke-validator-ops",
    "phase5a-wrapup-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Pricing Source Inputs",
    "Google Cloud Pricing Calculator",
    "GKE cluster management fee input",
    "Candidate Resource Profiles",
    "lean_sandbox_standard_zonal",
    "validator_ops_standard_multizone",
    "autopilot_small_pod_request",
    "Required Estimate Inputs",
    "Required Approval Gates",
    "billing_account_confirmed",
    "pricing_calculator_estimate_saved",
    "terraform_apply_window_approved",
    "Implementation Plan",
    "apply_gke_resources",
    "deploy_validator_manifests",
    "Non-Enablement",
    "GKE cluster creation",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5B GKE cost/resource plan doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5b-gke-cost-resource-plan-rc1",
    "status: gke_cost_resource_planning_checkpoint_ready",
    "inherits_from: phase5a-wrapup-rc1",
    "track: phase5b-gke-validator-ops",
    "active_runtime_baseline: phase2-lean-no-gke",
    "phase5a_baseline: phase5a-wrapup-rc1",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "pricing_inputs:",
    "source: official_google_cloud_gke_pricing_and_pricing_calculator",
    "captured_date: 2026-05-10",
    "cluster_management_fee_usd_per_cluster_hour: 0.10",
    "monthly_free_tier_credit_usd: 74.40",
    "free_tier_applies_to:",
    "autopilot_clusters",
    "zonal_standard_clusters",
    "free_tier_excludes:",
    "compute_charges",
    "regional_cluster_fee",
    "standard_node_pool_billing: compute_engine_instances_until_deleted",
    "autopilot_general_purpose_billing: pod_resource_requests",
    "operator_must_recalculate_in_pricing_calculator: true",
    "candidate_resource_profiles:",
    "lean_sandbox_standard_zonal:",
    "validator_ops_standard_multizone:",
    "autopilot_small_pod_request:",
    "cluster_mode: standard_zonal",
    "cluster_mode: standard_multizone",
    "cluster_mode: autopilot",
    "region: northamerica-northeast1",
    "min_nodes: 1",
    "max_nodes: 3",
    "min_nodes: 3",
    "max_nodes: 6",
    "validator_replicas: 3",
    "creation_allowed_by_this_checkpoint: false",
    "required_estimate_inputs:",
    "billing_account_and_project: required",
    "expected_monthly_runtime_hours: required",
    "teardown_owner_and_command_plan: required",
    "required_approval_gates:",
    "billing_account_confirmed: blocked",
    "pricing_calculator_estimate_saved: blocked",
    "terraform_apply_window_approved: blocked",
    "no_real_value_capability_enabled: blocked",
    "implementation_plan:",
    "estimate_profiles:",
    "allowed_by_this_checkpoint: true",
    "apply_gke_resources:",
    "allowed_by_this_checkpoint: false",
    "deploy_validator_manifests:",
    "run_gke_smoke_tests:",
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

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "terraform_gke_apply_allowed",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "gke_cluster_enabled",
    "gke_resource_creation_allowed",
    "kubernetes_manifest_deployment_enabled",
    "live_validator_operations_enabled",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "cloud_armor_waf_applied",
    "mtls_trust_config_applied",
    "hsm_kms_production_signing_enabled",
    "scheduler_changes_enabled",
    "automatic_scheduler_mutation_enabled",
    "manual_scheduler_action_approved_by_this_checkpoint",
    "cloud_run_job_execution_approved_by_this_checkpoint",
    "secret_rotation_approved_by_this_checkpoint",
    "cloud_smoke_execution_approved_by_this_checkpoint",
    "local_smoke_execution_approved_by_this_checkpoint",
    "live_sandbox_smoke_execution_enabled",
    "destructive_smoke_reset_enabled",
    "external_endpoint_smoke_enabled",
    "failure_injection_enabled",
    "live_failure_drills_enabled",
    "live_retry_drills_enabled",
    "live_recovery_drills_enabled",
    "live_drill_execution_approved_by_this_checkpoint",
    "production_replay_enabled",
    "restore_drill_executed",
    "production_recovery_executed",
    "external_evidence_export_enabled",
    "production_approval_via_evidence_pack_enabled",
    "external_institution_onboarding_enabled",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5B GKE cost/resource plan must not enable $forbidden"
    }
}

$profileCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($profileCount -lt 3) {
    throw "Expected at least 3 candidate GKE resource profiles, found $profileCount"
}

$estimateInputCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($estimateInputCount -lt 19) {
    throw "Expected at least 19 required estimate inputs, found $estimateInputCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 17) {
    throw "Expected at least 17 blocked Phase 5B approval gates, found $blockedGateCount"
}

$implementationStepCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($implementationStepCount -lt 9) {
    throw "Expected at least 9 Phase 5B implementation plan steps, found $implementationStepCount"
}

[pscustomobject]@{
    release_candidate = "phase5b-gke-cost-resource-plan-rc1"
    status = "gke_cost_resource_planning_checkpoint_ready"
    track = "phase5b-gke-validator-ops"
    active_runtime_baseline = "phase2-lean-no-gke"
    phase5a_baseline = "phase5a-wrapup-rc1"
    candidate_resource_profile_count = 3
    required_estimate_input_count = $estimateInputCount
    blocked_approval_gate_count = $blockedGateCount
    implementation_step_count = 9
    cluster_management_fee_usd_per_cluster_hour = "0.10"
    monthly_free_tier_credit_usd = "74.40"
    operator_must_recalculate_in_pricing_calculator = $true
    gke_enabled = $false
    gke_resource_creation_allowed = $false
    terraform_apply_allowed = $false
    kubernetes_manifest_deployment_enabled = $false
    live_validator_operations_enabled = $false
    google_cloud_resources_changed = $false
    production_authorization_enabled = $false
    legal_or_compliance_approval_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
