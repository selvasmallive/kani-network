$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_FAILURE_RETRY_DRILLS.md"
$configPath = "config/phase5a-failure-retry-drills.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5A_SCHEDULER_RUNBOOKS.md",
    "config/phase5a-scheduler-runbooks.yaml",
    "scripts/phase5a-scheduler-runbooks.ps1",
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
    throw "Missing Phase 5A failure and retry drill artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: failure and retry drill plan ready",
    "phase5a-failure-retry-drills-rc1",
    "failure_and_retry_drills",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase5a-scheduler-runbooks-rc1",
    "Drill Objective",
    "No double finalization",
    "No duplicate payment settlement",
    "Idempotent payment retry behavior remains intact",
    "Drill Matrix",
    "validator_job_retry_after_transient_failure",
    "scheduler_missed_trigger_detection",
    "manual_validator_rerun_after_pending_queue",
    "idempotent_payment_retry_after_client_timeout",
    "compliance_hold_release_retry",
    "database_connectivity_transient_failure",
    "cost_guard_scheduler_pause_recovery",
    "validator_report_reconciliation_after_retry",
    "Required Gates Before Live Drill Execution",
    "Drill owner assigned",
    "Recovery owner assigned",
    "Expected failure signal documented",
    "Expected retry signal documented",
    "Required Evidence",
    "pre-drill pending transaction count",
    "post-retry validator state",
    "Recovery Expectations",
    "Finality votes remain at least 2 of 3",
    "Non-Enablement",
    "Failure injection",
    "Live drill execution",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A failure and retry drill doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-failure-retry-drills-rc1",
    "status: failure_retry_drill_plan_ready",
    "inherits_from: phase5a-scheduler-runbooks-rc1",
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
    "failure_injection_enabled: false",
    "live_failure_drills_enabled: false",
    "live_retry_drills_enabled: false",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    'scheduler_cadence: "*/15 * * * *"',
    "consensus: phase1-poa",
    "required_finality_votes: 2",
    "validator_count: 3",
    "validator-a",
    "validator-b",
    "validator-c",
    "drill_matrix:",
    "validator_job_retry_after_transient_failure:",
    "scheduler_missed_trigger_detection:",
    "manual_validator_rerun_after_pending_queue:",
    "idempotent_payment_retry_after_client_timeout:",
    "compliance_hold_release_retry:",
    "database_connectivity_transient_failure:",
    "cost_guard_scheduler_pause_recovery:",
    "validator_report_reconciliation_after_retry:",
    "live_execution_allowed: false",
    "required_gates_before_live_drill_execution:",
    "sandbox_only_purpose_recorded: blocked",
    "drill_owner_assigned: blocked",
    "recovery_owner_assigned: blocked",
    "expected_failure_signal_documented: blocked",
    "expected_retry_signal_documented: blocked",
    "real_value_capability_confirmed_disabled: blocked",
    "required_evidence:",
    "pre_drill_pending_transaction_count",
    "post_retry_validator_state",
    "forbidden_evidence_fields:",
    "api_keys",
    "secret_manager_values",
    "success_criteria:",
    "pending_transactions_reach_expected_terminal_state: required",
    "finality_votes_at_least_two_of_three: required",
    "issued_supply_equals_reconciled_balances: required",
    "phase5a_failure_retry_drills_checked_in: true",
    "aggregate_phase5a_validator_includes_failure_retry_drills: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A failure and retry drill config content: $expected"
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
    "failure_injection_enabled",
    "live_failure_drills_enabled",
    "live_retry_drills_enabled",
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
        throw "Phase 5A failure and retry drills must not enable $forbidden"
    }
}

if ($config -match "(?m)^\s*live_execution_allowed:\s+true\s*$") {
    throw "Phase 5A failure and retry drill matrix must not allow live execution"
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$drillCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($drillCount -lt 8) {
    throw "Expected at least 8 failure and retry drills, found $drillCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 14) {
    throw "Expected at least 14 blocked live-drill gates, found $blockedGateCount"
}

$requiredEvidenceCount = ([regex]::Matches($config, "(?m)^\s{2}- [a-z0-9_]+\s*$")).Count
if ($requiredEvidenceCount -lt 19) {
    throw "Expected at least 19 required evidence items, found $requiredEvidenceCount"
}

$successCriteriaCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+required\s*$")).Count
if ($successCriteriaCount -lt 8) {
    throw "Expected at least 8 success criteria, found $successCriteriaCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-failure-retry-drills-rc1"
    status = "failure_retry_drill_plan_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    drill_count = 8
    blocked_live_drill_gate_count = $blockedGateCount
    required_evidence_count = $requiredEvidenceCount
    success_criteria_count = $successCriteriaCount
    gke_required = $false
    google_cloud_resources_changed = $false
    failure_injection_enabled = $false
    live_failure_drills_enabled = $false
    live_retry_drills_enabled = $false
    scheduler_changes_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
