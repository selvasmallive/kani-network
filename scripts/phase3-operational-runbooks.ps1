$ErrorActionPreference = "Stop"

$docPath = "PHASE3_OPERATIONAL_RUNBOOKS.md"
$configPath = "config/phase3-operational-runbooks.yaml"

foreach ($file in @($docPath, $configPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 3 operational runbook artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: operational slice ready",
    "phase3-operational-runbooks-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "technical_operator",
    "settlement_operator",
    "compliance_reviewer",
    "security_operator",
    "audit_reviewer",
    "release_approver",
    "Daily Operating Runbook",
    "Validator Operations",
    "Cloud Run Job plus Cloud Scheduler",
    "GKE validator operations remain deferred",
    "Incident Response",
    "SEV1",
    "Freeze validator Scheduler execution",
    "Release And Rollback Runbook",
    "Backup And Restore Runbook",
    "Credential And Secret Rotation Runbook",
    "Audit Evidence Pack",
    "No Google Cloud resources are created",
    "No production or real-value operations are enabled",
    "Current validator behavior remains Phase 1 PoA"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 operational runbook doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase3-operational-runbooks-rc1",
    "status: operational_runbooks_ready",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "production_operations_enabled: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "enables_gke_validator_operations: false",
    "technical_operator",
    "settlement_operator",
    "compliance_reviewer",
    "security_operator",
    "audit_reviewer",
    "release_approver",
    "daily_operations:",
    "validator_operations:",
    "cloud_run_job_scheduler_no_gke",
    "required_finality_votes: 2",
    "gke_deferred: true",
    "incident_response:",
    "SEV1",
    "freeze_validator_scheduler",
    "release_rollback:",
    "cargo_clippy_workspace_deny_warnings",
    "backup_restore:",
    "restore_to_separate_target",
    "credential_rotation:",
    "confirm_no_secrets_in_logs_or_audit_exports",
    "audit_evidence_pack:",
    "no_google_cloud_resources_created: true",
    "no_production_operations_enabled: true",
    "no_real_value_operations_enabled: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 3 operational runbook config content: $expected"
    }
}

if ($config -match "(?m)^\s*production_operations_enabled:\s+true\s*$") {
    throw "Production operations must remain disabled"
}

if ($config -match "(?m)^\s*creates_paid_resources:\s+true\s*$") {
    throw "Operational runbooks must not create paid resources"
}

if ($config -match "(?m)^\s*changes_google_cloud_resources:\s+true\s*$") {
    throw "Operational runbooks must not change Google Cloud resources"
}

if ($config -match "(?m)^\s*enables_gke_validator_operations:\s+true\s*$") {
    throw "GKE validator operations must remain deferred"
}

[pscustomobject]@{
    release_candidate = "phase3-operational-runbooks-rc1"
    status = "operational_runbooks_ready"
    operator_role_count = 6
    runbook_count = 7
    production_operations_enabled = $false
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    gke_validator_operations_enabled = $false
    real_value_capability_created = $false
    result = "ok"
}
