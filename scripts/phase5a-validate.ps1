$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE5A_VALIDATOR_HARDENING_PLAN.md",
    "PHASE5A_VALIDATOR_RECONCILIATION.md",
    "PHASE5A_SCHEDULER_RUNBOOKS.md",
    "PHASE5A_FAILURE_RETRY_DRILLS.md",
    "PHASE5A_LEDGER_REPLAY_FINALITY.md",
    "PHASE5A_OPERATOR_EVIDENCE_PACKS.md",
    "PHASE5A_ALERT_RESPONSE_RECOVERY.md",
    "config/phase5a-validator-hardening-plan.yaml",
    "config/phase5a-validator-reconciliation.yaml",
    "config/phase5a-scheduler-runbooks.yaml",
    "config/phase5a-failure-retry-drills.yaml",
    "config/phase5a-ledger-replay-finality.yaml",
    "config/phase5a-operator-evidence-packs.yaml",
    "config/phase5a-alert-response-recovery.yaml",
    "scripts/phase5a-validator-hardening-plan.ps1",
    "scripts/phase5a-validator-reconciliation.ps1",
    "scripts/phase5a-scheduler-runbooks.ps1",
    "scripts/phase5a-failure-retry-drills.ps1",
    "scripts/phase5a-ledger-replay-finality.ps1",
    "scripts/phase5a-operator-evidence-packs.ps1",
    "scripts/phase5a-alert-response-recovery.ps1",
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

$schedulerRunbooks = Get-Content "PHASE5A_SCHEDULER_RUNBOOKS.md" -Raw
foreach ($expected in @(
    "Status: scheduler runbooks checkpoint ready",
    "phase5a-scheduler-runbooks-rc1",
    "scheduler_pause_resume_runbooks",
    "phase5a-validator-reconciliation-rc1",
    "phase2-lean-no-gke",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "kani-sandbox-validator-scheduler",
    "kani-sandbox-validator",
    "Required Approvals Before Any Manual Scheduler Action",
    "Pre-Pause Checks",
    "Pause Scheduler",
    "Manual Validator Execution",
    "Resume Scheduler",
    "Post-Resume Reconciliation",
    "Rollback And Escalation",
    "Evidence Pack",
    "No Google Cloud resources are created or changed"
)) {
    if ($schedulerRunbooks -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A scheduler runbook content: $expected"
    }
}

$failureRetryDrills = Get-Content "PHASE5A_FAILURE_RETRY_DRILLS.md" -Raw
foreach ($expected in @(
    "Status: failure and retry drill plan ready",
    "phase5a-failure-retry-drills-rc1",
    "failure_and_retry_drills",
    "phase5a-scheduler-runbooks-rc1",
    "phase2-lean-no-gke",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
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
    "Required Evidence",
    "Recovery Expectations",
    "No Google Cloud resources are created or changed"
)) {
    if ($failureRetryDrills -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A failure and retry drill content: $expected"
    }
}

$ledgerReplayFinality = Get-Content "PHASE5A_LEDGER_REPLAY_FINALITY.md" -Raw
foreach ($expected in @(
    "Status: ledger replay and finality checkpoint ready",
    "phase5a-ledger-replay-finality-rc1",
    "ledger_replay_and_finality_verification",
    "phase5a-failure-retry-drills-rc1",
    "phase2-lean-no-gke",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Verification Objective",
    "Replay Inputs",
    "Replay Procedure",
    "Required Replay Checks",
    "block_heights_are_monotonic",
    "block_prev_hash_chain_is_contiguous",
    "finality_votes_are_at_least_two_of_three",
    "replayed_balances_match_account_balances",
    "replayed_issued_supply_matches_asset_supply",
    "Replay Evidence Pack Schema",
    "No Google Cloud resources are created or changed"
)) {
    if ($ledgerReplayFinality -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A ledger replay and finality content: $expected"
    }
}

$operatorEvidencePacks = Get-Content "PHASE5A_OPERATOR_EVIDENCE_PACKS.md" -Raw
foreach ($expected in @(
    "Status: operator evidence packs checkpoint ready",
    "phase5a-operator-evidence-packs-rc1",
    "operator_evidence_packs",
    "phase5a-ledger-replay-finality-rc1",
    "phase2-lean-no-gke",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "Evidence Pack Types",
    "validator_reconciliation_pack",
    "scheduler_pause_resume_pack",
    "failure_retry_drill_pack",
    "ledger_replay_finality_pack",
    "alert_response_recovery_pack",
    "sandbox_smoke_test_pack",
    "phase5a_wrapup_pack",
    "Required Common Metadata",
    "Required Evidence Sections",
    "Redaction Rules",
    "Review Workflow",
    "Retention Labels",
    "No Google Cloud resources are created or changed"
)) {
    if ($operatorEvidencePacks -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A operator evidence pack content: $expected"
    }
}

