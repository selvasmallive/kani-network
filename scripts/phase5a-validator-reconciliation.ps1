$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_VALIDATOR_RECONCILIATION.md"
$configPath = "config/phase5a-validator-reconciliation.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5A_VALIDATOR_HARDENING_PLAN.md",
    "config/phase5a-validator-hardening-plan.yaml",
    "scripts/phase5a-validator-hardening-plan.ps1"
)

$missing = @()
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5A validator reconciliation artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: validator reconciliation checkpoint ready",
    "phase5a-validator-reconciliation-rc1",
    "validator_reconciliation_tests",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase5a-validator-hardening-plan-rc1",
    "Reconciliation Objective",
    "Pending transactions drain to zero",
    "Fresh test asset issued supply matches",
    "2 of 3 finality votes",
    "validator-a",
    "validator-b",
    "validator-c",
    "Evidence Sources",
    "GET /health",
    "GET /v1/transactions/pending?limit=500&offset=0",
    "GET /v1/assets/{asset}/issued",
    "GET /v1/accounts/CORP_A/balances/{asset}",
    "GET /v1/accounts/CORP_B/balances/{asset}",
    "GET /v1/blocks/latest",
    "GET /v1/audit-events?limit=500&offset=0",
    "GET /v1/reports/settlement-summary?limit=500&offset=0",
    "GET /v1/reports/compliance-decisions?limit=500&offset=0",
    "GET /v1/reports/validator-finality?limit=500&offset=0",
    "GET /v1/validators",
    "GET /v1/iso20022/camt053/accounts/CORP_A?asset={asset}&limit=500&offset=0",
    "Required Reconciliation Checks",
    "pending_transactions_zero_after_sweep",
    "issued_supply_matches_reconciled_balances",
    "latest_block_finality_votes_at_least_two",
    "latest_block_validator_in_validator_set",
    "validator_report_required_finality_votes_equals_two",
    "validator_report_active_validator_count_equals_three",
    "settlement_report_minted_amount_matches_issued_supply",
    "settlement_report_transfer_amount_matches_payments",
    "audit_events_include_authorization_and_finalization",
    "camt053_entries_match_journal_debits_and_credits",
    "Evidence Pack Schema",
    "run_id",
    "reconciliation_results",
    "API keys",
    "Secret Manager values",
    "Operator Procedure",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A validator reconciliation doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-validator-reconciliation-rc1",
    "status: validator_reconciliation_checkpoint_ready",
    "inherits_from: phase5a-validator-hardening-plan-rc1",
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
    "live_failure_drills_enabled: false",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    'scheduler_cadence: "*/15 * * * *"',
    "consensus: phase1-poa",
    "required_finality_votes: 2",
    "validator_count: 3",
    "validator-a",
    "validator-b",
    "validator-c",
    "evidence_sources:",
    "health: GET /health",
    "pending_transactions: GET /v1/transactions/pending?limit=500&offset=0",
    "issued_supply: GET /v1/assets/{asset}/issued",
    "settlement_summary: GET /v1/reports/settlement-summary?limit=500&offset=0",
    "validator_finality: GET /v1/reports/validator-finality?limit=500&offset=0",
    "camt053_statement: GET /v1/iso20022/camt053/accounts/CORP_A?asset={asset}&limit=500&offset=0",
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
    "required_fields:",
    "forbidden_fields:",
    "api_keys",
    "bearer_tokens",
    "secret_manager_values",
    "raw_private_keys",
    "operator_procedure:",
    "scheduler_mutation_allowed: false",
    "live_failure_drill_allowed: false",
    "phase5a_validator_reconciliation_checked_in: true",
    "aggregate_phase5a_validator_includes_reconciliation: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A validator reconciliation config content: $expected"
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
    "production_go_live_allowed",
    "scheduler_mutation_allowed",
    "live_failure_drill_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 5A validator reconciliation must not enable $forbidden"
    }
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$evidenceSourceCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+GET\s+")).Count
if ($evidenceSourceCount -lt 13) {
    throw "Expected at least 13 Phase 5A evidence sources, found $evidenceSourceCount"
}

$requiredCheckCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($requiredCheckCount -lt 10) {
    throw "Expected at least 10 Phase 5A reconciliation checks, found $requiredCheckCount"
}

$requiredEvidenceFieldCount = ([regex]::Matches($config, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($requiredEvidenceFieldCount -lt 29) {
    throw "Expected at least 29 evidence pack required fields, found $requiredEvidenceFieldCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-validator-reconciliation-rc1"
    status = "validator_reconciliation_checkpoint_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    evidence_source_count = $evidenceSourceCount
    reconciliation_check_count = 10
    required_evidence_field_count = $requiredEvidenceFieldCount
    gke_required = $false
    google_cloud_resources_changed = $false
    scheduler_changes_enabled = $false
    live_failure_drills_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
