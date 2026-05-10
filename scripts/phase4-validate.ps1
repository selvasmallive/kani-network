$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE4_PRE_PRODUCTION_READINESS.md",
    "PHASE4_COST_MODEL.md",
    "config/phase4-pre-production-readiness.yaml",
    "config/phase4-cost-model.yaml",
    "scripts/phase4-validate.ps1",
    "scripts/phase4-cost-model.ps1",
    "PHASE3_WRAPUP.md",
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
    throw "Missing Phase 4 readiness files: $($missing -join ', ')"
}

$plan = Get-Content "PHASE4_PRE_PRODUCTION_READINESS.md" -Raw
foreach ($expected in @(
    "Status: readiness planning started",
    "phase4-pre-production-readiness-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase4-no-gke-preprod-readiness",
    "GKE remains deferred",
    "phase5b-gke-validator-ops",
    "phase2-lean-no-gke",
    "Cloud Run Job plus Cloud Scheduler",
    "No GKE cluster creation",
    "Readiness Gates",
    "legal_classification_review",
    "production_cost_estimate_review",
    "terraform_plan_review",
    "executive_go_live_approval",
    "Cost Gate",
    "Phase 5 Split",
    "phase5a-no-gke-validator-hardening",
    "phase5b-gke-validator-ops",
    "Non-Enablement",
    "GKE cluster creation",
    "Real-value settlement",
    "No Google Cloud resources are created",
    "No paid production-style resources are enabled"
)) {
    if ($plan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 readiness plan content: $expected"
    }
}

$costModel = Get-Content "PHASE4_COST_MODEL.md" -Raw
foreach ($expected in @(
    "Status: cost model ready",
    "phase4-cost-model-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Cost Model Principle",
    "Current No-GKE Baseline",
    "Deferred Production-Style Estimates",
    "GKE validator operations estimate",
    "Scenario Matrix",
    "preprod_no_gke",
    "validator_ops_gke_lab",
    "Approval Gates",
    "phase5b-gke-validator-ops",
    "Phase 5A remains no-GKE",
    "No Google Cloud resources are created or changed"
)) {
    if ($costModel -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 cost model content: $expected"
    }
}

$config = Get-Content "config/phase4-pre-production-readiness.yaml" -Raw
foreach ($expected in @(
    "phase: phase-4-pre-production-readiness",
    "release_candidate: phase4-pre-production-readiness-rc1",
    "status: readiness_planning_started",
    "inherits_from: phase3-wrapup-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "enables_gke_validator_operations: false",
    "enables_hsm_or_kms_signing: false",
    "enables_production_ingress: false",
    "enables_real_value_settlement: false",
    "authorizes_external_institution_onboarding: false",
    "id: phase2-lean-no-gke",
    "validator_runtime: cloud_run_job_plus_cloud_scheduler",
    "gke_enabled: false",
    "readiness_gates:",
    "legal_classification_review:",
    "registration_and_msb_analysis:",
    "aml_kyc_program_review:",
    "sanctions_screening_review:",
    "privacy_and_data_retention_review:",
    "custody_and_safeguarding_review:",
    "institution_agreement_review:",
    "security_architecture_review:",
    "penetration_test_scope:",
    "incident_response_and_dr_review:",
    "production_cost_estimate_review:",
    "terraform_plan_review:",
    "executive_go_live_approval:",
    "status: blocked",
    "required_before_paid_resource_apply: true",
    "required_before_gke_apply: true",
    "gke_estimate_separate: true",
    "future_gke_validator_operations",
    "phase5a_no_gke_validator_hardening:",
    "gke_required: false",
    "phase5b_gke_validator_ops:",
    "gke_required: true",
    "gke_cluster_enabled: false",
    "production_bft_validator_network_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "external_institution_onboarding_enabled: false",
    "real_value_settlement_enabled: false",
    "production_go_live_allowed: false",
    "no_google_cloud_resources_created: true",
    "no_paid_production_resources_enabled: true",
    "no_gke_enabled: true",
    "no_real_value_capability_enabled: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 readiness config content: $expected"
    }
}

$costConfig = Get-Content "config/phase4-cost-model.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-cost-model-rc1",
    "status: cost_model_ready",
    "inherits_from: phase4-pre-production-readiness-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "enables_gke_validator_operations: false",
    "fixed_live_prices_recorded: false",
    "live_pricing_must_be_checked_before_apply: true",
    "current_no_gke_baseline:",
    "cloud_run_api:",
    "cloud_run_validator_job:",
    "cloud_sql_postgresql_ledger:",
    "deferred_estimates:",
    "production_ingress:",
    "hsm_kms_signing:",
    "gke_validator_operations:",
    "deferred_to: phase5b-gke-validator-ops",
    "scenario_matrix:",
    "sandbox_minimal:",
    "preprod_no_gke:",
    "validator_ops_gke_lab:",
    "approval_gates:",
    "phase5a_remains_no_gke: true",
    "google_cloud_resource_creation_allowed: false",
    "paid_resource_enablement_allowed: false",
    "gke_cluster_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_cost_model: true"
)) {
    if ($costConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 cost model config content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_production_ingress",
    "enables_real_value_settlement",
    "authorizes_external_institution_onboarding",
    "gke_enabled",
    "gke_cluster_enabled",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "cloud_armor_waf_applied",
    "mtls_trust_config_applied",
    "hsm_kms_production_signing_enabled",
    "external_institution_onboarding_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 readiness must not enable $forbidden"
    }
    if ($costConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 cost model must not enable $forbidden"
    }
}

if ($costConfig -match "(?m)^\s*terraform_apply_allowed:\s+true\s*$") {
    throw "Phase 4 cost model must not allow Terraform apply"
}

if ($costConfig -match "(?m)^\s*fixed_live_prices_recorded:\s+true\s*$") {
    throw "Phase 4 cost model must not record fixed live prices"
}

$gateCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($gateCount -lt 13) {
    throw "Expected at least 13 readiness gates, found $gateCount"
}

[pscustomobject]@{
    phase = "phase-4-pre-production-readiness"
    release_candidate = "phase4-pre-production-readiness-rc1"
    status = "readiness-planning-started"
    track = "phase4-no-gke-preprod-readiness"
    readiness_gate_count = 13
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    gke_enabled = $false
    hsm_kms_signing_enabled = $false
    production_ingress_enabled = $false
    real_value_capability_enabled = $false
    phase5a_no_gke_available = $true
    phase5b_gke_deferred = $true
    cost_model_rc1 = $true
    result = "ok"
}