$alertResponseRecovery = Get-Content "PHASE5A_ALERT_RESPONSE_RECOVERY.md" -Raw
foreach ($expected in @(
    "Status: alert response and recovery checkpoint ready",
    "phase5a-alert-response-recovery-rc1",
    "alert_response_and_recovery_drills",
    "phase5a-operator-evidence-packs-rc1",
    "phase2-lean-no-gke",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
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
    "collect_evidence",
    "Evidence Sources",
    "Cloud Monitoring alert incident",
    "Cloud Logging query/export summary",
    "Cloud Run validator job execution state",
    "Cloud Scheduler job state",
    "Cloud SQL health and error evidence",
    "Recovery Action Catalog",
    "Required Gates Before Live Recovery Drill Or Action",
    "No Google Cloud resources are created or changed"
)) {
    if ($alertResponseRecovery -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A alert response and recovery content: $expected"
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

$schedulerConfig = Get-Content "config/phase5a-scheduler-runbooks.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5a-scheduler-runbooks-rc1",
    "status: scheduler_runbooks_checkpoint_ready",
    "inherits_from: phase5a-validator-reconciliation-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "scheduler_job: kani-sandbox-validator-scheduler",
    "validator_job: kani-sandbox-validator",
    "project_id: kani-network-sandbox",
    "region: northamerica-northeast1",
    "validator_run_mode: sweep",
    "validator_count: 3",
    "required_approvals_before_manual_scheduler_action:",
    "sandbox_only_purpose_recorded: blocked",
    "change_window_approved: blocked",
    "real_value_capability_confirmed_disabled: blocked",
    "runbook_steps:",
    "pre_pause_checks:",
    "pause_scheduler:",
    "manual_validator_execution:",
    "resume_scheduler:",
    "post_resume_reconciliation:",
    "rollback_and_escalation:",
    "evidence_pack:",
    "command_templates:",
    "phase5a_scheduler_runbooks_checked_in: true",
    "aggregate_phase5a_validator_includes_scheduler_runbooks: true"
)) {
    if ($schedulerConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A scheduler config content: $expected"
    }
}

$failureRetryConfig = Get-Content "config/phase5a-failure-retry-drills.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5a-failure-retry-drills-rc1",
    "status: failure_retry_drill_plan_ready",
    "inherits_from: phase5a-scheduler-runbooks-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "validator_count: 3",
    "failure_injection_enabled: false",
    "live_failure_drills_enabled: false",
    "live_retry_drills_enabled: false",
    "drill_matrix:",
    "validator_job_retry_after_transient_failure:",
    "scheduler_missed_trigger_detection:",
    "manual_validator_rerun_after_pending_queue:",
    "idempotent_payment_retry_after_client_timeout:",
    "compliance_hold_release_retry:",
    "database_connectivity_transient_failure:",
    "cost_guard_scheduler_pause_recovery:",
    "validator_report_reconciliation_after_retry:",
    "required_gates_before_live_drill_execution:",
    "drill_owner_assigned: blocked",
    "recovery_owner_assigned: blocked",
    "expected_failure_signal_documented: blocked",
    "expected_retry_signal_documented: blocked",
    "required_evidence:",
    "success_criteria:",
    "phase5a_failure_retry_drills_checked_in: true",
    "aggregate_phase5a_validator_includes_failure_retry_drills: true"
)) {
    if ($failureRetryConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A failure and retry config content: $expected"
    }
}

$ledgerReplayConfig = Get-Content "config/phase5a-ledger-replay-finality.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5a-ledger-replay-finality-rc1",
    "status: ledger_replay_finality_checkpoint_ready",
    "inherits_from: phase5a-failure-retry-drills-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "validator_count: 3",
    "production_replay_enabled: false",
    "replay_inputs:",
    "block_page: GET /v1/blocks?limit=500&offset=0",
    "latest_block: GET /v1/blocks/latest",
    "sampled_transactions: GET /v1/transactions/{id}",
    "issued_supply: GET /v1/assets/{asset}/issued",
    "replay_procedure:",
    "required_replay_checks:",
    "block_heights_are_monotonic:",
    "block_prev_hash_chain_is_contiguous:",
    "block_hashes_are_stable:",
    "block_validators_are_in_validator_set:",
    "finality_votes_are_at_least_two_of_three:",
    "finality_votes_are_in_validator_set:",
    "replayed_balances_match_account_balances:",
    "replayed_issued_supply_matches_asset_supply:",
    "settlement_report_matches_replayed_totals:",
    "audit_events_include_block_and_transaction_evidence:",
    "camt053_entries_match_replayed_journal_entries:",
    "pending_transactions_zero_or_explained:",
    "evidence_pack_schema:",
    "phase5a_ledger_replay_finality_checked_in: true",
    "aggregate_phase5a_validator_includes_ledger_replay_finality: true"
)) {
    if ($ledgerReplayConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A ledger replay and finality config content: $expected"
    }
}

