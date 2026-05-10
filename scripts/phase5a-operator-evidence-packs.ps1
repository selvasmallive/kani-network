$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_OPERATOR_EVIDENCE_PACKS.md"
$configPath = "config/phase5a-operator-evidence-packs.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5A_LEDGER_REPLAY_FINALITY.md",
    "config/phase5a-ledger-replay-finality.yaml",
    "scripts/phase5a-ledger-replay-finality.ps1",
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
    throw "Missing Phase 5A operator evidence pack artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: operator evidence packs checkpoint ready",
    "phase5a-operator-evidence-packs-rc1",
    "operator_evidence_packs",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase5a-ledger-replay-finality-rc1",
    "Evidence Pack Objective",
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
    "draft -> operator_complete -> reviewer_approved -> archived",
    "returned_for_correction",
    "Production approval is not a valid Phase 5A evidence pack state",
    "Retention Labels",
    "Non-Enablement",
    "Evidence export to external institutions",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A operator evidence pack doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-operator-evidence-packs-rc1",
    "status: operator_evidence_packs_checkpoint_ready",
    "inherits_from: phase5a-ledger-replay-finality-rc1",
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
    "evidence_pack_types:",
    "validator_reconciliation_pack:",
    "scheduler_pause_resume_pack:",
    "failure_retry_drill_pack:",
    "ledger_replay_finality_pack:",
    "alert_response_recovery_pack:",
    "sandbox_smoke_test_pack:",
    "phase5a_wrapup_pack:",
    "required_common_metadata:",
    "pack_id",
    "source_commit",
    "required_evidence_sections:",
    "sandbox_boundary",
    "redaction_rules:",
    "api_keys",
    "secret_manager_values",
    "review_workflow:",
    "allowed_states:",
    "forbidden_states:",
    "production_approved",
    "production_approval_allowed: false",
    "retention_labels:",
    "sandbox_only",
    "phase5a_operator_evidence_packs_checked_in: true",
    "aggregate_phase5a_validator_includes_operator_evidence_packs: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A operator evidence pack config content: $expected"
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
        throw "Phase 5A operator evidence packs must not enable $forbidden"
    }
}

if ($config -match "(?m)^\s*production_approval_allowed:\s+true\s*$") {
    throw "Phase 5A operator evidence packs must not allow production approval"
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$packTypeCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($packTypeCount -lt 7) {
    throw "Expected at least 7 operator evidence pack types, found $packTypeCount"
}

$metadataFieldCount = ([regex]::Matches($config, "(?m)^\s{2}- [a-z0-9_]+\s*$")).Count
if ($metadataFieldCount -lt 23) {
    throw "Expected at least 23 common metadata fields, found $metadataFieldCount"
}

$evidenceSectionCount = ([regex]::Matches($config, "(?m)^\s{2}- [a-z0-9_]+\s*$")).Count
if ($evidenceSectionCount -lt 35) {
    throw "Expected combined evidence sections and metadata entries to be at least 35, found $evidenceSectionCount"
}

$forbiddenFieldCount = ([regex]::Matches($config, "(?m)^\s{4}- [a-z0-9_]+\s*$")).Count
if ($forbiddenFieldCount -lt 9) {
    throw "Expected at least 9 redaction forbidden fields, found $forbiddenFieldCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-operator-evidence-packs-rc1"
    status = "operator_evidence_packs_checkpoint_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    evidence_pack_type_count = 7
    common_metadata_field_count = 23
    evidence_section_count = 12
    redaction_forbidden_field_count = $forbiddenFieldCount
    gke_required = $false
    google_cloud_resources_changed = $false
    external_evidence_export_enabled = $false
    production_approval_via_evidence_pack_enabled = $false
    production_replay_enabled = $false
    failure_injection_enabled = $false
    live_failure_drills_enabled = $false
    live_retry_drills_enabled = $false
    scheduler_changes_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
