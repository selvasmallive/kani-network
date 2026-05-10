$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_VALIDATOR_HARDENING_PLAN.md"
$configPath = "config/phase5a-validator-hardening-plan.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
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
    throw "Missing Phase 5A validator hardening artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: validator hardening plan ready",
    "phase5a-validator-hardening-plan-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase4-wrapup-rc1",
    "phase5a-no-gke-validator-hardening",
    "phase5b-gke-validator-ops",
    "Cloud Run Job plus Cloud Scheduler",
    'Run mode: `sweep`',
    "validator-a",
    "validator-b",
    "validator-c",
    "Phase 1 PoA",
    "2 of 3 validator finality",
    "15-minute cadence",
    "Hardening Workstreams",
    "validator_reconciliation_tests",
    "failure_and_retry_drills",
    "scheduler_pause_resume_runbooks",
    "ledger_replay_and_finality_verification",
    "operator_evidence_packs",
    "alert_response_and_recovery_drills",
    "complete_sandbox_smoke_tests",
    "Future Implementation Gates",
    "Cost reviewed if any paid resources",
    "Scheduler change window approved",
    "Failure drill owner assigned",
    "Recovery owner assigned",
    "No real-value, redemption, custody, trading, or external institution capability enabled",
    "Non-Enablement",
    "GKE cluster creation",
    "Terraform apply",
    "Google Cloud resource creation or mutation",
    "Validator Scheduler changes",
    "Live failure drills",
    "Production BFT validator network",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A validator hardening plan content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-validator-hardening-plan-rc1",
    "status: validator_hardening_plan_ready",
    "inherits_from: phase4-wrapup-rc1",
    "track: phase5a-no-gke-validator-hardening",
    "active_runtime_baseline: phase2-lean-no-gke",
    "gke_phase: phase5b-gke-validator-ops",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "google_cloud_resource_creation_allowed: false",
    "paid_resource_enablement_allowed: false",
    "runtime: cloud_run_job_plus_cloud_scheduler",
    "run_mode: sweep",
    'scheduler_cadence: "*/15 * * * *"',
    "consensus: phase1-poa",
    "finality_model: two_of_three",
    "required_finality_votes: 2",
    "validator_count: 3",
    "validator-a",
    "validator-b",
    "validator-c",
    "hardening_workstreams:",
    "validator_reconciliation_tests:",
    "failure_and_retry_drills:",
    "scheduler_pause_resume_runbooks:",
    "ledger_replay_and_finality_verification:",
    "operator_evidence_packs:",
    "alert_response_and_recovery_drills:",
    "complete_sandbox_smoke_tests:",
    "required_future_gates_before_live_drills:",
    "cost_review_if_paid_resources_required: blocked",
    "scheduler_change_window_approved: blocked",
    "failure_drill_owner_assigned: blocked",
    "recovery_owner_assigned: blocked",
    "rollback_path_documented: blocked",
    "evidence_pack_location_selected: blocked",
    "no_real_value_capability_enabled: blocked",
    "gke_cluster_enabled: false",
    "gke_required: false",
    "production_bft_validator_network_enabled: false",
    "production_ingress_enabled: false",
    "hsm_kms_production_signing_enabled: false",
    "scheduler_changes_enabled: false",
    "live_failure_drills_enabled: false",
    "external_institution_onboarding_enabled: false",
    "real_value_settlement_enabled: false",
    "phase5a_validator_hardening_plan_checked_in: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A validator hardening config content: $expected"
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
        throw "Phase 5A validator hardening plan must not enable $forbidden"
    }
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$workstreamCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($workstreamCount -lt 7) {
    throw "Expected at least 7 Phase 5A hardening workstreams, found $workstreamCount"
}

$blockedGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($blockedGateCount -lt 7) {
    throw "Expected at least 7 blocked Phase 5A live-drill gates, found $blockedGateCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-validator-hardening-plan-rc1"
    status = "validator_hardening_plan_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    hardening_workstream_count = 7
    blocked_live_drill_gate_count = $blockedGateCount
    gke_required = $false
    google_cloud_resources_changed = $false
    live_failure_drills_enabled = $false
    scheduler_changes_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