$operatorEvidenceConfig = Get-Content "config/phase5a-operator-evidence-packs.yaml" -Raw
foreach ($expected in @(
    "release_candidate: phase5a-operator-evidence-packs-rc1",
    "status: operator_evidence_packs_checkpoint_ready",
    "inherits_from: phase5a-ledger-replay-finality-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "validator_count: 3",
    "external_evidence_export_enabled: false",
    "production_approval_via_evidence_pack_enabled: false",
    "evidence_pack_types:",
    "validator_reconciliation_pack:",
    "scheduler_pause_resume_pack:",
    "failure_retry_drill_pack:",
    "ledger_replay_finality_pack:",
    "alert_response_recovery_pack:",
    "sandbox_smoke_test_pack:",
    "phase5a_wrapup_pack:",
    "required_common_metadata:",
    "required_evidence_sections:",
    "redaction_rules:",
    "review_workflow:",
    "retention_labels:",
    "phase5a_operator_evidence_packs_checked_in: true",
    "aggregate_phase5a_validator_includes_operator_evidence_packs: true"
)) {
    if ($operatorEvidenceConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A operator evidence pack config content: $expected"
    }
}

$alertResponseConfig = Get-Content "config/phase5a-alert-response-recovery.yaml" -Raw
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
    "structured_phase5a_alert_response_recovery_config_exists: true",
    "static_phase5a_alert_response_recovery_validator_required: true",
    "aggregate_phase5a_validator_includes_alert_response_recovery: true"
)) {
    if ($alertResponseConfig -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A alert response and recovery config content: $expected"
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
        throw "Phase 5A aggregate validator must not allow $forbidden"
    }
    if ($reconciliationConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A aggregate validator must not allow $forbidden in reconciliation"
    }
    if ($schedulerConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A aggregate validator must not allow $forbidden in scheduler runbooks"
    }
    if ($failureRetryConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A aggregate validator must not allow $forbidden in failure and retry drills"
    }
    if ($ledgerReplayConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A aggregate validator must not allow $forbidden in ledger replay and finality"
    }
    if ($operatorEvidenceConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A aggregate validator must not allow $forbidden in operator evidence packs"
    }
    if ($alertResponseConfig -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A aggregate validator must not allow $forbidden in alert response and recovery"
    }
}

if ($operatorEvidenceConfig -match "(?m)^\s*production_approval_allowed:\s+true\s*$") {
    throw "Phase 5A operator evidence packs must not allow production approval"
}

