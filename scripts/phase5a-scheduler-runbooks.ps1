$ErrorActionPreference = "Stop"

$docPath = "PHASE5A_SCHEDULER_RUNBOOKS.md"
$configPath = "config/phase5a-scheduler-runbooks.yaml"

$requiredArtifacts = @(
    $docPath,
    $configPath,
    "PHASE5A_VALIDATOR_RECONCILIATION.md",
    "config/phase5a-validator-reconciliation.yaml",
    "scripts/phase5a-validator-reconciliation.ps1",
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
    throw "Missing Phase 5A scheduler runbook artifact: $($missing -join ', ')"
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: scheduler runbooks checkpoint ready",
    "phase5a-scheduler-runbooks-rc1",
    "scheduler_pause_resume_runbooks",
    "Cloud Scheduler job",
    "Cloud Run validator job",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "phase5a-validator-reconciliation-rc1",
    "kani-sandbox-validator-scheduler",
    "kani-sandbox-validator",
    "kani-network-sandbox",
    "northamerica-northeast1",
    "*/15 * * * *",
    "validator-a",
    "validator-b",
    "validator-c",
    "Required Approvals Before Any Manual Scheduler Action",
    "Sandbox-only purpose recorded",
    "Change window approved",
    "Current Scheduler state captured",
    "Rollback path identified",
    "Runbook Steps",
    "Pre-Pause Checks",
    "Pause Scheduler",
    "Manual Validator Execution",
    "Resume Scheduler",
    "Post-Resume Reconciliation",
    "Rollback And Escalation",
    "Evidence Pack",
    "gcloud scheduler jobs describe kani-sandbox-validator-scheduler",
    "gcloud scheduler jobs pause kani-sandbox-validator-scheduler",
    "gcloud run jobs execute kani-sandbox-validator",
    "gcloud scheduler jobs resume kani-sandbox-validator-scheduler",
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A scheduler runbook doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase5a-scheduler-runbooks-rc1",
    "status: scheduler_runbooks_checkpoint_ready",
    "inherits_from: phase5a-validator-reconciliation-rc1",
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
    "live_failure_drills_enabled: false",
    "scheduler_job: kani-sandbox-validator-scheduler",
    "validator_job: kani-sandbox-validator",
    "project_id: kani-network-sandbox",
    "region: northamerica-northeast1",
    "scheduler_location: northamerica-northeast1",
    'cadence: "*/15 * * * *"',
    "validator_run_mode: sweep",
    "consensus: phase1-poa",
    "required_finality_votes: 2",
    "validator_count: 3",
    "validator-a",
    "validator-b",
    "validator-c",
    "required_approvals_before_manual_scheduler_action:",
    "sandbox_only_purpose_recorded: blocked",
    "operator_identified: blocked",
    "approver_identified: blocked",
    "change_window_approved: blocked",
    "rollback_path_identified: blocked",
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
    "describe_scheduler: gcloud scheduler jobs describe kani-sandbox-validator-scheduler",
    "pause_scheduler: gcloud scheduler jobs pause kani-sandbox-validator-scheduler",
    "execute_validator_job: gcloud run jobs execute kani-sandbox-validator",
    "resume_scheduler: gcloud scheduler jobs resume kani-sandbox-validator-scheduler",
    "phase5a_scheduler_runbooks_checked_in: true",
    "aggregate_phase5a_validator_includes_scheduler_runbooks: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 5A scheduler runbook config content: $expected"
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
        throw "Phase 5A scheduler runbooks must not enable $forbidden"
    }
}

$validatorCount = ([regex]::Matches($config, "(?m)^\s+- validator-[abc]\s*$")).Count
if ($validatorCount -ne 3) {
    throw "Expected exactly 3 Phase 5A validators, found $validatorCount"
}

$approvalGateCount = ([regex]::Matches($config, ":\s+blocked")).Count
if ($approvalGateCount -lt 11) {
    throw "Expected at least 11 blocked scheduler approval gates, found $approvalGateCount"
}

$runbookStepCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s*$")).Count
if ($runbookStepCount -lt 7) {
    throw "Expected at least 7 scheduler runbook steps, found $runbookStepCount"
}

$commandTemplateCount = ([regex]::Matches($config, "(?m)^\s{2}[a-z0-9_]+:\s+gcloud\s+")).Count
if ($commandTemplateCount -lt 5) {
    throw "Expected at least 5 scheduler command templates, found $commandTemplateCount"
}

$requiredEvidenceFieldCount = ([regex]::Matches($config, "(?m)^\s{6}- [a-z0-9_]+\s*$")).Count
if ($requiredEvidenceFieldCount -lt 21) {
    throw "Expected at least 21 scheduler evidence fields, found $requiredEvidenceFieldCount"
}

[pscustomobject]@{
    release_candidate = "phase5a-scheduler-runbooks-rc1"
    status = "scheduler_runbooks_checkpoint_ready"
    track = "phase5a-no-gke-validator-hardening"
    validator_count = 3
    approval_gate_count = $approvalGateCount
    runbook_step_count = 7
    command_template_count = $commandTemplateCount
    required_evidence_field_count = $requiredEvidenceFieldCount
    gke_required = $false
    google_cloud_resources_changed = $false
    scheduler_changes_enabled = $false
    automatic_scheduler_mutation_enabled = $false
    live_failure_drills_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
