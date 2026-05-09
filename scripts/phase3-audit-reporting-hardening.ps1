$ErrorActionPreference = "Stop"

$configPath = "config/phase3-audit-reporting.yaml"

if (-not (Test-Path $configPath)) {
    throw "Missing audit/reporting hardening config: $configPath"
}

$config = Get-Content $configPath -Raw

foreach ($expected in @(
    "release_candidate: phase3-audit-reporting-hardening-rc1",
    "status: hardening_ready",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "creates_real_value_capability: false",
    "external_report_delivery_enabled: false",
    "production_reporting_enabled: false",
    "export_requires_admin_authorization: true",
    "export_records_audit_event: true",
    "secrets_redacted_from_exports: true",
    "settlement_summary:",
    "compliance_decisions:",
    "validator_finality:",
    "reconciliation:",
    "immutable_audit_contract:",
    "hash_chain_enforced: false",
    "signing_enforced: false",
    "retention_matrix:",
    "requires_legal_privacy_approval",
    "export_controls:",
    "privacy_legal_review_required: true",
    "production_reporting_ready: false",
    "real_value_reporting_ready: false"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected audit/reporting hardening config content: $expected"
    }
}

$requiredAuditFields = @(
    "event_id",
    "event_type",
    "created_at",
    "actor_institution_id",
    "resource_type",
    "resource_id",
    "decision",
    "block_height",
    "transaction_id",
    "metadata_hash",
    "previous_event_hash",
    "event_hash"
)

foreach ($field in $requiredAuditFields) {
    if ($config -notmatch [regex]::Escape($field)) {
        throw "Missing immutable audit contract field: $field"
    }
}

if ($config -match "production_reporting_enabled:\s+true") {
    throw "Production reporting must remain disabled in phase3-audit-reporting-hardening-rc1"
}

if ($config -match "external_report_delivery_enabled:\s+true") {
    throw "External report delivery must remain disabled in phase3-audit-reporting-hardening-rc1"
}

if ($config -match "real_value_reporting_ready:\s+true") {
    throw "Real-value reporting must remain disabled in phase3-audit-reporting-hardening-rc1"
}

[pscustomobject]@{
    phase = "phase-3-enterprise"
    release_candidate = "phase3-audit-reporting-hardening-rc1"
    audit_reporting_hardening_status = "ready"
    immutable_audit_field_count = $requiredAuditFields.Count
    production_reporting_enabled = $false
    external_report_delivery_enabled = $false
    real_value_reporting_ready = $false
    result = "ok"
}
