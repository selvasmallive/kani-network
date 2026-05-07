$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "PHASE2_CLOUD_MVP.md",
    "cloudbuild.yaml",
    "config/cloud-sandbox.yaml",
    "infra/terraform/versions.tf",
    "infra/terraform/variables.tf",
    "infra/terraform/main.tf",
    "infra/terraform/outputs.tf",
    "infra/terraform/terraform.tfvars.example",
    "k8s/kustomization.yaml",
    "k8s/namespace.yaml",
    "k8s/validator-rbac.yaml",
    "k8s/validator-configmap.yaml",
    "k8s/validator-secret.example.yaml",
    "k8s/validators.yaml",
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
    "k8s/validator-configmap.yaml",
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

$validatorManifest = Get-Content "k8s/validators.yaml" -Raw
foreach ($validator in @("validator-a", "validator-b", "validator-c")) {
    if ($validatorManifest -notmatch $validator) {
        throw "Expected $validator deployment in k8s/validators.yaml"
    }
}

$validatorConfig = Get-Content "k8s/validator-configmap.yaml" -Raw
if ($validatorConfig -notmatch "CLOUD_SQL_CONNECTION_NAME") {
    throw "Expected CLOUD_SQL_CONNECTION_NAME in k8s/validator-configmap.yaml"
}

if ($validatorManifest -notmatch "cloud-sql-proxy") {
    throw "Expected Cloud SQL proxy sidecars in k8s/validators.yaml"
}

$terraformVariables = Get-Content "infra/terraform/variables.tf" -Raw
$leanExpectations = @{
    "gke_location zonal default" = '(?s)variable\s+"gke_location".*?default\s*=\s*"northamerica-northeast1-a"'
    "database_tier micro default" = '(?s)variable\s+"database_tier".*?default\s*=\s*"db-f1-micro"'
    "Cloud SQL 10 GB disk default" = '(?s)variable\s+"cloud_sql_disk_size_gb".*?default\s*=\s*10'
    "Cloud SQL backups disabled" = '(?s)variable\s+"cloud_sql_backups_enabled".*?default\s*=\s*false'
    "Cloud SQL PITR disabled" = '(?s)variable\s+"cloud_sql_point_in_time_recovery_enabled".*?default\s*=\s*false'
    "GKE one node default" = '(?s)variable\s+"gke_node_count".*?default\s*=\s*1'
    "GKE e2-small default" = '(?s)variable\s+"gke_machine_type".*?default\s*=\s*"e2-small"'
    "GKE 20 GB node disk default" = '(?s)variable\s+"gke_disk_size_gb".*?default\s*=\s*20'
    "Cloud Run max instance cap" = '(?s)variable\s+"cloud_run_max_instances".*?default\s*=\s*1'
}

foreach ($expectation in $leanExpectations.GetEnumerator()) {
    if ($terraformVariables -notmatch $expectation.Value) {
        throw "Expected lean cost profile setting: $($expectation.Key)"
    }
}

$cloudSandbox = Get-Content "config/cloud-sandbox.yaml" -Raw
if ($cloudSandbox -notmatch "cost_profile:\s*lean-free-trial") {
    throw "Expected lean-free-trial cost profile in config/cloud-sandbox.yaml"
}

[pscustomobject]@{
    phase = "phase-2-cloud-mvp"
    cost_profile = "lean-free-trial"
    required_file_count = $requiredFiles.Count
    sandbox_boundary_checked = $true
    validator_count = 3
    cloud_sql_proxy_checked = $true
    status = "ok"
}
