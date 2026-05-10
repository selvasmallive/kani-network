$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE5A_VALIDATOR_HARDENING_PLAN.md",
    "PHASE5A_VALIDATOR_RECONCILIATION.md",
    "config/phase5a-validator-hardening-plan.yaml",
    "config/phase5a-validator-reconciliation.yaml",
    "scripts/phase5a-validator-hardening-plan.ps1",
    "scripts/phase5a-validator-reconciliation.ps1",
    "PHASE4_WRAPUP.md",
    "config/phase4-wrapup.yaml",
    "scripts/phase4-validate.ps1",
    "scripts/phase3-validate.ps1",
    "scripts/phase2-validate.ps1"
)

$missing = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5A validation files: $($missing -join ', ')"
}

$plan = Get-Content "PHASE5A_VALIDATOR_HARDENING_PLAN.md" -Raw
foreach ($expected in @(
    "Status: validator hardening plan ready",
    "phase5a-validator-hardening-plan-rc1",
    "phase5a-no-gke-validator-hardening",
    "phase5b-gke-validator-ops",
    "phase2-lean-no-gke",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Cloud Run Job plus Cloud Scheduler",
    "validator_reconciliation_tests",
    "failure_and_retry_drills",
    "scheduler_pause_resume_runbooks",
    "ledger_replay_and_finality_verification",
    "operator_evidence_packs",
    "alert_response_and_recovery_drills",
    "complete_sandbox_smoke_tests",
    "No Google Cloud resources are created or changed"
)) {
    if ($plan -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A plan content: $expected"
    }
}

$reconciliation = Get-Content "PHASE5A_VALIDATOR_RECONCILIATION.md" -Raw
foreach ($expected in @(
    "Status: validator reconciliation checkpoint ready",
    "phase5a-validator-reconciliation-rc1",
    "validator_reconciliation_tests",
    "phase5a-validator-hardening-plan-rc1",
    "phase2-lean-no-gke",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Evidence Sources",
    "GET /v1/assets/{asset}/issued",
    "GET /v1/reports/validator-finality?limit=500&offset=0",
    "Required Reconciliation Checks",
    "pending_transactions_zero_after_sweep",
    "issued_supply_matches_reconciled_balances",
    "latest_block_finality_votes_at_least_two",
    "validator_report_active_validator_count_equals_three",
    "settlement_report_minted_amount_matches_issued_supply",
    "audit_events_include_authorization_and_finalization",
    "camt053_entries_match_journal_debits_and_credits",
    "Evidence Pack Schema",
    "Operator Procedure",
    "No Google Cloud resources are created or changed"
)) {
    if ($reconciliation -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A reconciliation content: $expected"
    }
}

$config = Get-Content "config/phase5a-validator-hardening-plan.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5a-validator-hardening-plan-rc1",
    "status: validator_hardening_plan_ready",
    "inherits_from: phase4-wrapup-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    "validator_count: 3",
    "validator_reconciliation_tests:",
    "failure_and_retry_drills:",
    "scheduler_pause_resume_runbooks:",
    "ledger_replay_and_finality_verification:",
    "operator_evidence_packs:",
    "alert_response_and_recovery_drills:",
    "complete_sandbox_smoke_tests:",
    "static_phase5a_validator_required: true",
    "aggregate_phase5a_validator_required: true",
    "phase4_validator_required: true",
    "phase3_validator_required: true",
    "phase2_validator_required: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A config content: $expected"
    }
}

$reconciliationConfig = Get-Content "config/phase5a-validator-reconciliation.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5a-validator-reconciliation-rc1",
    "status: validator_reconciliation_checkpoint_ready",
    "inherits_from: phase5a-validator-hardening-plan-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    "validator_count: 3",
    "evidence_sources:",
    "required_reconciliation_checks:",
    "pending_transactions_zero_after_sweep:",
    "issued_supply_matches_reconciled_balances:",
    "latest_block_finality_votes_at_least_two:",
    "latest_block_validator_in_validator_set:",
    "validator_report_required_finality_votes_equals_two:",
    "validator_report_active_validator_count_equals_three:",
    "settlement_report_minted_amount_matches_issued_supply:",
    "settlement_report_transfer_amount_matches_payments:",
    "audit_events_include_authorization_and_finalization:",
    "camt053_entries_match_journal_debits_and_credits:",
    "evidence_pack_schema:",
    "operator_procedure:",
    "phase5a_validator_reconciliation_checked_in: true",
    "aggregate_phase5a_validator_includes_reconciliation: true"
)) {
    if ($reconciliationConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A reconciliation config content: $expected"
    }
}

$phase4Wrapup = Get-Content "config/phase4-wrapup.yaml" -Raw
foreach ($expected in @(
    "next_phase: phase5a-no-gke-validator-hardening",
    "gke_phase: phase5b-gke-validator-ops",
    "phase5a_ready_to_start: true",
    "phase5b_gke_deferred: true",
    "validator_runtime: cloud_run_job_plus_cloud_scheduler"
)) {
    if ($phase4Wrapup -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 wrap-up handoff content: $expected"
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
    "live_failure_drills_enabled",
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
        throw "Phase 5A aggregate validator must not allow $forbidden"
    }
    if ($reconciliationConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A aggregate validator must not allow $forbidden in reconciliation"
    }
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$reconciliationValidatorCount = ([regex]::Matches($reconciliationConfig, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($reconciliationValidatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A reconciliation validators, found $reconciliationValidatorCount"
}

$workstreamCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($workstreamCount -lt 7) {
    throw "Expected at least 7 Phase 5A hardening workstreams, found $workstreamCount"
}

$evidenceSourceCount = ([regex]::Matches($reconciliationConfig, "(?m)^\s{2}[a-z0-9_]+:\s+GET\s+")).Count
if ($evidenceSourceCount -lt 13) {
    throw "Expected at least 13 Phase 5A evidence sources, found $evidenceSourceCount"
}

$reconciliationCheckCount = ([regex]::Matches($reconciliationConfig, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($reconciliationCheckCount -lt 10) {
    throw "Expected at least 10 Phase 5A reconciliation checks, found $reconciliationCheckCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 7) {
    throw "Expected at least 7 blocked Phase 5A live-drill gates, found $blockedGateCount"
}

[pscustomobject]@{
    phase = "phase-5a-no-gke-validator-hardening"
    release_candidate = "phase5a-validator-hardening-plan-rc1"
    status = "validator-hardening-plan-ready"
    validator_count = 3
    hardening_workstream_count = 7
    reconciliation_rc1 = $true
    evidence_source_count = $evidenceSourceCount
    reconciliation_check_count = 10
    blocked_live_drill_gate_count = $blockedGateCount
    active_runtime_baseline = "phase2-lean-no-gke"
    gke_required = $false
    gke_deferred_to = "phase5b-gke-validator-ops"
    google_cloud_resources_changed = $false
    scheduler_changes_enabled = $false
    live_failure_drills_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
