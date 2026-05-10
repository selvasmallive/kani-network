$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_WRAPUP.md"
$configPath = "config/phase5a-wrapup.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5A_SANDBOX_SMOKE_COVERAGE.md",
    "config/phase5a-sandbox-smoke-coverage.yaml",
    "scripts/phase5a-sandbox-smoke-coverage.ps1",
    "PHASE5A_ALERT_RESPONSE_RECOVERY.md",
    "config/phase5a-alert-response-recovery.yaml",
    "scripts/phase5a-alert-response-recovery.ps1",
    "PHASE5A_OPERATOR_EVIDENCE_PACKS.md",
    "config/phase5a-operator-evidence-packs.yaml",
    "PHASE5A_LEDGER_REPLAY_FINALITY.md",
    "config/phase5a-ledger-replay-finality.yaml",
    "PHASE5A_FAILURE_RETRY_DRILLS.md",
    "config/phase5a-failure-retry-drills.yaml",
    "PHASE5A_SCHEDULER_RUNBOOKS.md",
    "config/phase5a-scheduler-runbooks.yaml",
    "PHASE5A_VALIDATOR_RECONCILIATION.md",
    "config/phase5a-validator-reconciliation.yaml",
    "PHASE5A_VALIDATOR_HARDENING_PLAN.md",
    "config/phase5a-validator-hardening-plan.yaml",
    "PHASE4_WRAPUP.md",
    "config/phase4-wrapup.yaml"
)

$missing = @()
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5A wrap-up artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: no-GKE validator hardening complete",
    "phase5a-wrapup-rc1",
    "phase5a-no-gke-validator-hardening",
    "phase5a-sandbox-smoke-coverage-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Completed Phase 5A Checkpoints",
    "phase5a-validator-hardening-plan-rc1",
    "phase5a-validator-reconciliation-rc1",
    "phase5a-scheduler-runbooks-rc1",
    "phase5a-failure-retry-drills-rc1",
    "phase5a-ledger-replay-finality-rc1",
    "phase5a-operator-evidence-packs-rc1",
    "phase5a-alert-response-recovery-rc1",
    "phase5a-sandbox-smoke-coverage-rc1",
    "Phase 5A Result",
    "No-GKE validator hardening plan",
    "Aggregate Phase 5A validator coverage",
    "GKE validator operations",
    "Live failure, retry, recovery, or smoke execution approval",
    'move into `phase5b-gke-validator-ops`',
    "Required Blocks That Remain",
    "GKE resource approval",
    "Production authorization",
    "Real-value settlement",
    "Non-Enablement",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A wrap-up doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-wrapup-rc1",
    "status: no_gke_validator_hardening_complete",
    "inherits_from: phase5a-sandbox-smoke-coverage-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "next_phase: phase5b-gke-validator-ops",
    "gke_phase: phase5b-gke-validator-ops",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "completed_release_candidates:",
    "phase5a_validator_hardening_plan_rc1: true",
    "phase5a_validator_reconciliation_rc1: true",
    "phase5a_scheduler_runbooks_rc1: true",
    "phase5a_failure_retry_drills_rc1: true",
    "phase5a_ledger_replay_finality_rc1: true",
    "phase5a_operator_evidence_packs_rc1: true",
    "phase5a_alert_response_recovery_rc1: true",
    "phase5a_sandbox_smoke_coverage_rc1: true",
    "phase_result:",
    "no_gke_validator_hardening_complete: true",
    "planning_validation_and_evidence_only: true",
    "cloud_run_scheduler_runtime_preserved: true",
    "aggregate_phase5a_validator_coverage_complete: true",
    "phase5a_ready_to_close: true",
    "phase5b_ready_for_planning: true",
    "phase5b_execution_deferred: true",
    "production_ready: false",
    "real_value_ready: false",
    "google_cloud_resources_created: false",
    "paid_resources_created: false",
    "terraform_apply_allowed: false",
    "gke_required: false",
    "gke_cluster_enabled: false",
    "phase5b_handoff:",
    "gke_required_for_phase5a: false",
    "execution_deferred_until_explicit_approval: true",
    "gke_validator_operations_cost_estimate",
    "remaining_blocked_gates:",
    "gke_resource_approval: blocked",
    "gke_cost_estimate_approval: blocked",
    "terraform_plan_review: blocked",
    "live_validator_operations_approval: blocked",
    "production_authorization: blocked",
    "real_value_settlement: blocked",
    "non_enablement:",
    "live_drill_execution_approved_by_this_checkpoint: false",
    "phase5a_wrapup_checked_in: true",
    "aggregate_phase5a_validator_includes_wrapup: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A wrap-up config content: $expected"
    }
}

foreach ($forbidden in @(
    "production_ready",
    "real_value_ready",
    "legal_advice_provided",
    "google_cloud_resources_created",
    "paid_resources_created",
    "terraform_apply_allowed",
    "gke_required",
    "gke_cluster_enabled",
    "scheduler_changes_enabled",
    "cloud_run_job_execution_approved_by_this_checkpoint",
    "live_drill_execution_approved_by_this_checkpoint",
    "live_sandbox_smoke_execution_enabled",
    "production_bft_validator_network_enabled",
    "production_ingress_enabled",
    "public_endpoint_exposure_enabled",
    "cloud_armor_waf_applied",
    "mtls_trust_config_applied",
    "hsm_kms_production_signing_enabled",
    "failure_injection_enabled",
    "live_failure_drills_enabled",
    "live_retry_drills_enabled",
    "live_recovery_drills_enabled",
    "production_replay_enabled",
    "restore_drill_executed",
    "production_recovery_executed",
    "external_evidence_export_enabled",
    "production_approval_via_evidence_pack_enabled",
    "external_institution_onboarding_enabled",
    "production_authorization_granted",
    "legal_or_compliance_approval_enabled",
    "real_value_settlement_enabled",
    "fiat_deposit_or_redemption_enabled",
    "custody_for_others_enabled",
    "trading_enabled",
    "google_cloud_resource_creation_allowed",
    "paid_resource_enablement_allowed",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A wrap-up must not enable $forbidden"
    }
}

$completedCount = ([regex]::Matches($config, "phase5a_[a-z0-9_]+_rc1:\s+true")).Count
if ($completedCount -lt 8) {
    throw "Expected at least 8 completed Phase 5A release candidates, found $completedCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 24) {
    throw "Expected at least 24 blocked Phase 5A wrap-up gates, found $blockedGateCount"
}

$handoffFocusCount = ([regex]::Matches($config, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($handoffFocusCount -lt 8) {
    throw "Expected at least 8 Phase 5B handoff focus items, found $handoffFocusCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-wrapup-rc1"
    status = "no_gke_validator_hardening_complete"
    track = "phase5a-no-gke-validator-hardening"
    completed_release_candidate_count = 8
    blocked_gate_count = $blockedGateCount
    handoff_focus_count = $handoffFocusCount
    active_runtime_baseline = "phase2-lean-no-gke"
    next_phase = "phase5b-gke-validator-ops"
    gke_required = $false
    gke_enabled = $false
    google_cloud_resources_created = $false
    scheduler_changes_enabled = $false
    cloud_run_job_execution_approved_by_this_checkpoint = $false
    live_drill_execution_approved_by_this_checkpoint = $false
    live_sandbox_smoke_execution_enabled = $false
    production_authorization_enabled = $false
    legal_or_compliance_approval_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
