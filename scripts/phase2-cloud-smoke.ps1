param(
    [string]$ProjectId = "kani-network-sandbox",
    [string]$Region = "northamerica-northeast1",
    [string]$ServiceName = "kani-sandbox-api",
    [string]$ValidatorJob = "kani-sandbox-validator",
    [string]$BaseUrl = "",
    [switch]$SkipIdentityToken,
    [switch]$SkipValidatorJob
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
}

$gcloud = Get-Gcloud

if (-not $BaseUrl) {
    $BaseUrl = (& $gcloud run services describe $ServiceName --region $Region --project $ProjectId --format "value(status.url)").Trim()
}

if (-not $BaseUrl) {
    throw "Could not resolve Cloud Run service URL for $ServiceName"
}

$authorizationHeaders = @{}
if (-not $SkipIdentityToken) {
    $token = (& $gcloud auth print-identity-token "--audiences=$BaseUrl").Trim()
    if ($token) {
        $authorizationHeaders["Authorization"] = "Bearer $token"
    }
}

function Join-Headers {
    param([hashtable]$SpecificHeaders)

    $headers = @{}
    foreach ($key in $authorizationHeaders.Keys) {
        $headers[$key] = $authorizationHeaders[$key]
    }
    foreach ($key in $SpecificHeaders.Keys) {
        $headers[$key] = $SpecificHeaders[$key]
    }
    return $headers
}

function Invoke-KaniJson {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers,
        $Body = $null
    )

    $uri = "$BaseUrl$Path"
    $requestHeaders = Join-Headers $Headers

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $requestHeaders
    }

    $json = $Body | ConvertTo-Json -Depth 10
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $requestHeaders -ContentType "application/json" -Body $json
}

function Invoke-ValidatorJob {
    if ($SkipValidatorJob) {
        return
    }

    & $gcloud run jobs execute $ValidatorJob --region $Region --project $ProjectId --wait | Out-Host
}

$asset = "KCAD_TEST_$(Get-Date -Format yyyyMMddHHmmss)"
$treasuryHeaders = @{
    "x-kani-institution-id" = "KANI_TREASURY"
    "x-kani-api-key" = "sandbox-treasury-token"
}
$corpAHeaders = @{
    "x-kani-institution-id" = "CORP_A"
    "x-kani-api-key" = "sandbox-corp-a-token"
}
$corpBHeaders = @{
    "x-kani-institution-id" = "CORP_B"
    "x-kani-api-key" = "sandbox-corp-b-token"
}
$adminHeaders = @{
    "x-kani-institution-id" = "KANI_ADMIN"
    "x-kani-api-key" = "sandbox-admin-token"
}

$health = Invoke-KaniJson -Method Get -Path "/health" -Headers @{}
if ($health.status -ne "ok") {
    throw "Expected /health status ok"
}

$mint = Invoke-KaniJson -Method Post -Path "/v1/sandbox/mint" -Headers $treasuryHeaders -Body @{
    treasury = "TREASURY_SANDBOX"
    to = "CORP_A"
    asset = $asset
    amount = 1000000
}
Invoke-ValidatorJob

$transfer = Invoke-KaniJson -Method Post -Path "/v1/payments" -Headers $corpAHeaders -Body @{
    from = "CORP_A"
    to = "CORP_B"
    asset = $asset
    amount = 100000
    client_reference_id = "phase2-cloud-$asset"
}
Invoke-ValidatorJob

$balanceA = Invoke-KaniJson -Method Get -Path "/v1/accounts/CORP_A/balances/$asset" -Headers $corpAHeaders
$balanceB = Invoke-KaniJson -Method Get -Path "/v1/accounts/CORP_B/balances/$asset" -Headers $corpBHeaders
$latestBlock = Invoke-KaniJson -Method Get -Path "/v1/blocks/latest" -Headers $adminHeaders
$pending = Invoke-KaniJson -Method Get -Path "/v1/transactions/pending?limit=100&offset=0" -Headers $adminHeaders

if ([int64]$balanceA.amount -ne 900000) {
    throw "Expected CORP_A balance 900000, got $($balanceA.amount)"
}
if ([int64]$balanceB.amount -ne 100000) {
    throw "Expected CORP_B balance 100000, got $($balanceB.amount)"
}
if ([int64]$pending.count -ne 0) {
    throw "Expected no pending transactions, got $($pending.count)"
}

[pscustomobject]@{
    profile = "phase2-lean-no-gke"
    base_url = $BaseUrl
    health = $health.status
    asset = $asset
    mint_transaction = $mint.transaction.id
    transfer_transaction = $transfer.transaction.id
    corp_a_balance = $balanceA.amount
    corp_b_balance = $balanceB.amount
    latest_block_height = $latestBlock.height
    latest_block_validator = $latestBlock.validator
    latest_block_finalized_by = $latestBlock.finalized_by -join ","
    pending_count = $pending.count
    status = "ok"
}
