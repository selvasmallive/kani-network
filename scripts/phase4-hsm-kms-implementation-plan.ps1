$ErrorActionPreference = "Stop"

$docPath = "PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md"
$configPath = "config/phase4-hsm-kms-implementation-plan.yaml"
$terraformPath = "infra/terraform/phase4_hsm_kms_implementation_plan.tf"

foreach ($file in @($docPath, $configPath, $terraformPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 4 HSM/KMS implementation plan artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
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
    "api_request_signing",
    "audit_log_signing",
    "iso20022_message_signing",
    "Implementation Stages",
    "stage_0_design_only",
    "stage_2_kms_mock_adapter",
    "Signing Request Contract",
    "Raw private keys must never leave managed custody",
    "Key Lifecycle",
    "Required Gates Before Apply",
    "Terraform Boundary",
    "phase4_hsm_kms_implementation_enabled = false",
    'Declare no `resource "google_*"` blocks',
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS implementation plan doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase4-hsm-kms-implementation-plan-rc1",
    "status: implementation_plan_ready",
    "inherits_from: phase4-security-review-scope-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
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
    "api_request_signing:",
    "audit_log_signing:",
    "iso20022_message_signing:",
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
    "guard_default: false",
    "declares_google_cloud_resources: false",
    "output_only: true",
    "kms_key_ring_created: false",
    "kms_crypto_key_created: false",
    "hsm_key_created: false",
    "signing_service_deployed: false",
    "validator_kms_hsm_signing_enabled: false",
    "treasury_kms_hsm_signing_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_hsm_kms_plan: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS implementation plan config content: $expected"
    }
}

$terraform = Get-Content $terraformPath -Raw
foreach ($expected in @(
    'variable "phase4_hsm_kms_implementation_enabled"',
    "default     = false",
    "phase4-hsm-kms-implementation-plan-rc1",
    "creates_paid_resources         = false",
    "changes_google_cloud_resources = false",
    "creates_real_value_capability  = false",
    "production_signing_enabled     = false",
    "validator_block_signing",
    "treasury_asset_authority",
    "stage_0_design_only",
    "stage_6_production_candidate",
    "google_kms_key_ring",
    "google_kms_crypto_key",
    "cloud_hsm_key_generation",
    'output "phase4_hsm_kms_implementation_plan"'
)) {
    if ($terraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 HSM/KMS Terraform design content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "creates_kms_key_ring",
    "creates_kms_crypto_key",
    "creates_hsm_key",
    "deploys_signing_service",
    "enables_kms_hsm_signing",
    "enables_gke_validator_operations",
    "enables_production_ingress",
    "enables_real_value_settlement",
    "kms_key_ring_created",
    "kms_crypto_key_created",
    "hsm_key_created",
    "signing_service_deployed",
    "validator_kms_hsm_signing_enabled",
    "treasury_kms_hsm_signing_enabled",
    "audit_kms_hsm_signing_enabled",
    "iso20022_kms_hsm_signing_enabled",
    "google_cloud_resource_creation_allowed",
    "real_value_settlement_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 HSM/KMS implementation plan must not enable $forbidden"
    }
}

if ($terraform -match 'resource\s+"google_') {
    throw "phase4_hsm_kms_implementation_plan.tf must remain design-only and must not declare Google Cloud resources in this slice"
}

[pscustomobject]@{
    release_candidate = "phase4-hsm-kms-implementation-plan-rc1"
    status = "implementation_plan_ready"
    track = "phase4-no-gke-preprod-readiness"
    signing_purpose_count = 5
    implementation_stage_count = 7
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    terraform_apply_allowed = $false
    kms_key_ring_created = $false
    hsm_key_created = $false
    signing_service_deployed = $false
    production_signing_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
