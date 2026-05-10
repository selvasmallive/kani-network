$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_ALERT_RESPONSE_RECOVERY.md"
$configPath = "config/phase5a-alert-response-recovery.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5A_OPERATOR_EVIDENCE_PACKS.md",
    "config/phase5a-operator-evidence-packs.yaml",
    "scripts/phase5a-operator-evidence-packs.ps1",
    "PHASE5A_LEDGER_REPLAY_FINALITY.md",
    "config/phase5a-ledger-replay-finality.yaml",
    "PHASE5A_FAILURE_RETRY_DRILLS.md",
    "config/phase5a-failure-retry-drills.yaml",
    "PHASE5A_SCHEDULER_RUNBOOKS.md",
    "config/phase5a-scheduler-runbooks.yaml",
    "PHASE5A_VALIDATOR_RECONCILIATION.md",
    "config/phase5a-validator-reconciliation.yaml",
    "PHASE5A_VALIDATOR_HARDENING_PLAN.md",
    "config/phase5a-validator-hardening-plan.yaml"
)

$missing = @()
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5A alert response and recovery artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: alert response and recovery checkpoint ready",
    "phase5a-alert-response-recovery-rc1",
    "alert_response_and_recovery_drills",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase5a-operator-evidence-packs-rc1",
    "Response Objective",
    "Alert Classes",
    "api_error_logs",
    "validator_job_error_logs",
    "scheduler_error_logs",
    "cloud_sql_error_logs",
    "budget_brake_activity_logs",
    "validator_finality_gap",
    "pending_transaction_backlog",
    "ledger_reconciliation_discrepancy",
    "Required Response Stages",
    "detect",
    "classify",
    "contain",
    "collect_evidence",
    "recover",
    "reconcile",
    "review",
    "archive",
    "Evidence Sources",
    "Cloud Monitoring alert incident",
    "Cloud Logging query/export summary",
    "Cloud Run validator job execution state",
    "Cloud Scheduler job state",
    "Cloud SQL health and error evidence",
    'GET /v1/transactions/pending?limit=500&offset=0',
    'GET /v1/reports/validator-finality?limit=500&offset=0',
    "Recovery Action Catalog",
    "Required Gates Before Live Recovery Drill Or Action",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A alert response and recovery doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-alert-response-recovery-rc1",
    "status: alert_response_recovery_checkpoint_ready",
    "inherits_from: phase5a-operator-evidence-packs-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "scheduler_changes_enabled: false",
    "automatic_scheduler_mutation_enabled: false",
    "manual_scheduler_action_approved_by_this_checkpoint: false",
    "cloud_run_job_execution_approved_by_this_checkpoint: false",
    "secret_rotation_approved_by_this_checkpoint: false",
    "failure_injection_enabled: false",
    "live_failure_drills_enabled: false",
    "live_retry_drills_enabled: false",
    "live_recovery_drills_enabled: false",
    "production_replay_enabled: false",
    "external_evidence_export_enabled: false",
    "production_approval_via_evidence_pack_enabled: false",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    'scheduler_cadence: "*/15 * * * *"',
    "consensus: phase1-poa",
    "required_finality_votes: 2",
    "validator_count: 3",
    "validator-a",
    "validator-b",
    "validator-c",
    "alert_classes:",
    "api_error_logs:",
    "validator_job_error_logs:",
    "scheduler_error_logs:",
    "cloud_sql_error_logs:",
    "budget_brake_activity_logs:",
    "validator_finality_gap:",
    "pending_transaction_backlog:",
    "ledger_reconciliation_discrepancy:",
    "required_response_stages:",
    "detect:",
    "classify:",
    "contain:",
    "collect_evidence:",
    "recover:",
    "reconcile:",
    "review:",
    "archive:",
    "evidence_sources:",
    "cloud_monitoring_incident: Cloud Monitoring alert incident",
    "cloud_logging_query_export_summary: Cloud Logging query/export summary",
    "cloud_run_validator_job_execution_state: Cloud Run validator job execution state",
    "cloud_scheduler_job_state: Cloud Scheduler job state",
    "cloud_sql_health_error_evidence: Cloud SQL health and error evidence",
    'pending_transactions: GET /v1/transactions/pending?limit=500&offset=0',
    'validator_finality: GET /v1/reports/validator-finality?limit=500&offset=0',
    "recovery_action_catalog:",
    "required_gates_before_live_recovery_drill_or_action:",
    "sandbox_only_purpose_recorded: blocked",
    "incident_owner_assigned: blocked",
    "recovery_owner_assigned: blocked",
    "approver_identified: blocked",
    "change_window_approved: blocked",
    "expected_alert_signal_documented: blocked",
    "expected_recovery_signal_documented: blocked",
    "operator_evidence_pack_location_selected: blocked",
    "rollback_path_documented: blocked",
    "cost_impact_reviewed: blocked",
    "no_real_value_capability_enabled: blocked",
    "phase5a_alert_response_recovery_checked_in: true",
    "aggregate_phase5a_validator_includes_alert_response_recovery: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A alert response and recovery config content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "gke_cluster_enabled",
    "gke_required",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "cloud_armor_waf_applied",
    "mtls_trust_config_applied",
    "hsm_kms_production_signing_enabled",
    "scheduler_changes_enabled",
    "automatic_scheduler_mutation_enabled",
    "manual_scheduler_action_approved_by_this_checkpoint",
    "cloud_run_job_execution_approved_by_this_checkpoint",
    "secret_rotation_approved_by_this_checkpoint",
    "failure_injection_enabled",
    "live_failure_drills_enabled",
    "live_retry_drills_enabled",
    "live_recovery_drills_enabled",
    "production_replay_enabled",
    "external_evidence_export_enabled",
    "production_approval_via_evidence_pack_enabled",
    "restore_drill_executed",
    "production_recovery_executed",
    "external_institution_onboarding_enabled",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A alert response and recovery must not enable $forbidden"
    }
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$alertClassCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$", [System.Text.RegularExpressions.RegexOptions]::None)).Count
if ($alertClassCount -lt 8) {
    throw "Expected at least 8 alert classes and response keys, found $alertClassCount"
}

