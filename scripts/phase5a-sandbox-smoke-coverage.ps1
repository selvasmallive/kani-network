$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_SANDBOX_SMOKE_COVERAGE.md"
$configPath = "config/phase5a-sandbox-smoke-coverage.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "scripts/smoke-test.ps1",
    "scripts/phase2-cloud-smoke.ps1",
    "scripts/phase2-security-smoke.ps1",
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
    "config/phase5a-validator-hardening-plan.yaml"
)

$missing = @()
foreach ($file in $requiredArtifacts) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 5A sandbox smoke coverage artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: sandbox smoke coverage checkpoint ready",
    "phase5a-sandbox-smoke-coverage-rc1",
    "complete_sandbox_smoke_tests",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase5a-alert-response-recovery-rc1",
    "Coverage Objective",
    "Required Smoke Controls",
    "runtime_health",
    "sandbox_mint",
    "payment_transfer",
    "validator_sweep",
    "pending_queue_clearance",
    "poa_finality",
    "balance_reconciliation",
    "issued_supply_reconciliation",
    "iso_pacs008_submission",
    "iso_pacs002_status",
    "iso_camt053_statement",
    "compliance_self_transfer_rejection",
    "settlement_reporting",
    "compliance_reporting",
    "validator_finality_reporting",
    "audit_event_reporting",
    "Evidence Sources",
    "scripts/smoke-test.ps1",
    "scripts/phase2-cloud-smoke.ps1",
    "scripts/phase2-security-smoke.ps1",
    "GET /health",
    "POST /v1/sandbox/mint",
    "POST /v1/payments",
    "POST /v1/iso20022/pacs008",
    "GET /v1/blocks/latest",
    "Execution Gates",
    "Expected Outcomes",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A sandbox smoke coverage doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-sandbox-smoke-coverage-rc1",
    "status: sandbox_smoke_coverage_checkpoint_ready",
    "inherits_from: phase5a-alert-response-recovery-rc1",
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
    "cloud_smoke_execution_approved_by_this_checkpoint: false",
    "local_smoke_execution_approved_by_this_checkpoint: false",
    "live_sandbox_smoke_execution_enabled: false",
    "destructive_smoke_reset_enabled: false",
    "external_endpoint_smoke_enabled: false",
    "failure_injection_enabled: false",
    "live_failure_drills_enabled: false",
    "live_retry_drills_enabled: false",
    "live_recovery_drills_enabled: false",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    'scheduler_cadence: "*/15 * * * *"',
    "consensus: phase1-poa",
    "required_finality_votes: 2",
    "validator_count: 3",
    "validator-a",
    "validator-b",
    "validator-c",
    "smoke_scripts:",
    "local_smoke: scripts/smoke-test.ps1",
    "cloud_smoke: scripts/phase2-cloud-smoke.ps1",
    "security_smoke: scripts/phase2-security-smoke.ps1",
    "required_smoke_controls:",
    "runtime_health:",
    "sandbox_mint:",
    "payment_transfer:",
    "validator_sweep:",
    "pending_queue_clearance:",
    "poa_finality:",
    "balance_reconciliation:",
    "issued_supply_reconciliation:",
    "iso_pacs008_submission:",
    "iso_pacs002_status:",
    "iso_camt053_statement:",
    "compliance_self_transfer_rejection:",
    "settlement_reporting:",
    "compliance_reporting:",
    "validator_finality_reporting:",
    "audit_event_reporting:",
    "evidence_sources:",
    "health_endpoint: GET /health",
    "sandbox_mint_endpoint: POST /v1/sandbox/mint",
    "payments_endpoint: POST /v1/payments",
    "pacs008_endpoint: POST /v1/iso20022/pacs008",
    'pending_transactions: GET /v1/transactions/pending?limit=100&offset=0',
    'settlement_summary: GET /v1/reports/settlement-summary?limit=500&offset=0',
    "required_gates_before_smoke_execution:",
    "sandbox_only_purpose_recorded: blocked",
    "operator_assigned: blocked",
    "reviewer_assigned: blocked",
    "evidence_pack_location_selected: blocked",
    "base_url_confirmed: blocked",
    "sandbox_api_keys_confirmed_available: blocked",
    "test_asset_prefix_confirmed: blocked",
    "validator_run_mode_confirmed: blocked",
    "expected_balance_math_documented: blocked",
    "expected_iso_evidence_documented: blocked",
    "expected_report_evidence_documented: blocked",
    "no_real_value_capability_enabled: blocked",
    "expected_outcomes:",
    "mint_amount: 1000000",
    "direct_payment_amount: 100000",
    "iso_payment_amount: 25000",
    "corp_a_final_balance: 875000",
    "corp_b_final_balance: 125000",
    "pacs002_status: ACSC",
    "phase5a_sandbox_smoke_coverage_checked_in: true",
    "aggregate_phase5a_validator_includes_sandbox_smoke_coverage: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A sandbox smoke coverage config content: $expected"
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
    "cloud_smoke_execution_approved_by_this_checkpoint",
    "local_smoke_execution_approved_by_this_checkpoint",
    "live_sandbox_smoke_execution_enabled",
    "destructive_smoke_reset_enabled",
    "external_endpoint_smoke_enabled",
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
        throw "Phase 5A sandbox smoke coverage must not enable $forbidden"
    }
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$requiredSmokeControls = @(
    "runtime_health",
    "sandbox_mint",
    "payment_transfer",
    "validator_sweep",
    "pending_queue_clearance",
    "poa_finality",
    "balance_reconciliation",
    "issued_supply_reconciliation",
    "iso_pacs008_submission",
    "iso_pacs002_status",
    "iso_camt053_statement",
    "compliance_self_transfer_rejection",
    "settlement_reporting",
    "compliance_reporting",
    "validator_finality_reporting",
    "audit_event_reporting"
)

