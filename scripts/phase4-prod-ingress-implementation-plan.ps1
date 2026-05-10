$ErrorActionPreference = "Stop"

$docPath = "PHASE4_PROD_INGRESS_IMPLEMENTATION_PLAN.md"
$configPath = "config/phase4-prod-ingress-implementation-plan.yaml"
$terraformPath = "infra/terraform/phase4_prod_ingress_implementation_plan.tf"

foreach ($file in @($docPath, $configPath, $terraformPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 4 production ingress implementation plan artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
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
    "Public endpoint exposure",
    "allUsers",
    "allAuthenticatedUsers",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress implementation plan doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
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
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress implementation plan config content: $expected"
    }
}

$terraform = Get-Content $terraformPath -Raw
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
    if ($terraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 production ingress Terraform design content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
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
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_real_value_settlement",
    "external_https_load_balancer_created",
    "api_gateway_created",
    "reserved_static_ip_created",
    "dns_record_created",
    "certificate_manager_certificate_created",
    "certificate_manager_trust_config_created",
    "institution_mtls_enabled",
    "cloud_armor_waf_applied",
    "cloud_armor_rate_limits_applied",
    "cloud_run_ingress_changed",
    "public_endpoint_exposure_enabled",
    "google_cloud_resource_creation_allowed",
    "real_value_settlement_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 production ingress implementation plan must not enable $forbidden"
    }
}

if ($terraform -match 'resource\s+"google_') {
    throw "phase4_prod_ingress_implementation_plan.tf must remain design-only and must not declare Google Cloud resources in this slice"
}

[pscustomobject]@{
    release_candidate = "phase4-prod-ingress-implementation-plan-rc1"
    status = "implementation_plan_ready"
    track = "phase4-no-gke-preprod-readiness"
    request_path_count = 4
    implementation_stage_count = 7
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    terraform_apply_allowed = $false
    production_ingress_enabled = $false
    public_endpoint_exposure_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