$requiredAlertClasses = @(
    "api_error_logs",
    "validator_job_error_logs",
    "scheduler_error_logs",
    "cloud_sql_error_logs",
    "budget_brake_activity_logs",
    "validator_finality_gap",
    "pending_transaction_backlog",
    "ledger_reconciliation_discrepancy"
)

foreach ($class in $requiredAlertClasses) {
    if ($config -notmatch "(?m)^\s{2}$($class):\s*$") {
        throw "Missing alert class: $class"
    }
}

$requiredResponseStages = @(
    "detect",
    "classify",
    "contain",
    "collect_evidence",
    "recover",
    "reconcile",
    "review",
    "archive"
)

foreach ($stage in $requiredResponseStages) {
    if ($config -notmatch "(?m)^\s{2}$($stage):\s*$") {
        throw "Missing response stage: $stage"
    }
}

$evidenceSourceCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+(GET|Cloud|Budget|phase5a-)")).Count
if ($evidenceSourceCount -lt 15) {
    throw "Expected at least 15 alert response evidence sources, found $evidenceSourceCount"
}

$blockedRecoveryGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedRecoveryGateCount -lt 11) {
    throw "Expected at least 11 blocked recovery gates, found $blockedRecoveryGateCount"
}

$recoveryActionCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($recoveryActionCount -lt 7) {
    throw "Expected at least 7 recovery action entries, found $recoveryActionCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-alert-response-recovery-rc1"
    status = "alert_response_recovery_checkpoint_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    alert_class_count = 8
    response_stage_count = 8
    evidence_source_count = $evidenceSourceCount
    blocked_recovery_gate_count = $blockedRecoveryGateCount
    recovery_action_count = 7
    gke_required = $false
    google_cloud_resources_changed = $false
    scheduler_changes_enabled = $false
    automatic_scheduler_mutation_enabled = $false
    manual_scheduler_action_approved_by_this_checkpoint = $false
    cloud_run_job_execution_approved_by_this_checkpoint = $false
    secret_rotation_approved_by_this_checkpoint = $false
    failure_injection_enabled = $false
    live_failure_drills_enabled = $false
    live_retry_drills_enabled = $false
    live_recovery_drills_enabled = $false
    production_replay_enabled = $false
    external_evidence_export_enabled = $false
    production_approval_via_evidence_pack_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
