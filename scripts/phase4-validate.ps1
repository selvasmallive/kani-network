$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE4_PRE_PRODUCTION_READINESS.md",
    "PHASE4_COST_MODEL.md",
    "PHASE4_SECURITY_REVIEW_SCOPE.md",
    "PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md",
    "PHASE4_PROD_INGRESS_IMPLEMENTATION_PLAN.md",
    "config/phase4-pre-production-readiness.yaml",
    "config/phase4-cost-model.yaml",
    "config/phase4-security-review-scope.yaml",
    "config/phase4-hsm-kms-implementation-plan.yaml",
    "config/phase4-prod-ingress-implementation-plan.yaml",
    "scripts/phase4-validate.ps1",
    "scripts/phase4-cost-model.ps1",
    "scripts/phase4-security-review-scope.ps1",
    "scripts/phase4-hsm-kms-implementation-plan.ps1",
    "scripts/phase4-prod-ingress-implementation-plan.ps1",
    "infra/terraform/phase4_hsm_kms_implementation_plan.tf",
    "infra/terraform/phase4_prod_ingress_implementation_plan.tf",
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

$securityScope = Get-Content "PHASE4_SECURITY_REVIEW_SCOPE.md" -Raw
foreach ($expected in @(
    "Status: security scope ready",
    "phase4-security-review-scope-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Review Objectives",
    "In-Scope Assets",
    "Out-Of-Scope Until Explicit Approval",
    "Threat Areas",
    "Test Evidence Requirements",
    "Required Review Workstreams",
    "api_authorization_review",
    "deferred_gke_hsm_ingress_review",
    "Penetration test execution",
    "Production target testing",
    "No Google Cloud resources are created or changed"
)) {
    if ($securityScope -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 security review scope content: $expected"
    }
}

$hsmKmsPlan = Get-Content "PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md" -Raw
foreach ($expected in @(
    "Status: implementation plan ready",
    "phase4-hsm-kms-implementation-plan-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Target Signing Purposes",
    "validator_block_signing",
    "treasury_asset_authority",
    "Implementation Stages",
    "stage_0_design_only",
    "stage_2_kms_mock_adapter",
    "Signing Request Contract",
    "Raw private keys must never leave managed custody",
    "Required Gates Before Apply",
    "Terraform Boundary",
    "phase4_hsm_kms_implementation_enabled = false",
    'Declare no `resource "google_*"` blocks',
    "No Google Cloud resources are created or changed"
)) {
    if ($hsmKmsPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS implementation plan content: $expected"
    }
}

$prodIngressPlan = Get-Content "PHASE4_PROD_INGRESS_IMPLEMENTATION_PLAN.md" -Raw
foreach ($expected in @(
    "Status: implementation plan ready",
    "phase4-prod-ingress-implementation-plan-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Implementation Objective",
    "This plan is not an approval to enable production ingress",
    "Target Components",
    "external_https_load_balancer_or_api_gateway_decision",
    "serverless_neg_to_cloud_run_api",
    "certificate_manager_tls_certificate",
    "certificate_manager_trust_config",
    "institution_mtls",
    "cloud_armor_waf",
    "admin_oidc",
    "private_cloud_run_ingress",
    "Request Paths",
    "institution_api_path",
    "admin_api_path",
    "validator_internal_path",
    "health_path",
    "Implementation Stages",
    "stage_0_design_only",
    "stage_3_mtls_trust_design",
    "Required Gates Before Apply",
    "DNS owner approval recorded",
    "Cloud Armor policy reviewed",
    "Terraform Boundary",
    "phase4_prod_ingress_implementation_enabled = false",
    'Declare no `resource "google_*"` blocks',
    "allUsers",
    "allAuthenticatedUsers",
    "Public endpoint exposure",
    "No Google Cloud resources are created or changed"
)) {
    if ($prodIngressPlan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress implementation plan content: $expected"
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

$securityConfig = Get-Content "config/phase4-security-review-scope.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-security-review-scope-rc1",
    "status: security_scope_ready",
    "inherits_from: phase4-cost-model-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "penetration_test_execution_allowed: false",
    "production_target_testing_allowed: false",
    "external_institution_testing_allowed: false",
    "enables_gke_validator_operations: false",
    "enables_public_endpoint_exposure: false",
    "review_objectives:",
    "gke_deferred_to_phase5b_confirmation",
    "in_scope_assets:",
    "out_of_scope:",
    "threat_areas:",
    "test_evidence_requirements:",
    "forbidden_evidence:",
    "review_workstreams:",
    "api_authorization_review:",
    "deferred_gke_hsm_ingress_review:",
    "google_cloud_resource_creation_allowed: false",
    "gke_cluster_enabled: false",
    "public_endpoint_exposure_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_security_scope: true"
)) {
    if ($securityConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 security review scope config content: $expected"
    }
}