foreach ($control in $requiredSmokeControls) {
    if ($config -notmatch "(?m)^\s{2}$($control):\s*$") {
        throw "Missing smoke control: $control"
    }
}

$evidenceSourceCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+(GET|POST|scripts|Cloud|phase5a-)")).Count
if ($evidenceSourceCount -lt 22) {
    throw "Expected at least 22 sandbox smoke evidence sources, found $evidenceSourceCount"
}

$executionGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($executionGateCount -lt 12) {
    throw "Expected at least 12 blocked smoke execution gates, found $executionGateCount"
}

$requiredEvidenceFieldCount = ([regex]::Matches($config, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($requiredEvidenceFieldCount -lt 30) {
    throw "Expected at least 30 sandbox smoke evidence fields, found $requiredEvidenceFieldCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-sandbox-smoke-coverage-rc1"
    status = "sandbox_smoke_coverage_checkpoint_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    smoke_control_count = 16
    evidence_source_count = $evidenceSourceCount
    blocked_execution_gate_count = $executionGateCount
    required_evidence_field_count = $requiredEvidenceFieldCount
    local_smoke_script_defined = $true
    cloud_smoke_script_defined = $true
    security_smoke_script_defined = $true
    gke_required = $false
    google_cloud_resources_changed = $false
    scheduler_changes_enabled = $false
    automatic_scheduler_mutation_enabled = $false
    manual_scheduler_action_approved_by_this_checkpoint = $false
    cloud_run_job_execution_approved_by_this_checkpoint = $false
    secret_rotation_approved_by_this_checkpoint = $false
    cloud_smoke_execution_approved_by_this_checkpoint = $false
    local_smoke_execution_approved_by_this_checkpoint = $false
    live_sandbox_smoke_execution_enabled = $false
    destructive_smoke_reset_enabled = $false
    external_endpoint_smoke_enabled = $false
    failure_injection_enabled = $false
    live_failure_drills_enabled = $false
    live_retry_drills_enabled = $false
    live_recovery_drills_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
