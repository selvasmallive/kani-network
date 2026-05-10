$ErrorActionPreference = "Stop"

$docPath = "PHASE4_DR_READINESS.md"
$configPath = "config/phase4-dr-readiness.yaml"
$terraformPath = "infra/terraform/phase4_dr_readiness.tf"

foreach ($file in @($docPath, $configPath, $terraformPath)) {
    if (-not (Test-Path $file)) {
        throw "Missing Phase 4 DR readiness artifact: $file"
    }
}

$doc = Get-Content $docPath -Raw
foreach ($expected in @(
    "Status: DR readiness ready",
    "phase4-dr-readiness-rc1",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "phase2-lean-no-gke",
    "Readiness Objective",
    "This plan is not an approval to execute production recovery",
    "Recovery Domains",
    "ledger_database",
    "ledger_integrity",
    "api_runtime",
    "validator_runtime",
    "secrets_and_credentials",
    "audit_and_reporting",
    "Target RTO/RPO",
    "sandbox_no_gke",
    'target RTO `4h`',
    'target RPO `15m`',
    "Evidence Drills",
    "backup_configuration_inventory",
    "pitr_restore_to_separate_instance",
    "ledger_reconciliation_check",
    "validator_recovery_check",
    "post_drill_report",
    "Restore Runbook",
    "Required Gates Before Drill Execution",
    "Terraform Boundary",
    "phase4_dr_readiness_enabled = false",
    'Declare no `resource "google_*"` blocks',
    "No Google Cloud resources are created or changed"
)) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 DR readiness doc content: $expected"
    }
}

$config = Get-Content $configPath -Raw
foreach ($expected in @(
    "release_candidate: phase4-dr-readiness-rc1",
    "status: dr_readiness_ready",
    "inherits_from: phase4-prod-ingress-implementation-plan-rc1",
    "track: phase4-no-gke-preprod-readiness",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "creates_paid_resources: false",
    "changes_google_cloud_resources: false",
    "terraform_apply_allowed: false",
    "executes_restore_drill: false",
    "creates_restore_instance: false",
    "changes_cloud_sql_backup_configuration: false",
    "creates_cross_region_replica: false",
    "creates_archive_bucket: false",
    "changes_validator_scheduler: false",
    "promotes_restored_database: false",
    "executes_production_recovery: false",
    "recovery_domains:",
    "ledger_database:",
    "ledger_integrity:",
    "api_runtime:",
    "validator_runtime:",
    "secrets_and_credentials:",
    "artifact_and_config:",
    "audit_and_reporting:",
    "operator_runbooks:",
    "target_rto_rpo:",
    "sandbox_no_gke:",
    "target_rto: 4h",
    "target_rpo: 15m",
    "preprod_no_gke_candidate:",
    "production_candidate:",
    "evidence_drills:",
    "backup_configuration_inventory:",
    "pitr_restore_to_separate_instance:",
    "ledger_reconciliation_check:",
    "validator_recovery_check:",
    "post_drill_report:",
    "restore_runbook:",
    "required_gates_before_drill_execution:",
    "terraform_boundary:",
    "design_file: infra/terraform/phase4_dr_readiness.tf",
    "guard_variable: phase4_dr_readiness_enabled",
    "guard_default: false",
    "declares_google_cloud_resources: false",
    "output_only: true",
    "restore_drill_executed: false",
    "restore_instance_created: false",
    "cloud_sql_backup_configuration_changed: false",
    "production_recovery_executed: false",
    "real_value_settlement_enabled: false",
    "phase4_validator_includes_dr_readiness: true"
)) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 DR readiness config content: $expected"
    }
}

$terraform = Get-Content $terraformPath -Raw
foreach ($expected in @(
    'variable "phase4_dr_readiness_enabled"',
    "default     = false",
    "phase4-dr-readiness-rc1",
    "active_runtime_baseline        = `"phase2-lean-no-gke`"",
    "creates_paid_resources         = false",
    "changes_google_cloud_resources = false",
    "creates_real_value_capability  = false",
    "restore_drill_executed         = false",
    "restore_instance_created       = false",
    "production_recovery_enabled    = false",
    "ledger_database",
    "ledger_integrity",
    "backup_configuration_inventory",
    "pitr_restore_to_separate_instance",
    "google_sql_database_instance_restore_target",
    "google_sql_backup_restore",
    "google_storage_bucket_archive",
    'output "phase4_dr_readiness"'
)) {
    if ($terraform -notmatch [regex]::Escape($expected)) {
        throw "Expected Phase 4 DR readiness Terraform design content: $expected"
    }
}

foreach ($forbidden in @(
    "creates_paid_resources",
    "changes_google_cloud_resources",
    "terraform_apply_allowed",
    "executes_restore_drill",
    "creates_restore_instance",
    "changes_cloud_sql_backup_configuration",
    "creates_cross_region_replica",
    "creates_archive_bucket",
    "changes_validator_scheduler",
    "promotes_restored_database",
    "executes_production_recovery",
    "enables_gke_validator_operations",
    "enables_hsm_or_kms_signing",
    "enables_production_ingress",
    "enables_real_value_settlement",
    "restore_drill_executed",
    "restore_instance_created",
    "cloud_sql_backup_configuration_changed",
    "cross_region_replica_created",
    "archive_bucket_created",
    "validator_scheduler_changed",
    "restored_database_promoted",
    "production_recovery_executed",
    "google_cloud_resource_creation_allowed",
    "real_value_settlement_enabled",
    "production_go_live_allowed"
)) {
    if ($config -match "(?m)^\s*$($forbidden):\s+true\s*$") {
        throw "Phase 4 DR readiness must not enable $forbidden"
    }
}

if ($terraform -match 'resource\s+"google_') {
    throw "phase4_dr_readiness.tf must remain design-only and must not declare Google Cloud resources in this slice"
}

[pscustomobject]@{
    release_candidate = "phase4-dr-readiness-rc1"
    status = "dr_readiness_ready"
    track = "phase4-no-gke-preprod-readiness"
    recovery_domain_count = 8
    evidence_drill_count = 10
    paid_resources_created = $false
    google_cloud_resources_changed = $false
    terraform_apply_allowed = $false
    restore_drill_executed = $false
    restore_instance_created = $false
    production_recovery_enabled = $false
    real_value_capability_enabled = $false
    result = "ok"
}
