$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_LEDGER_REPLAY_FINALITY.md"
$configPath = "config/phase5a-ledger-replay-finality.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5A_FAILURE_RETRY_DRILLS.md",
    "config/phase5a-failure-retry-drills.yaml",
    "scripts/phase5a-failure-retry-drills.ps1",
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
    throw "Missing Phase 5A ledger replay and finality artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: ledger replay and finality checkpoint ready",
    "phase5a-ledger-replay-finality-rc1",
    "ledger_replay_and_finality_verification",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase5a-failure-retry-drills-rc1",
    "Verification Objective",
    "Finalized block heights are monotonic",
    "Every finalized block links to the expected previous hash",
    'Every block validator is inside `validator-a`, `validator-b`, and `validator-c`',
    "Every finalized block has at least 2 of 3 finality votes",
    "Replay Inputs",
    'GET /v1/blocks?limit=500&offset=0',
    "GET /v1/blocks/latest",
    "GET /v1/transactions/{id}",
    "GET /v1/assets/{asset}/issued",
    'GET /v1/reports/validator-finality?limit=500&offset=0',
    "Replay Procedure",
    "Required Replay Checks",
    "block_heights_are_monotonic",
    "block_prev_hash_chain_is_contiguous",
    "block_hashes_are_stable",
    "block_validators_are_in_validator_set",
    "finality_votes_are_at_least_two_of_three",
    "replayed_balances_match_account_balances",
    "replayed_issued_supply_matches_asset_supply",
    "settlement_report_matches_replayed_totals",
    "Replay Evidence Pack Schema",
    "Non-Enablement",
    "Live replay execution against production data",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A ledger replay and finality doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-ledger-replay-finality-rc1",
    "status: ledger_replay_finality_checkpoint_ready",
    "inherits_from: phase5a-failure-retry-drills-rc1",
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
    "production_replay_enabled: false",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    'scheduler_cadence: "*/15 * * * *"',
    "consensus: phase1-poa",
    "required_finality_votes: 2",
    "validator_count: 3",
    "validator-a",
    "validator-b",
    "validator-c",
    "replay_inputs:",
    'block_page: GET /v1/blocks?limit=500&offset=0',
    "latest_block: GET /v1/blocks/latest",
    "sampled_transactions: GET /v1/transactions/{id}",
    "issued_supply: GET /v1/assets/{asset}/issued",
    'validator_finality: GET /v1/reports/validator-finality?limit=500&offset=0',
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
    "production_replay_enabled: false",
    "phase5a_ledger_replay_finality_checked_in: true",
    "aggregate_phase5a_validator_includes_ledger_replay_finality: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A ledger replay and finality config content: $expected"
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
    "failure_injection_enabled",
    "live_failure_drills_enabled",
    "live_retry_drills_enabled",
    "production_replay_enabled",
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
        throw "Phase 5A ledger replay and finality must not enable $forbidden"
    }
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$replayInputCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+GET\s+")).Count
if ($replayInputCount -lt 11) {
    throw "Expected at least 11 ledger replay inputs, found $replayInputCount"
}

$replayStepCount = ([regex]::Matches($config, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($replayStepCount -lt 10) {
    throw "Expected at least 10 ledger replay procedure steps, found $replayStepCount"
}

$replayCheckCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($replayCheckCount -lt 12) {
    throw "Expected at least 12 ledger replay checks, found $replayCheckCount"
}

$requiredEvidenceFieldCount = ([regex]::Matches($config, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($requiredEvidenceFieldCount -lt 23) {
    throw "Expected at least 23 ledger replay evidence fields, found $requiredEvidenceFieldCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-ledger-replay-finality-rc1"
    status = "ledger_replay_finality_checkpoint_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    replay_input_count = $replayInputCount
    replay_step_count = 10
    replay_check_count = 12
    required_evidence_field_count = $requiredEvidenceFieldCount
    gke_required = $false
    google_cloud_resources_changed = $false
    production_replay_enabled = $false
    failure_injection_enabled = $false
    live_failure_drills_enabled = $false
    live_retry_drills_enabled = $false
    scheduler_changes_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
