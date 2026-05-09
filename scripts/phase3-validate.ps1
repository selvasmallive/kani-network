$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE3_ENTERPRISE_PLAN.md",
    "PHASE3_INSTITUTION_MODEL.md",
    "config/phase3-enterprise.yaml",
    "scripts/phase3-validate.ps1",
    "PHASE2_OBSERVATION_REPORT.md",
    "migrations/0002_phase3_institutions.sql"
)

$missing = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 3 files: $($missing -join ', ')"
}

$plan = Get-Content "PHASE3_ENTERPRISE_PLAN.md" -Raw
foreach ($expected in @(
    "Status: implementation started",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Consensus Evolution",
    "Institution Onboarding",
    "Compliance Workflow",
    "Production Ingress And mTLS",
    "Key Management And Crypto Agility",
    "Regulatory And Legal Readiness",
    "Data, Audit, And Reporting",
    "phase3-institution-model-rc1",
    "phase3-compliance-cases-rc1",
    "phase3-consensus-interface-rc1",
    "No GKE, production ingress, HSM, or real-value resources are created",
    "PHASE3_INSTITUTION_MODEL.md"
)) {
    if ($plan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 plan content in PHASE3_ENTERPRISE_PLAN.md: $expected"
    }
}

$institutionModel = Get-Content "PHASE3_INSTITUTION_MODEL.md" -Raw
foreach ($expected in @(
    "Status: implementation slice ready",
    "phase3-institution-model-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "KANI_TREASURY",
    "CORP_A",
    "CORP_B",
    "GET  /v1/admin/institutions",
    "POST /v1/admin/institutions",
    "POST /v1/admin/institutions/{id}/credentials",
    "POST /v1/admin/institutions/{id}/suspend",
    "POST /v1/admin/institutions/{id}/limits",
    "Suspended or otherwise non-approved institutions cannot operate accounts"
)) {
    if ($institutionModel -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution model content in PHASE3_INSTITUTION_MODEL.md: $expected"
    }
}

$config = Get-Content "config/phase3-enterprise.yaml" -Raw
foreach ($expected in @(
    "phase: phase-3-enterprise",
    "inherits_from: phase2-lean-no-gke",
    "real_value: false",
    "production_value_movement_allowed: false",
    "consensus:",
    "target: BFT",
    "institution_onboarding:",
    "InstitutionCredential",
    "compliance:",
    "target_profile: enterprise-policy-versioned",
    "ingress:",
    "institution_mtls",
    "allUsers",
    "key_management:",
    "dual_control_key_ceremony",
    "regulatory_readiness:",
    "requires_external_review: true",
    "creates_paid_resources: false",
    "creates_real_value_capability: false",
    "phase3_institution_model_rc1:",
    "migrations/0002_phase3_institutions.sql",
    "suspended_institutions_cannot_operate_accounts"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 config content in config/phase3-enterprise.yaml: $expected"
    }
}

$readme = Get-Content "README.md" -Raw
foreach ($expected in @(
    "PHASE3_ENTERPRISE_PLAN.md",
    "PHASE3_INSTITUTION_MODEL.md",
    "phase3-validate.ps1",
    "POST /v1/admin/institutions",
    "POST /v1/admin/institutions/{id}/suspend"
)) {
    if ($readme -notmatch [regex]::Escape($expected)) {
        throw "Expected README.md Phase 3 content: $expected"
    }
}

$observation = Get-Content "PHASE2_OBSERVATION_REPORT.md" -Raw
if ($observation -notmatch "Move into Phase 3 planning" -or $observation -notmatch "BFT consensus design boundary") {
    throw "Expected Phase 2 observation report to point to Phase 3 planning"
}

$types = Get-Content "crates/kani-types/src/lib.rs" -Raw
foreach ($expected in @(
    "pub struct Institution",
    "pub struct InstitutionCredential",
    "pub struct InstitutionLimit",
    "pub struct OnboardingCase",
    "pub enum InstitutionStatus",
    "pub enum InstitutionCredentialStatus"
)) {
    if ($types -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution type in kani-types: $expected"
    }
}

$ledger = Get-Content "crates/kani-ledger/src/lib.rs" -Raw
foreach ($expected in @(
    "UnknownInstitution",
    "upsert_institution",
    "institution_credentials",
    "institution_limits",
    "load_institution_credentials",
    "load_institution_limits"
)) {
    if ($ledger -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution storage support in kani-ledger: $expected"
    }
}

$node = Get-Content "crates/kani-node/src/lib.rs" -Raw
foreach ($expected in @(
    "pub async fn institutions",
    "pub async fn upsert_institution",
    "pub async fn suspend_institution",
    "pub async fn institution_credentials",
    "pub async fn institution_limits"
)) {
    if ($node -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution node support in kani-node: $expected"
    }
}

$api = Get-Content "crates/kani-api/src/lib.rs" -Raw
foreach ($expected in @(
    '"/v1/admin/institutions"',
    '"/v1/admin/institutions/:id/credentials"',
    '"/v1/admin/institutions/:id/suspend"',
    '"/v1/admin/institutions/:id/limits"',
    "InstitutionProfileResponse",
    "ensure_institution_can_operate",
    "suspended_institution_cannot_authorize_account_control"
)) {
    if ($api -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution API support in kani-api: $expected"
    }
}

$migration = Get-Content "migrations/0002_phase3_institutions.sql" -Raw
foreach ($expected in @(
    "CREATE TABLE IF NOT EXISTS institutions",
    "CREATE TABLE IF NOT EXISTS institution_credentials",
    "CREATE TABLE IF NOT EXISTS institution_limits"
)) {
    if ($migration -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution migration content: $expected"
    }
}

[pscustomobject]@{
    phase = "phase-3-enterprise"
    status = "implementation-started"
    required_file_count = $requiredFiles.Count
    sandbox_boundary_checked = $true
    consensus_planning = $true
    institution_onboarding_planning = $true
    compliance_workflow_planning = $true
    ingress_mtls_planning = $true
    key_management_planning = $true
    regulatory_readiness_planning = $true
    paid_resources_created = $false
    real_value_capability_created = $false
    gke_enabled = $false
    institution_model_rc1 = $true
    result = "ok"
}
