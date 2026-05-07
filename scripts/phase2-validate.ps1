$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE2_CLOUD_MVP.md",
    "cloudbuild.yaml",
    "config/cloud-sandbox.yaml",
    "scripts/phase2-cloud-smoke.ps1",
    "infra/terraform/versions.tf",
    "infra/terraform/variables.tf",
    "infra/terraform/main.tf",
    "infra/terraform/outputs.tf",
    "infra/terraform/terraform.tfvars.example",
    "k8s/README.md"
)

$missing = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    throw "Missing Phase 2 files: $($missing -join ', ')"
}

$sandboxFiles = @(
    "config/cloud-sandbox.yaml",
    "infra/terraform/main.tf",
    "PHASE2_CLOUD_MVP.md"
)

foreach ($file in $sandboxFiles) {
    $content = Get-Content $file -Raw
    foreach ($expected in @("SANDBOX", "REAL_VALUE", "REDEEMABLE")) {
        if ($content -notmatch $expected) {
            throw "Expected $expected in $file"
        }
    }
}

$terraformVariables = Get-Content "infra/terraform/variables.tf" -Raw
$leanExpectations = @{
    "database_tier small default" = '(?s)variable\s+"database_tier".*?default\s*=\s*"db-g1-small"'
    "Cloud SQL 10 GB disk default" = '(?s)variable\s+"cloud_sql_disk_size_gb".*?default\s*=\s*10'
    "Cloud SQL backups enabled" = '(?s)variable\s+"cloud_sql_backups_enabled".*?default\s*=\s*true'
    "Cloud SQL PITR enabled" = '(?s)variable\s+"cloud_sql_point_in_time_recovery_enabled".*?default\s*=\s*true'
    "Cloud SQL backup start time" = '(?s)variable\s+"cloud_sql_backup_start_time".*?default\s*=\s*"07:00"'
    "Cloud SQL retained backups" = '(?s)variable\s+"cloud_sql_backup_retained_count".*?default\s*=\s*7'
    "Cloud SQL transaction log retention" = '(?s)variable\s+"cloud_sql_transaction_log_retention_days".*?default\s*=\s*7'
    "Cloud Run max instance cap" = '(?s)variable\s+"cloud_run_max_instances".*?default\s*=\s*1'
    "Cloud Run direct IAM ingress" = '(?s)variable\s+"cloud_run_ingress".*?default\s*=\s*"INGRESS_TRAFFIC_ALL"'
    "Validator job timeout" = '(?s)variable\s+"validator_job_timeout_seconds".*?default\s*=\s*300'
    "Validator scheduler enabled" = '(?s)variable\s+"validator_scheduler_enabled".*?default\s*=\s*true'
    "Validator scheduler cadence" = '(?s)variable\s+"validator_schedule".*?default\s*=\s*"\*/15 \* \* \* \*"'
    "Budget guardrail enabled" = '(?s)variable\s+"budget_guardrail_enabled".*?default\s*=\s*true'
    "Budget guardrail amount" = '(?s)variable\s+"budget_amount_units".*?default\s*=\s*50'
    "Budget Pub/Sub attachment switch" = '(?s)variable\s+"budget_pubsub_topic_attachment_enabled".*?default\s*=\s*true'
    "Monitoring alerts enabled" = '(?s)variable\s+"monitoring_alerts_enabled".*?default\s*=\s*true'
    "Monitoring alert rate limit" = '(?s)variable\s+"monitoring_alert_log_notification_rate_limit".*?default\s*=\s*"900s"'
    "Deletion protection disabled" = '(?s)variable\s+"deletion_protection".*?default\s*=\s*false'
}

foreach ($expectation in $leanExpectations.GetEnumerator()) {
    if ($terraformVariables -notmatch $expectation.Value) {
        throw "Expected phase2-lean-no-gke setting: $($expectation.Key)"
    }
}

$terraformMain = Get-Content "infra/terraform/main.tf" -Raw
foreach ($forbidden in @("google_container_cluster", "google_container_node_pool", "container.googleapis.com", "compute.googleapis.com")) {
    if ($terraformMain -match $forbidden) {
        throw "Expected no GKE/Compute resource or service in phase2-lean-no-gke Terraform, found $forbidden"
    }
}

foreach ($expected in @("google_cloud_run_v2_job", "KANI_VALIDATOR_RUN_MODE", "KANI_VALIDATOR_IDS", "sweep")) {
    if ($terraformMain -notmatch $expected) {
        throw "Expected Cloud Run validator job setting in infra/terraform/main.tf: $expected"
    }
}