$hsmKmsConfig = Get-Content "config/phase4-hsm-kms-implementation-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-hsm-kms-implementation-plan-rc1",
    "status: implementation_plan_ready",
    "inherits_from: phase4-security-review-scope-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "creates_kms_key_ring: false",
    "creates_kms_crypto_key: false",
    "creates_hsm_key: false",
    "deploys_signing_service: false",
    "enables_kms_hsm_signing: false",
    "target_signing_purposes:",
    "validator_block_signing:",
    "treasury_asset_authority:",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_6_production_candidate:",
    "signing_request_contract:",
    "private_keys_exportable: false",
    "key_lifecycle:",
    "required_gates_before_apply:",
    "terraform_boundary:",
    "design_file: infra/terraform/phase4_hsm_kms_implementation_plan.tf",
    "guard_variable: phase4_hsm_kms_implementation_enabled",
    "declares_google_cloud_resources: false",
    "output_only: true",
    "kms_key_ring_created: false",
    "signing_service_deployed: false",
    "phase4_validator_includes_hsm_kms_plan: true"
)) {
    if ($hsmKmsConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS implementation plan config content: $expected"
    }
}

$prodIngressConfig = Get-Content "config/phase4-prod-ingress-implementation-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase4-prod-ingress-implementation-plan-rc1",
    "status: implementation_plan_ready",
    "inherits_from: phase4-hsm-kms-implementation-plan-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "creates_external_https_load_balancer: false",
    "creates_api_gateway: false",
    "creates_reserved_static_ip: false",
    "creates_dns_record: false",
    "creates_certificate_manager_certificate: false",
    "creates_certificate_manager_trust_config: false",
    "applies_cloud_armor_policy: false",
    "changes_cloud_run_ingress: false",
    "enables_institution_mtls: false",
    "enables_public_endpoint_exposure: false",
    "target_components:",
    "external_https_load_balancer_or_api_gateway_decision:",
    "serverless_neg_to_cloud_run_api:",
    "certificate_manager_tls_certificate:",
    "certificate_manager_trust_config:",
    "institution_mtls:",
    "cloud_armor_waf:",
    "admin_oidc:",
    "private_cloud_run_ingress:",
    "request_paths:",
    "institution_api_path:",
    "admin_api_path:",
    "validator_internal_path:",
    "health_path:",
    "implementation_stages:",
    "stage_0_design_only:",
    "stage_6_production_candidate:",
    "required_gates_before_apply:",
    "terraform_boundary:",
    "design_file: infra/terraform/phase4_prod_ingress_implementation_plan.tf",
    "guard_variable: phase4_prod_ingress_implementation_enabled",
    "guard_default: false",
    "declares_google_cloud_resources: false",
    "output_only: true",
    "iam_boundary:",
    "allUsers",
    "allAuthenticatedUsers",
    "external_https_load_balancer_created: false",
    "api_gateway_created: false",
    "dns_record_created: false",
    "certificate_manager_certificate_created: false",
    "certificate_manager_trust_config_created: false",
    "institution_mtls_enabled: false",
    "cloud_armor_waf_applied: false",
    "cloud_run_ingress_changed: false",
    "public_endpoint_exposure_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_prod_ingress_plan: true"
)) {
    if ($prodIngressConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress implementation plan config content: $expected"
    }
}

$hsmKmsTerraform = Get-Content "infra/terraform/phase4_hsm_kms_implementation_plan.tf" -Raw
foreach ($expected in @(
    'variable "phase4_hsm_kms_implementation_enabled"',
    "default     = false",
    "phase4-hsm-kms-implementation-plan-rc1",
    "creates_paid_resources         = false",
    "changes_google_cloud_resources = false",
    "production_signing_enabled     = false",
    "validator_block_signing",
    "treasury_asset_authority",
    "stage_0_design_only",
    "google_kms_key_ring",
    'output "phase4_hsm_kms_implementation_plan"'
)) {
    if ($hsmKmsTerraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS Terraform design content: $expected"
    }
}

