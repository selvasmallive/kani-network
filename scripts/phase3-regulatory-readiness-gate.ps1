$ErrorActionPreference = "Stop"

$configPath = "config/phase3-regulatory-readiness.yaml"

if (-not (Test-Path $configPath)) {
    throw "Missing regulatory readiness gate config: $configPath"
}

$config = Get-Content $configPath -Raw

foreach ($expected in @(
    "release_candidate: phase3-regulatory-readiness-gate-rc1",
    "status: blocked",
    "legal_advice: false",
    "requires_external_review: true",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "production_go_live_allowed: false",
    "real_value_capability_allowed: false",
    "external_customer_access_allowed: false",
    "fiat_deposit_or_redemption_allowed: false",
    "custody_for_others_allowed: false",
    "trading_allowed: false",
    "approval_records_required: true",
    "qualified_legal_review_required: true",
    "independent_security_review_required: true",
    "gate_status: blocked",
    "production_ready: false",
    "real_value_ready: false"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected regulatory readiness gate config content: $expected"
    }
}

$requiredGates = @(
    "legal_classification",
    "registration_analysis",
    "aml_kyc_program",
    "sanctions_process",
    "privacy_data_retention",
    "institution_agreements",
    "custody_safeguarding",
    "incident_response",
    "security_penetration_test",
    "production_go_live_approval"
)

foreach ($gate in $requiredGates) {
    if ($config -notmatch [regex]::Escape("${gate}:")) {
        throw "Missing regulatory readiness gate: $gate"
    }
}

if ($config -match "production_go_live_allowed:\s+true") {
    throw "Production go-live must remain blocked in phase3-regulatory-readiness-gate-rc1"
}

if ($config -match "real_value_capability_allowed:\s+true") {
    throw "Real-value capability must remain blocked in phase3-regulatory-readiness-gate-rc1"
}

if ($config -match "gate_status:\s+approved") {
    throw "The regulatory readiness gate must not be approved in this sandbox design slice"
}

[pscustomobject]@{
    phase = "phase-3-enterprise"
    release_candidate = "phase3-regulatory-readiness-gate-rc1"
    gate_status = "blocked"
    legal_advice = $false
    requires_external_review = $true
    required_gate_count = $requiredGates.Count
    production_go_live_allowed = $false
    real_value_capability_allowed = $false
    external_customer_access_allowed = $false
    result = "ok"
}
