$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE3_ENTERPRISE_PLAN.md",
    "PHASE3_INSTITUTION_MODEL.md",
    "PHASE3_COMPLIANCE_CASES.md",
    "PHASE3_CONSENSUS_INTERFACE.md",
    "config/phase3-enterprise.yaml",
    "scripts/phase3-validate.ps1",
    "PHASE2_OBSERVATION_REPORT.md",
    "openapi/kani-api.v1.json",
    "migrations/0002_phase3_institutions.sql",
    "migrations/0009_phase3_compliance_cases.sql"
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
    "PHASE3_INSTITUTION_MODEL.md",
    "PHASE3_COMPLIANCE_CASES.md",
    "PHASE3_CONSENSUS_INTERFACE.md"
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

$complianceCases = Get-Content "PHASE3_COMPLIANCE_CASES.md" -Raw
foreach ($expected in @(
    "Status: implementation slice ready",
    "phase3-compliance-cases-rc1",
    "TransactionStatus::HELD",
    "ComplianceCase",
    "GET  /v1/compliance/cases",
    "POST /v1/compliance/cases/{id}/approve",
    "POST /v1/compliance/cases/{id}/reject",
    "keeps the transaction out of the validator pending queue"
)) {
    if ($complianceCases -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 compliance cases content in PHASE3_COMPLIANCE_CASES.md: $expected"
    }
}

$consensusInterface = Get-Content "PHASE3_CONSENSUS_INTERFACE.md" -Raw
foreach ($expected in @(
    "Status: implementation slice ready",
    "phase3-consensus-interface-rc1",
    "ConsensusEngine",
    "ConsensusEngineConfig",
    "ConfiguredConsensusEngine",
    "PoAConsensus",
    "ConsensusProposal",
    "ConsensusVote",
    "QuorumCertificate",
    "FinalityProof",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($consensusInterface -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 consensus interface content in PHASE3_CONSENSUS_INTERFACE.md: $expected"
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
    "suspended_institutions_cannot_operate_accounts",
    "phase3_compliance_cases_rc1:",
    "migrations/0009_phase3_compliance_cases.sql",
    "held_payments_are_not_validator_pending",
    "approved_cases_release_payment_to_pending",
    "rejected_cases_mark_payment_rejected",
    "phase3_consensus_interface_rc1:",
    "default_engine: phase1-poa",
    "ConsensusEngine trait",
    "production finality claims"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 config content in config/phase3-enterprise.yaml: $expected"
    }
}

$readme = Get-Content "README.md" -Raw
foreach ($expected in @(
    "PHASE3_ENTERPRISE_PLAN.md",
    "PHASE3_INSTITUTION_MODEL.md",
    "PHASE3_COMPLIANCE_CASES.md",
    "PHASE3_CONSENSUS_INTERFACE.md",
    "phase3-validate.ps1",
    "POST /v1/admin/institutions",
    "POST /v1/admin/institutions/{id}/suspend",
    "GET  /v1/compliance/cases",
    "POST /v1/compliance/cases/{id}/approve",
    "ConsensusEngine"
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
    "pub struct ComplianceCase",
    "pub struct ComplianceCaseOpen",
    "pub enum ComplianceCaseStatus",
    "pub enum InstitutionStatus",
    "pub enum InstitutionCredentialStatus",
    "Held",
    "pub struct ConsensusProposal",
    "pub struct ConsensusVote",
    "pub struct QuorumCertificate",
    "pub struct FinalityProof",
    "pub struct ValidatorSet"
)) {
    if ($types -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution type in kani-types: $expected"
    }
}

$consensus = Get-Content "crates/kani-consensus/src/lib.rs" -Raw
foreach ($expected in @(
    "pub trait ConsensusEngine",
    "pub enum ConsensusAlgorithm",
    "pub struct ConsensusEngineConfig",
    "pub enum ConfiguredConsensusEngine",
    "impl ConsensusEngine for PoAConsensus",
    "phase1_default_validators",
    "UnsupportedEngine"
)) {
    if ($consensus -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 consensus interface support in kani-consensus: $expected"
    }
}

$ledger = Get-Content "crates/kani-ledger/src/lib.rs" -Raw
foreach ($expected in @(
    "UnknownInstitution",
    "upsert_institution",
    "institution_credentials",
    "institution_limits",
    "load_institution_credentials",
    "load_institution_limits",
    "hold_payment_for_review",
    "approve_compliance_case",
    "reject_compliance_case",
    "compliance_cases"
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
    "pub async fn institution_limits",
    "pub async fn hold_payment_for_review",
    "pub async fn compliance_cases",
    "pub async fn approve_compliance_case",
    "pub async fn reject_compliance_case"
)) {
    if ($node -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution node support in kani-node: $expected"
    }
}

$nodeConsensusExpected = @(
    "ConfiguredConsensusEngine",
    "ConsensusEngineConfig::phase1_poa",
    "pub fn consensus(&self) -> &dyn ConsensusEngine",
    "consensus: &dyn ConsensusEngine"
)
foreach ($expected in $nodeConsensusExpected) {
    if ($node -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 consensus interface node support in kani-node: $expected"
    }
}

$api = Get-Content "crates/kani-api/src/lib.rs" -Raw
foreach ($expected in @(
    '"/v1/admin/institutions"',
    '"/v1/admin/institutions/:id/credentials"',
    '"/v1/admin/institutions/:id/suspend"',
    '"/v1/admin/institutions/:id/limits"',
    '"/v1/compliance/cases"',
    '"/v1/compliance/cases/:id/approve"',
    '"/v1/compliance/cases/:id/reject"',
    "InstitutionProfileResponse",
    "ComplianceCaseResponse",
    "ensure_institution_can_operate",
    "suspended_institution_cannot_authorize_account_control",
    "payment_submission_opens_compliance_case_for_manual_review"
)) {
    if ($api -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 institution API support in kani-api: $expected"
    }
}

$openapi = Get-Content "openapi/kani-api.v1.json" -Raw
foreach ($expected in @(
    '"/v1/compliance/cases"',
    '"/v1/compliance/cases/{id}/approve"',
    '"/v1/compliance/cases/{id}/reject"',
    '"ComplianceCase"',
    '"ComplianceCaseResponse"',
    '"PaginatedComplianceCaseResponse"',
    '"HELD"'
)) {
    if ($openapi -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 compliance OpenAPI content: $expected"
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

$complianceMigration = Get-Content "migrations/0009_phase3_compliance_cases.sql" -Raw
foreach ($expected in @(
    "CREATE TABLE IF NOT EXISTS compliance_cases",
    "'HELD'",
    "idx_compliance_cases_status"
)) {
    if ($complianceMigration -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 compliance migration content: $expected"
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
    compliance_cases_rc1 = $true
    consensus_interface_rc1 = $true
    result = "ok"
}
