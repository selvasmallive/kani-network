$ErrorActionPreference = "Stop"

$docPath = "PHASE3_WRAPUP.md"
$configPath = "config/phase3-wrapup.yaml"

foreach ($file in @($docPath, $configPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 3 wrap-up artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: sandbox enterprise track complete",
    "phase3-wrapup-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Completed Release Candidates",
    "phase3-spec-rc1",
    "phase3-institution-model-rc1",
    "phase3-compliance-cases-rc1",
    "phase3-consensus-interface-rc1",
    "phase3-bft-prototype-rc1",
    "phase3-prod-edge-design-rc1",
    "phase3-key-management-design-rc1",
    "phase3-regulatory-readiness-gate-rc1",
    "phase3-audit-reporting-hardening-rc1",
    "phase3-operational-runbooks-rc1",
    "phase3-wrapup-rc1",
    "Explicit Non-Enablement",
    "No GKE validator cluster is enabled",
    "No production BFT finality claim is made",
    "No Cloud HSM, production KMS keys, or signing service is created",
    "No production ingress",
    "No external institution onboarding is authorized",
    "No real-value reporting",
    "Deferral Register",
    "Phase 4 Entry Criteria",
    "scripts/phase3-wrapup.ps1",
    "Phase 3 is complete for the sandbox enterprise track"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 wrap-up doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase3-wrapup-rc1",
    "status: sandbox_enterprise_track_complete",
    "completion_scope: sandbox_enterprise_track",
    "completion_percentage: 100",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "creates_real_value_capability: false",
    "enables_gke_validator_operations: false",
    "enables_hsm_or_kms_signing: false",
    "enables_production_ingress: false",
    "authorizes_external_institution_onboarding: false",
    "completed_release_candidates:",
    "phase3-operational-runbooks-rc1",
    "phase3-wrapup-rc1",
    "phase2_lean_no_gke_baseline_retained: true",
    "phase1_poa_validator_default_retained: true",
    "regulatory_gate_blocked: true",
    "gke_cluster_enabled: false",
    "production_bft_enabled: false",
    "hsm_signing_enabled: false",
    "production_ingress_enabled: false",
    "external_customer_access_enabled: false",
    "real_value_reporting_enabled: false",
    "legal_or_regulatory_approval_claimed: false",
    "deferred_to_phase4_or_later:",
    "gke_multi_node_validator_operations",
    "production_bft_networking_and_round_changes",
    "hsm_backed_validator_treasury_api_iso_and_audit_signing",
    "legal_classification_and_registration_analysis",
    "phase4_entry_criteria:",
    "production_cost_estimate_reviewed",
    "terraform_plan_review_before_paid_resource_apply",
    "phase3_sandbox_enterprise_track_complete: true",
    "production_ready: false",
    "real_value_ready: false",
    "next_phase: phase-4-pre-production-readiness"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 wrap-up config content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "creates_real_value_capability",
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_production_ingress",
    "authorizes_external_institution_onboarding",
    "gke_cluster_enabled",
    "production_bft_enabled",
    "hsm_signing_enabled",
    "production_ingress_enabled",
    "external_customer_access_enabled",
    "real_value_reporting_enabled",
    "legal_or_regulatory_approval_claimed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 3 wrap-up must not enable $forbidden"
    }
}

if ($config -notmatch "(?m)^\s*completion_percentage:\s+100\s*$") {
    throw "Phase 3 sandbox enterprise completion percentage must be 100"
}

[pscustomobject]@{
    release_candidate = "phase3-wrapup-rc1"
    status = "sandbox_enterprise_track_complete"
    completion_percentage = 100
    completed_release_candidate_count = 11
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    gke_validator_operations_enabled = $false
    hsm_or_kms_signing_enabled = $false
    production_ingress_enabled = $false
    real_value_capability_created = $false
    production_ready = $false
    result = "ok"
}
