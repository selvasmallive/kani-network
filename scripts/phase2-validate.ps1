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
    "Cloud SQL backups disabled" = '(?s)variable\s+"cloud_sql_backups_enabled".*?default\s*=\s*false'
    "Cloud SQL PITR disabled" = '(?s)variable\s+"cloud_sql_point_in_time_recovery_enabled".*?default\s*=\s*false'
    "Cloud Run max instance cap" = '(?s)variable\s+"cloud_run_max_instances".*?default\s*=\s*1'
    "Cloud Run direct IAM ingress" = '(?s)variable\s+"cloud_run_ingress".*?default\s*=\s*"INGRESS_TRAFFIC_ALL"'
    "Validator job timeout" = '(?s)variable\s+"validator_job_timeout_seconds".*?default\s*=\s*300'
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

[pscustomobject]@{
    phase = "phase-2-cloud-mvp"
    cost_profile = "phase2-lean-no-gke"
    required_file_count = $requiredFiles.Count
    sandbox_boundary_checked = $true
    validator_count = 3
    validator_runtime = "cloud-run-job"
    gke_enabled = $false
    status = "ok"
}
