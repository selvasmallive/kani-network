param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("treasury", "corp_a", "corp_b", "admin")]
    [string]$Key,

    [string]$TerraformDir = "infra/terraform",
    [string]$PlanFile = "",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

function Get-Gcloud {
    $candidates = @(
        "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        "gcloud"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -eq "gcloud") {
            return $candidate
        }

        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Could not find gcloud"
}

function Get-Terraform {
    $candidates = @(
        "C:\ProgramData\chocolatey\bin\terraform.exe",
        "terraform"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -eq "terraform") {
            return $candidate
        }

        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Could not find terraform"
}

$gcloud = Get-Gcloud
$terraform = Get-Terraform

if (-not $PlanFile) {
    $PlanFile = "tfplan-rotate-$($Key.Replace('_', '-'))"
}

$env:GOOGLE_OAUTH_ACCESS_TOKEN = (& $gcloud auth print-access-token).Trim()

$replacePassword = "random_password.sandbox_api_key[`"$Key`"]"
$replaceSecretVersion = "google_secret_manager_secret_version.sandbox_api_key[`"$Key`"]"

& $terraform -chdir=$TerraformDir plan `
    "-replace=$replacePassword" `
    "-replace=$replaceSecretVersion" `
    -out=$PlanFile

if ($Apply) {
    & $terraform -chdir=$TerraformDir apply -auto-approve $PlanFile
    Remove-Item -LiteralPath (Join-Path $TerraformDir $PlanFile) -Force -ErrorAction SilentlyContinue
}

[pscustomobject]@{
    rotated_key = $Key
    terraform_dir = $TerraformDir
    plan_file = $PlanFile
    applied = [bool]$Apply
    next_step = if ($Apply) {
        "Run scripts/phase2-security-smoke.ps1 and scripts/phase2-cloud-smoke.ps1"
    } else {
        "Review the plan, then rerun with -Apply"
    }
}
