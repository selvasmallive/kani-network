$ErrorActionPreference = "Stop"

$docPath = "PHASE4_LEGAL_COMPLIANCE_EVIDENCE.md"
$configPath = "config/phase4-legal-compliance-evidence.yaml"

foreach ($file in @($docPath, $configPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 4 legal/compliance evidence artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: evidence register ready",
    "phase4-legal-compliance-evidence-rc1",
    "not legal advice",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Evidence Objective",
    "Required Evidence Gates",
    "legal_classification_review",
    "registration_and_msb_analysis",
    "aml_kyc_program_review",
    "sanctions_screening_review",
    "privacy_and_data_retention_review",
    "custody_and_safeguarding_review",
    "institution_agreement_review",
    "security_architecture_review",
    "penetration_test_scope",
    "incident_response_and_dr_review",
    "production_cost_estimate_review",
    "terraform_plan_review",
    "executive_go_live_approval",
    'Every evidence gate starts as `blocked`',
    "Evidence Fields",
    "Reviewer Requirements",
    "qualified_external_legal_counsel",
    "independent_security_reviewer",
    "Production Blockers",
    "Non-Enablement",
    "Legal classification approval",
    "External institution onboarding",
    "Real-value settlement",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 legal/compliance evidence doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase4-legal-compliance-evidence-rc1",
    "status: evidence_register_ready",
    "inherits_from: phase4-dr-readiness-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "legal_advice: false",
    "requires_external_legal_review: true",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "enables_external_institution_onboarding: false",
    "enables_real_value_settlement: false",
    "approval_boundary:",
    "legal_advice_provided: false",
    "legal_classification_approved: false",
    "registration_analysis_approved: false",
    "aml_kyc_program_approved: false",
    "sanctions_screening_approved: false",
    "privacy_review_approved: false",
    "custody_safeguarding_approved: false",
    "institution_agreement_approved: false",
    "executive_go_live_approved: false",
    "production_authorization_granted: false",
    "evidence_requirements:",
    "required_status_before_production: approved",
    "named_owner_required: true",
    "qualified_external_legal_review_required: true",
    "independent_security_review_required: true",
    "reviewer_roles:",
    "qualified_external_legal_counsel",
    "compliance_officer",
    "privacy_officer",
    "independent_security_reviewer",
    "executive_approver",
    "evidence_register:",
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
    "approval_status: blocked",
    "owner: unassigned",
    "evidence_location: pending",
    "approval_date: pending",
    "residual_risk: pending",
    "fintrac_msb_analysis",
    "suspicious_activity_escalation",
    "cross_border_data_flow_review",
    "terraform_plan_output",
    "signed_go_live_record",
    "external_institution_onboarding_enabled: false",
    "production_go_live_allowed: false",
    "phase4_validator_includes_legal_compliance_evidence: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 legal/compliance evidence config content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_production_ingress",
    "enables_external_institution_onboarding",
    "enables_real_value_settlement",
    "legal_advice_provided",
    "legal_classification_approved",
    "registration_analysis_approved",
    "aml_kyc_program_approved",
    "sanctions_screening_approved",
    "privacy_review_approved",
    "custody_safeguarding_approved",
    "institution_agreement_approved",
    "security_architecture_approved",
    "penetration_test_approved",
    "production_cost_approved",
    "terraform_plan_approved",
    "executive_go_live_approved",
    "production_authorization_granted",
    "external_institution_onboarding_enabled",
    "google_cloud_resource_creation_allowed",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 legal/compliance evidence must not enable $forbidden"
    }
}

$blockedGateCount = ([regex]::Matches($config, "approval_status:\s+blocked")).Count
if ($blockedGateCount -lt 13) {
    throw "Expected at least 13 blocked evidence gates, found $blockedGateCount"
}

[pscustomobject]@{
    release_candidate = "phase4-legal-compliance-evidence-rc1"
    status = "evidence_register_ready"
    track = "phase4-no-gke-preprod-readiness"
    evidence_gate_count = 13
    blocked_gate_count = $blockedGateCount
    legal_advice_provided = $false
    legal_or_compliance_approval_enabled = $false
    external_institution_onboarding_enabled = $false
    production_authorization_enabled = $false
    real_value_capability_enabled = $false
    google_cloud_resources_changed = $false
    result = "ok"
}
