param(
    [string]$ProjectId = "kani-network-sandbox",
    [string]$Region = "northamerica-northeast1",
    [string]$Zone = "northamerica-northeast1-a",
    [string]$NamePrefix = "kani-sandbox",
    [string]$ClusterName = "kani-sandbox-validators",
    [string]$GkeNodeMachineType = "e2-medium",
    [string]$ImageRepository = "kani",
    [string]$ImageName = "kani-api",
    [string]$ImageTag = "",
    [switch]$SkipBuild,
    [switch]$SkipTerraformApply,
    [switch]$SkipKubernetesApply
)

$ErrorActionPreference = "Stop"

function Get-CommandPath {
    param(
        [string]$Name,
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Could not find required command: $Name"
}

function Invoke-Logged {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    Write-Host "> $FilePath $($Arguments -join ' ')"
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

function Get-TcpDatabaseUrl {
    param([string]$RawDatabaseUrl)

    $trimmed = $RawDatabaseUrl.Trim()
    if ($trimmed -match "^postgres://(?<user>[^:]+):(?<password>[^@]+)@localhost/kani\?host=.+$") {
        return "postgres://$($Matches.user):$($Matches.password)@127.0.0.1:5432/kani"
    }

    if ($trimmed -match "^postgres://[^@]+@127\.0\.0\.1:5432/kani$") {
        return $trimmed
    }

    throw "Unsupported DATABASE_URL shape for GKE Cloud SQL Proxy TCP rendering."
}

$gcloud = Get-CommandPath -Name "gcloud" -Candidates @(
    "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
)
$terraform = Get-CommandPath -Name "terraform" -Candidates @("terraform")
$kubectl = Get-CommandPath -Name "kubectl" -Candidates @(
    "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\kubectl.cmd"
)
$gkeAuthPlugin = Get-Command gke-gcloud-auth-plugin -ErrorAction SilentlyContinue
if (-not $gkeAuthPlugin) {
    throw "Missing gke-gcloud-auth-plugin. Install it from an Administrator Google Cloud SDK Shell with: gcloud components install gke-gcloud-auth-plugin --quiet"
}

try {
    $adcToken = (& $gcloud auth application-default print-access-token 2>$null)
    if (-not $adcToken) {
        throw "empty token"
    }
} catch {
    throw "Google Application Default Credentials need reauthentication. Run: gcloud auth application-default login --project $ProjectId"
}

if (-not $ImageTag) {
    $ImageTag = "phase5b-$(Get-Date -Format yyyyMMddHHmmss)"
}

$imageUri = "$Region-docker.pkg.dev/$ProjectId/$ImageRepository/$ImageName`:$ImageTag"

if (-not $SkipBuild) {
    Invoke-Logged -FilePath $gcloud -Arguments @(
        "builds",
        "submit",
        "--project",
        $ProjectId,
        "--config",
        "cloudbuild.yaml",
        "--substitutions",
        "_REGION=$Region,_REPOSITORY=$ImageRepository,_IMAGE=$ImageName,_TAG=$ImageTag"
    )
}

if (-not $SkipTerraformApply) {
    Invoke-Logged -FilePath $terraform -Arguments @(
        "-chdir=infra/terraform",
        "apply",
        "-auto-approve",
        "-var",
        "api_image=$imageUri",
        "-var",
        "validator_scheduler_paused=true"
    )
    Invoke-Logged -FilePath $terraform -Arguments @("-chdir=infra/terraform-gke", "init")
    Invoke-Logged -FilePath $terraform -Arguments @(
        "-chdir=infra/terraform-gke",
        "apply",
        "-auto-approve",
        "-var",
        "gke_node_machine_type=$GkeNodeMachineType"
    )
}

$gkeClusterNameOutput = (& $terraform -chdir=infra/terraform-gke output -raw gke_cluster_name 2>$null)
if ($gkeClusterNameOutput) {
    $ClusterName = $gkeClusterNameOutput.Trim()
}

$gkeClusterLocationOutput = (& $terraform -chdir=infra/terraform-gke output -raw gke_cluster_location 2>$null)
if ($gkeClusterLocationOutput) {
    $Zone = $gkeClusterLocationOutput.Trim()
}

Invoke-Logged -FilePath $gcloud -Arguments @(
    "container",
    "clusters",
    "get-credentials",
    $ClusterName,
    "--zone",
    $Zone,
    "--project",
    $ProjectId
)

$cloudSqlConnectionName = (& $terraform -chdir=infra/terraform output -raw cloud_sql_connection_name).Trim()
$validatorServiceAccount = (& $terraform -chdir=infra/terraform-gke output -raw validator_service_account).Trim()
$rawDatabaseUrl = (& $gcloud secrets versions access latest --secret "$NamePrefix-database-url" --project $ProjectId)
$databaseUrl = Get-TcpDatabaseUrl -RawDatabaseUrl ($rawDatabaseUrl -join "`n")

$renderRoot = Join-Path ([System.IO.Path]::GetTempPath()) "kani-phase5b-gke-render"
if (Test-Path $renderRoot) {
    Remove-Item -LiteralPath $renderRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $renderRoot | Out-Null

foreach ($file in @(
    "k8s/namespace.yaml",
    "k8s/validator-rbac.yaml",
    "k8s/validator-configmap.yaml",
    "k8s/validators.yaml",
    "k8s/kustomization.yaml"
)) {
    Copy-Item -LiteralPath $file -Destination $renderRoot -Force
}

(Get-Content (Join-Path $renderRoot "kustomization.yaml") -Raw).
    Replace("northamerica-northeast1-docker.pkg.dev/PROJECT_ID/kani/kani-api", "$Region-docker.pkg.dev/$ProjectId/$ImageRepository/$ImageName").
    Replace("newTag: latest", "newTag: $ImageTag") |
    Set-Content -Path (Join-Path $renderRoot "kustomization.yaml") -NoNewline

(Get-Content (Join-Path $renderRoot "validator-configmap.yaml") -Raw).
    Replace("REPLACE_WITH_CLOUD_SQL_CONNECTION_NAME", $cloudSqlConnectionName) |
    Set-Content -Path (Join-Path $renderRoot "validator-configmap.yaml") -NoNewline

(Get-Content (Join-Path $renderRoot "validator-rbac.yaml") -Raw).
    Replace("REPLACE_WITH_VALIDATOR_GSA_EMAIL", $validatorServiceAccount) |
    Set-Content -Path (Join-Path $renderRoot "validator-rbac.yaml") -NoNewline

@"
apiVersion: v1
kind: Secret
metadata:
  name: kani-ledger-database
  namespace: kani-system
  labels:
    app.kubernetes.io/name: kani-validator
    app.kubernetes.io/part-of: kani-network
    kani.phase: "phase-5b"
type: Opaque
stringData:
  DATABASE_URL: "$databaseUrl"
"@ | Set-Content -Path (Join-Path $renderRoot "validator-secret.yaml") -NoNewline

$kustomizationPath = Join-Path $renderRoot "kustomization.yaml"
$kustomization = Get-Content $kustomizationPath -Raw
$kustomization = $kustomization.Replace("  - validators.yaml", "  - validators.yaml`n  - validator-secret.yaml")
Set-Content -Path $kustomizationPath -Value $kustomization -NoNewline

if (-not $SkipKubernetesApply) {
    Invoke-Logged -FilePath $kubectl -Arguments @("apply", "-k", $renderRoot)
    foreach ($validator in @("validator-a", "validator-b", "validator-c")) {
        Invoke-Logged -FilePath $kubectl -Arguments @(
            "rollout",
            "status",
            "deployment/$validator",
            "-n",
            "kani-system",
            "--timeout=300s"
        )
    }
}

Invoke-Logged -FilePath $kubectl -Arguments @(
    "get",
    "pods",
    "-n",
    "kani-system",
    "-l",
    "app.kubernetes.io/name=kani-validator",
    "-o",
    "wide"
)

[pscustomobject]@{
    phase = "phase5b-gke-apply-pilot"
    project_id = $ProjectId
    region = $Region
    zone = $Zone
    cluster_name = $ClusterName
    image_uri = $imageUri
    cloud_sql_connection_name = $cloudSqlConnectionName
    validator_service_account = $validatorServiceAccount
    rendered_manifest_path = $renderRoot
    terraform_apply_executed = -not $SkipTerraformApply
    kubernetes_apply_executed = -not $SkipKubernetesApply
    environment = "SANDBOX"
    real_value = $false
    redeemable = $false
    result = "ok"
}