$prodIngressTerraform = Get-Content "infra/terraform/phase4_prod_ingress_implementation_plan.tf" -Raw
foreach ($expected in @(
    'variable "phase4_prod_ingress_implementation_enabled"',
    "default     = false",
    "phase4-prod-ingress-implementation-plan-rc1",
    "active_runtime_baseline        = `"phase2-lean-no-gke`"",
    "creates_paid_resources         = false",
    "changes_google_cloud_resources = false",
    "creates_real_value_capability  = false",
    "public_endpoint_exposure       = false",
    "production_ingress_enabled     = false",
    "institution_api_path",
    "admin_api_path",
    "validator_internal_path",
    "stage_0_design_only",
    "stage_3_mtls_trust_design",
    "google_compute_global_address",
    "google_certificate_manager_certificate",
    "google_certificate_manager_trust_config",
    "google_api_gateway_api",
    "google_dns_record_set",
    'output "phase4_prod_ingress_implementation_plan"'
)) {
    if ($prodIngressTerraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress Terraform design content: $expected"
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
    "creates_external_https_load_balancer",
    "creates_api_gateway",
    "creates_reserved_static_ip",
    "creates_dns_record",
    "creates_certificate_manager_certificate",
    "creates_certificate_manager_trust_config",
    "applies_cloud_armor_policy",
    "changes_cloud_run_ingress",
    "enables_institution_mtls",
    "enables_public_endpoint_exposure",
    "external_https_load_balancer_created",
    "api_gateway_created",
    "reserved_static_ip_created",
    "dns_record_created",
    "certificate_manager_certificate_created",
    "certificate_manager_trust_config_created",
    "cloud_armor_waf_applied",
    "cloud_armor_rate_limits_applied",
    "mtls_trust_config_applied",
    "institution_mtls_enabled",
    "cloud_run_ingress_changed",
    "public_endpoint_exposure_enabled",
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
    if ($securityConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 security review scope must not enable $forbidden"
    }
    if ($hsmKmsConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 HSM/KMS implementation plan must not enable $forbidden"
    }
    if ($prodIngressConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 production ingress implementation plan must not enable $forbidden"
    }
}

if ($costConfig -match "(?m)^\s*terraform_apply_allowed:\s+true\s*$") {
    throw "Phase 4 cost model must not allow Terraform apply"
}

if ($securityConfig -match "(?m)^\s*penetration_test_execution_allowed:\s+true\s*$") {
    throw "Phase 4 security review scope must not allow penetration test execution"
}

if ($securityConfig -match "(?m)^\s*production_target_testing_allowed:\s+true\s*$") {
    throw "Phase 4 security review scope must not allow production target testing"
}

if ($hsmKmsConfig -match "(?m)^\s*enables_kms_hsm_signing:\s+true\s*$") {
    throw "Phase 4 HSM/KMS implementation plan must not enable KMS/HSM signing"
}

if ($prodIngressConfig -match "(?m)^\s*terraform_apply_allowed:\s+true\s*$") {
    throw "Phase 4 production ingress implementation plan must not allow Terraform apply"
}

if ($prodIngressConfig -match "(?m)^\s*enables_public_endpoint_exposure:\s+true\s*$") {
    throw "Phase 4 production ingress implementation plan must not enable public endpoint exposure"
}

if ($prodIngressConfig -match "(?m)^\s*production_ingress_enabled:\s+true\s*$") {
    throw "Phase 4 production ingress implementation plan must not enable production ingress"
}

if ($hsmKmsTerraform -match 'resource\s+"google_') {
    throw "phase4_hsm_kms_implementation_plan.tf must remain design-only and must not declare Google Cloud resources"
}

if ($prodIngressTerraform -match 'resource\s+"google_') {
    throw "phase4_prod_ingress_implementation_plan.tf must remain design-only and must not declare Google Cloud resources"
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
    security_review_scope_rc1 = $true
    hsm_kms_implementation_plan_rc1 = $true
    prod_ingress_implementation_plan_rc1 = $true
    result = "ok"
}
