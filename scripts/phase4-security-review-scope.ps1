$ErrorActionPreference = "Stop"

$docPath = "PHASE4_SECURITY_REVIEW_SCOPE.md"
$configPath = "config/phase4-security-review-scope.yaml"

foreach ($file in @($docPath, $configPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 4 security review scope artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
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
    "ledger_integrity_review",
    "validator_operations_review",
    "deferred_gke_hsm_ingress_review",
    "No sensitive secrets",
    "Penetration test execution",
    "Production target testing",
    "GKE cluster creation",
    "Real-value settlement",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 security review scope doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase4-security-review-scope-rc1",
    "status: security_scope_ready",
    "inherits_from: phase4-cost-model-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "penetration_test_execution_allowed: false",
    "production_target_testing_allowed: false",
    "external_institution_testing_allowed: false",
    "enables_gke_validator_operations: false",
    "enables_hsm_or_kms_signing: false",
    "enables_production_ingress: false",
    "enables_public_endpoint_exposure: false",
    "enables_real_value_settlement: false",
    "review_objectives:",
    "sandbox_runtime_flags_prevent_real_value_use",
    "gke_deferred_to_phase5b_confirmation",
    "in_scope_assets:",
    "kani_api_institution_endpoints",
    "cloud_run_iam_assumptions",
    "out_of_scope:",
    "production_resource_testing",
    "gke_validator_cluster_testing",
    "threat_areas:",
    "broken_object_level_authorization_between_institutions",
    "terraform_drift_or_accidental_paid_resource_enablement",
    "test_evidence_requirements:",
    "forbidden_evidence:",
    "review_workstreams:",
    "api_authorization_review:",
    "deferred_gke_hsm_ingress_review:",
    "status: blocked",
    "google_cloud_resource_creation_allowed: false",
    "gke_cluster_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "production_ingress_enabled: false",
    "public_endpoint_exposure_enabled: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_security_scope: true",
    "no_penetration_test_execution: true",
    "no_public_endpoint_exposure_enabled: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 security review scope config content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "penetration_test_execution_allowed",
    "production_target_testing_allowed",
    "external_institution_testing_allowed",
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_production_ingress",
    "enables_public_endpoint_exposure",
    "enables_real_value_settlement",
    "google_cloud_resource_creation_allowed",
    "gke_cluster_enabled",
    "hsm_kms_production_signing_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "real_value_settlement_enabled"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 security review scope must not enable $forbidden"
    }
}

$workstreamCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($workstreamCount -lt 13) {
    throw "Expected at least 13 security review workstreams, found $workstreamCount"
}

[pscustomobject]@{
    release_candidate = "phase4-security-review-scope-rc1"
    status = "security_scope_ready"
    track = "phase4-no-gke-preprod-readiness"
    review_workstream_count = 13
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    penetration_test_execution_allowed = $false
    production_target_testing_allowed = $false
    external_institution_testing_allowed = $false
    gke_enabled = $false
    hsm_kms_signing_enabled = $false
    production_ingress_enabled = $false
    public_endpoint_exposure_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
