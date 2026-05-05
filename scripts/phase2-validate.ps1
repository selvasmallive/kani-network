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

[pscustomobject]@{
    phase = "phase-2-cloud-mvp"
    required_file_count = $requiredFiles.Count
    sandbox_boundary_checked = $true
    validator_count = 3
    cloud_sql_proxy_checked = $true
    status = "ok"
}