if ($failureRetryConfig -match "(?m)^\s*live_execution_allowed:\s+true\s*$") {
    throw "Phase 5A failure and retry drill matrix must not allow live execution"
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$reconciliationValidatorCount = ([regex]::Matches($reconciliationConfig, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($reconciliationValidatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A reconciliation validators, found $reconciliationValidatorCount"
}

$schedulerValidatorCount = ([regex]::Matches($schedulerConfig, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($schedulerValidatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A scheduler validators, found $schedulerValidatorCount"
}

$failureRetryValidatorCount = ([regex]::Matches($failureRetryConfig, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($failureRetryValidatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A failure and retry validators, found $failureRetryValidatorCount"
}

$ledgerReplayValidatorCount = ([regex]::Matches($ledgerReplayConfig, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($ledgerReplayValidatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A ledger replay validators, found $ledgerReplayValidatorCount"
}

$operatorEvidenceValidatorCount = ([regex]::Matches($operatorEvidenceConfig, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($operatorEvidenceValidatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A operator evidence validators, found $operatorEvidenceValidatorCount"
}

$alertResponseValidatorCount = ([regex]::Matches($alertResponseConfig, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($alertResponseValidatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A alert response validators, found $alertResponseValidatorCount"
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

$schedulerApprovalGateCount = ([regex]::Matches($schedulerConfig, ":\s+blocked")).Count
if ($schedulerApprovalGateCount -lt 11) {
    throw "Expected at least 11 Phase 5A scheduler approval gates, found $schedulerApprovalGateCount"
}

$schedulerRunbookStepCount = ([regex]::Matches($schedulerConfig, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($schedulerRunbookStepCount -lt 7) {
    throw "Expected at least 7 Phase 5A scheduler runbook steps, found $schedulerRunbookStepCount"
}

$schedulerCommandTemplateCount = ([regex]::Matches($schedulerConfig, "(?m)^\s{2}[a-z0-9_]+:\s+gcloud\s+")).Count
if ($schedulerCommandTemplateCount -lt 5) {
    throw "Expected at least 5 Phase 5A scheduler command templates, found $schedulerCommandTemplateCount"
}

$failureRetryDrillCount = ([regex]::Matches($failureRetryConfig, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($failureRetryDrillCount -lt 8) {
    throw "Expected at least 8 Phase 5A failure and retry drills, found $failureRetryDrillCount"
}

$failureRetryBlockedGateCount = ([regex]::Matches($failureRetryConfig, ":\s+blocked")).Count
if ($failureRetryBlockedGateCount -lt 14) {
    throw "Expected at least 14 Phase 5A failure and retry approval gates, found $failureRetryBlockedGateCount"
}

$failureRetryRequiredEvidenceCount = ([regex]::Matches($failureRetryConfig, "(?m)^\s{2}- [a-z0-9_]+\s*$")).Count
if ($failureRetryRequiredEvidenceCount -lt 19) {
    throw "Expected at least 19 Phase 5A failure and retry evidence items, found $failureRetryRequiredEvidenceCount"
}

$ledgerReplayInputCount = ([regex]::Matches($ledgerReplayConfig, "(?m)^\s{2}[a-z0-9_]+:\s+GET\s+")).Count
if ($ledgerReplayInputCount -lt 11) {
    throw "Expected at least 11 Phase 5A ledger replay inputs, found $ledgerReplayInputCount"
}

$ledgerReplayCheckCount = ([regex]::Matches($ledgerReplayConfig, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($ledgerReplayCheckCount -lt 12) {
    throw "Expected at least 12 Phase 5A ledger replay checks, found $ledgerReplayCheckCount"
}

$operatorEvidencePackTypeCount = ([regex]::Matches($operatorEvidenceConfig, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($operatorEvidencePackTypeCount -lt 7) {
    throw "Expected at least 7 Phase 5A operator evidence pack types, found $operatorEvidencePackTypeCount"
}

$operatorEvidenceForbiddenFieldCount = ([regex]::Matches($operatorEvidenceConfig, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($operatorEvidenceForbiddenFieldCount -lt 9) {
    throw "Expected at least 9 Phase 5A operator evidence redaction fields, found $operatorEvidenceForbiddenFieldCount"
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
    if ($alertResponseConfig -notmatch "(?m)^\s{2}$($class):\s*$") {
        throw "Missing Phase 5A alert response class: $class"
    }
}

$requiredAlertResponseStages = @(
    "detect",
    "classify",
    "contain",
    "collect_evidence",
    "recover",
    "reconcile",
    "review",
    "archive"
)

foreach ($stage in $requiredAlertResponseStages) {
    if ($alertResponseConfig -notmatch "(?m)^\s{2}$($stage):\s*$") {
        throw "Missing Phase 5A alert response stage: $stage"
    }
}

$alertResponseEvidenceSourceCount = ([regex]::Matches($alertResponseConfig, "(?m)^\s{2}[a-z0-9_]+:\s+(GET|Cloud|Budget|phase5a-)")).Count
if ($alertResponseEvidenceSourceCount -lt 15) {
    throw "Expected at least 15 Phase 5A alert response evidence sources, found $alertResponseEvidenceSourceCount"
}

$alertResponseRecoveryGateCount = ([regex]::Matches($alertResponseConfig, ":\s+blocked")).Count
if ($alertResponseRecoveryGateCount -lt 11) {
    throw "Expected at least 11 Phase 5A alert response recovery gates, found $alertResponseRecoveryGateCount"
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
    scheduler_runbooks_rc1 = $true
    failure_retry_drills_rc1 = $true
    ledger_replay_finality_rc1 = $true
    operator_evidence_packs_rc1 = $true
    alert_response_recovery_rc1 = $true
    evidence_source_count = $evidenceSourceCount
    reconciliation_check_count = 10
    scheduler_approval_gate_count = $schedulerApprovalGateCount
    scheduler_runbook_step_count = 7
    scheduler_command_template_count = $schedulerCommandTemplateCount
    failure_retry_drill_count = 8
    failure_retry_approval_gate_count = $failureRetryBlockedGateCount
    failure_retry_required_evidence_count = $failureRetryRequiredEvidenceCount
    ledger_replay_input_count = $ledgerReplayInputCount
    ledger_replay_check_count = 12
    operator_evidence_pack_type_count = 7
    operator_evidence_redaction_field_count = $operatorEvidenceForbiddenFieldCount
    alert_class_count = 8
    alert_response_stage_count = 8
    alert_response_evidence_source_count = $alertResponseEvidenceSourceCount
    alert_response_recovery_gate_count = $alertResponseRecoveryGateCount
    blocked_live_drill_gate_count = $blockedGateCount
    active_runtime_baseline = "phase2-lean-no-gke"
    gke_required = $false
    gke_deferred_to = "phase5b-gke-validator-ops"
    google_cloud_resources_changed = $false
    scheduler_changes_enabled = $false
    automatic_scheduler_mutation_enabled = $false
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
