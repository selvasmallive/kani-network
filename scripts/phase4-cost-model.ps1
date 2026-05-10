$ErrorActionPreference = "Stop"

$docPath = "PHASE4_COST_MODEL.md"
$configPath = "config/phase4-cost-model.yaml"

foreach ($file in @($docPath, $configPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 4 cost model artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: cost model ready",
    "phase4-cost-model-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Cost Model Principle",
    "Google Cloud Pricing Calculator",
    "Current No-GKE Baseline",
    "Cloud Run API service",
    "Cloud Run validator job",
    "Cloud SQL PostgreSQL ledger instance",
    "Deferred Production-Style Estimates",
    "Production ingress estimate",
    "HSM/KMS signing estimate",
    "GKE validator operations estimate",
    "Scenario Matrix",
    "sandbox_minimal",
    "preprod_no_gke",
    "validator_ops_gke_lab",
    "Approval Gates",
    'GKE remains deferred to `phase5b-gke-validator-ops`',
    "Phase 5A remains no-GKE",
    "Terraform apply",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 cost model doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase4-cost-model-rc1",
    "status: cost_model_ready",
    "inherits_from: phase4-pre-production-readiness-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "enables_gke_validator_operations: false",
    "enables_hsm_or_kms_signing: false",
    "enables_production_ingress: false",
    "enables_real_value_settlement: false",
    "fixed_live_prices_recorded: false",
    "live_pricing_must_be_checked_before_apply: true",
    "google_cloud_pricing_calculator",
    "current_no_gke_baseline:",
    "cloud_run_api:",
    "cloud_run_validator_job:",
    "cloud_sql_postgresql_ledger:",
    "cloud_monitoring_logging_alerting:",
    "deferred_estimates:",
    "production_ingress:",
    "hsm_kms_signing:",
    "gke_validator_operations:",
    "deferred_to: phase5b-gke-validator-ops",
    "scenario_matrix:",
    "sandbox_minimal:",
    "preprod_no_gke:",
    "validator_ops_gke_lab:",
    "validator_ops_gke_realistic:",
    "approval_gates:",
    "finance_owner_review_required: true",
    "terraform_plan_review_required: true",
    "regulatory_gate_override_allowed: false",
    "real_value_override_allowed: false",
    "phase5a_remains_no_gke: true",
    "google_cloud_resource_creation_allowed: false",
    "paid_resource_enablement_allowed: false",
    "gke_cluster_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "external_institution_onboarding_enabled: false",
    "real_value_settlement_enabled: false",
    "production_go_live_allowed: false",
    "phase4_validator_includes_cost_model: true",
    "no_google_cloud_resources_created: true",
    "no_gke_enabled: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 cost model config content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_production_ingress",
    "enables_real_value_settlement",
    "authorizes_external_institution_onboarding",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "gke_cluster_enabled",
    "production_ingress_enabled",
    "hsm_kms_production_signing_enabled",
    "external_institution_onboarding_enabled",
    "real_value_settlement_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 cost model must not enable $forbidden"
    }
}

if ($config -match "(?m)^\s*fixed_live_prices_recorded:\s+true\s*$") {
    throw "Phase 4 cost model must not record fixed live prices"
}

$scenarioCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($scenarioCount -lt 7) {
    throw "Expected at least 7 cost scenarios, found $scenarioCount"
}

[pscustomobject]@{
    release_candidate = "phase4-cost-model-rc1"
    status = "cost_model_ready"
    track = "phase4-no-gke-preprod-readiness"
    fixed_live_prices_recorded = $false
    cost_scenario_count = 7
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    terraform_apply_allowed = $false
    gke_enabled = $false
    hsm_kms_signing_enabled = $false
    production_ingress_enabled = $false
    real_value_capability_enabled = $false
    phase5a_no_gke_available = $true
    phase5b_gke_deferred = $true
    result = "ok"
}
