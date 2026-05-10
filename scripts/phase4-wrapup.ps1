$ErrorActionPreference = "Stop"

$docPath = "PHASE4_WRAPUP.md"
$configPath = "config/phase4-wrapup.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE4_PRE_PRODUCTION_READINESS.md",
    "PHASE4_COST_MODEL.md",
    "PHASE4_SECURITY_REVIEW_SCOPE.md",
    "PHASE4_HSM_KMS_IMPLEMENTATION_PLAN.md",
    "PHASE4_PROD_INGRESS_IMPLEMENTATION_PLAN.md",
    "PHASE4_DR_READINESS.md",
    "PHASE4_LEGAL_COMPLIANCE_EVIDENCE.md",
    "config/phase4-pre-production-readiness.yaml",
    "config/phase4-cost-model.yaml",
    "config/phase4-security-review-scope.yaml",
    "config/phase4-hsm-kms-implementation-plan.yaml",
    "config/phase4-prod-ingress-implementation-plan.yaml",
    "config/phase4-dr-readiness.yaml",
    "config/phase4-legal-compliance-evidence.yaml"
)

$missing = @()
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 4 wrap-up artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: sandbox pre-production readiness complete",
    "phase4-wrapup-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Completed Phase 4 Checkpoints",
    "phase4-pre-production-readiness-rc1",
    "phase4-cost-model-rc1",
    "phase4-security-review-scope-rc1",
    "phase4-hsm-kms-implementation-plan-rc1",
    "phase4-prod-ingress-implementation-plan-rc1",
    "phase4-dr-readiness-rc1",
    "phase4-legal-compliance-evidence-rc1",
    "Phase 4 Result",
    "No-GKE pre-production readiness gates",
    "Aggregate Phase 4 validator coverage",
    "Production approval",
    "Legal advice",
    "Real-value capability",
    'Ready to move into `phase5a-no-gke-validator-hardening`',
    'GKE remains deferred to `phase5b-gke-validator-ops`',
    "Required Blocks That Remain",
    "Legal classification approval",
    "Executive go-live approval",
    "Non-Enablement",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 wrap-up doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase4-wrapup-rc1",
    "status: sandbox_pre_production_readiness_complete",
    "inherits_from: phase4-legal-compliance-evidence-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "next_phase: phase5a-no-gke-validator-hardening",
    "gke_phase: phase5b-gke-validator-ops",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "completed_release_candidates:",
    "phase4_pre_production_readiness_rc1: true",
    "phase4_cost_model_rc1: true",
    "phase4_security_review_scope_rc1: true",
    "phase4_hsm_kms_implementation_plan_rc1: true",
    "phase4_prod_ingress_implementation_plan_rc1: true",
    "phase4_dr_readiness_rc1: true",
    "phase4_legal_compliance_evidence_rc1: true",
    "phase_result:",
    "no_gke_preprod_readiness_complete: true",
    "planning_and_evidence_only: true",
    "production_ready: false",
    "real_value_ready: false",
    "legal_advice_provided: false",
    "google_cloud_resources_created: false",
    "paid_resources_created: false",
    "terraform_apply_allowed: false",
    "phase5a_ready_to_start: true",
    "phase5b_gke_deferred: true",
    "phase5a_scope:",
    "gke_required: false",
    "validator_runtime: cloud_run_job_plus_cloud_scheduler",
    "remaining_blocked_gates:",
    "legal_classification_review: blocked",
    "executive_go_live_approval: blocked",
    "non_enablement:",
    "gke_cluster_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "external_institution_onboarding_enabled: false",
    "production_authorization_granted: false",
    "legal_or_compliance_approval_enabled: false",
    "real_value_settlement_enabled: false",
    "terraform_apply_allowed: false",
    "google_cloud_resource_creation_allowed: false",
    "production_go_live_allowed: false",
    "aggregate_phase4_validator_includes_wrapup: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 wrap-up config content: $expected"
    }
}

foreach ($forbidden in @(
    "production_ready",
    "real_value_ready",
    "legal_advice_provided",
    "google_cloud_resources_created",
    "paid_resources_created",
    "terraform_apply_allowed",
    "gke_cluster_enabled",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "cloud_armor_waf_applied",
    "mtls_trust_config_applied",
    "hsm_kms_production_signing_enabled",
    "restore_drill_executed",
    "production_recovery_executed",
    "external_institution_onboarding_enabled",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "google_cloud_resource_creation_allowed",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 wrap-up must not enable $forbidden"
    }
}

$completedCount = ([regex]::Matches($config, "phase4_[a-z0-9_]+_rc1:\s+true")).Count
if ($completedCount -lt 7) {
    throw "Expected at least 7 completed Phase 4 release candidates, found $completedCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 13) {
    throw "Expected at least 13 blocked gates, found $blockedGateCount"
}

[pscustomobject]@{
    release_candidate = "phase4-wrapup-rc1"
    status = "sandbox_pre_production_readiness_complete"
    track = "phase4-no-gke-preprod-readiness"
    completed_release_candidate_count = 7
    blocked_gate_count = $blockedGateCount
    next_phase = "phase5a-no-gke-validator-hardening"
    gke_deferred_to = "phase5b-gke-validator-ops"
    google_cloud_resources_created = $false
    production_authorization_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