foreach ($expected in @(
    "cloudscheduler.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "google_monitoring_notification_channel",
    "monitoring_notification_channels",
    "google_pubsub_topic",
    "google_pubsub_subscription",
    "google_cloud_run_v2_service.cost_guard",
    "KANI_BUDGET_BRAKE_THRESHOLD",
    "KANI_REQUIRE_CONFIGURED_SANDBOX_API_KEYS",
    "KANI_SANDBOX_TREASURY_API_KEY",
    "google_secret_manager_secret.sandbox_api_key",
    "api_sandbox_api_key",
    "transaction_log_retention_days",
    "backup_retention_settings",
    "cloud_sql_backup_retained_count",
    "google_monitoring_alert_policy",
    "condition_matched_log",
    "api_error_logs",
    "validator_job_error_logs",
    "scheduler_error_logs",
    "cloud_sql_error_logs",
    "budget_brake_activity_logs",
    "google_cloud_scheduler_job",
    "run.googleapis.com/v2/projects",
    "roles/run.invoker",
    "google_billing_budget",
    "budget_filter",
    "threshold_rules"
)) {
    if ($terraformMain -notmatch $expected) {
        throw "Expected Scheduler/Budget guardrail setting in infra/terraform/main.tf: $expected"
    }
}

if ($terraformMain -notmatch 'edition\s*=\s*"ENTERPRISE"') {
    throw "Expected Cloud SQL Enterprise edition pin for db-g1-small in infra/terraform/main.tf"
}

foreach ($expected in @("cloud_build_artifact_writer", "cloud_build_source_reader", "cloud_build_log_writer")) {
    if ($terraformMain -notmatch $expected) {
        throw "Expected Cloud Build IAM grant in infra/terraform/main.tf: $expected"
    }
}

$cloudSandbox = Get-Content "config/cloud-sandbox.yaml" -Raw
if ($cloudSandbox -notmatch "cost_profile:\s*phase2-lean-no-gke") {
    throw "Expected phase2-lean-no-gke cost profile in config/cloud-sandbox.yaml"
}

foreach ($expected in @("validator_scheduler:", "budget_guardrail:", "hard_cap:\s*false")) {
    if ($cloudSandbox -notmatch $expected) {
        throw "Expected cloud sandbox guardrail setting in config/cloud-sandbox.yaml: $expected"
    }
}

foreach ($expected in @("programmatic_notifications:", "automated_brake:", "pause-validator-scheduler")) {
    if ($cloudSandbox -notmatch $expected) {
        throw "Expected cloud sandbox automated brake setting in config/cloud-sandbox.yaml: $expected"
    }
}

foreach ($expected in @("monitoring_alerts:", "api-error-logs", "validator-job-error-logs", "cloud-sql-error-logs", "budget-brake-activity")) {
    if ($cloudSandbox -notmatch $expected) {
        throw "Expected cloud sandbox monitoring alert setting in config/cloud-sandbox.yaml: $expected"
    }
}

foreach ($expected in @("api_auth:", "source:\s*secret-manager", "require_configured_keys:\s*true")) {
    if ($cloudSandbox -notmatch $expected) {
        throw "Expected cloud sandbox API auth hardening setting in config/cloud-sandbox.yaml: $expected"
    }
}

foreach ($expected in @("backups_enabled:\s*true", "backup_start_time_utc:\s*`"07:00`"", "retained_backups:\s*7", "point_in_time_recovery_enabled:\s*true", "transaction_log_retention_days:\s*7")) {
    if ($cloudSandbox -notmatch $expected) {
        throw "Expected cloud sandbox recovery setting in config/cloud-sandbox.yaml: $expected"
    }
}

$cloudSmokeScript = Get-Content "scripts/phase2-cloud-smoke.ps1" -Raw
foreach ($expected in @("secrets versions access latest", "NamePrefix-treasury-api-key", "KANI_SANDBOX_TREASURY_API_KEY")) {
    if ($cloudSmokeScript -notmatch $expected) {
        throw "Expected cloud smoke test to read sandbox API keys from Secret Manager or env: $expected"
    }
}

[pscustomobject]@{
    phase = "phase-2-cloud-mvp"
    cost_profile = "phase2-lean-no-gke"
    required_file_count = $requiredFiles.Count
    sandbox_boundary_checked = $true
    validator_count = 3
    validator_runtime = "cloud-run-job"
    validator_scheduler_enabled = $true
    budget_guardrail_enabled = $true
    budget_brake_enabled = $true
    budget_pubsub_topic_attachment_configurable = $true
    api_keys_source = "secret-manager"
    cloud_sql_backups_enabled = $true
    cloud_sql_point_in_time_recovery_enabled = $true
    monitoring_alerts_enabled = $true
    gke_enabled = $false
    status = "ok"
}
