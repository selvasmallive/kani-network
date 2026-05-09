$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE3_ENTERPRISE_PLAN.md",
    "config/phase3-enterprise.yaml",
    "scripts/phase3-validate.ps1",
    "PHASE2_OBSERVATION_REPORT.md"
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
    "Status: planning",
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
    "No GKE, production ingress, HSM, or real-value resources are created"
)) {
    if ($plan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 plan content in PHASE3_ENTERPRISE_PLAN.md: $expected"
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
    "creates_real_value_capability: false"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 config content in config/phase3-enterprise.yaml: $expected"
    }
}

$readme = Get-Content "README.md" -Raw
if ($readme -notmatch "PHASE3_ENTERPRISE_PLAN.md" -or $readme -notmatch "phase3-validate.ps1") {
    throw "Expected README.md to link Phase 3 plan and validator"
}

$observation = Get-Content "PHASE2_OBSERVATION_REPORT.md" -Raw
if ($observation -notmatch "Move into Phase 3 planning" -or $observation -notmatch "BFT consensus design boundary") {
    throw "Expected Phase 2 observation report to point to Phase 3 planning"
}

[pscustomobject]@{
    phase = "phase-3-enterprise"
    status = "planning"
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
    result = "ok"
}
