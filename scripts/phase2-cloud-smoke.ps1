param(
    [string]$ProjectId = "kani-network-sandbox",
    [string]$Region = "northamerica-northeast1",
    [string]$NamePrefix = "kani-sandbox",
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
    $activeAccount = (& $gcloud config get-value account 2>$null).Trim()
    if ($activeAccount -match "gserviceaccount\.com$") {
        $token = (& $gcloud auth print-identity-token "--audiences=$BaseUrl").Trim()
    } else {
        $token = (& $gcloud auth print-identity-token)
        $token = $token.Trim()
    }
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

function Invoke-KaniXml {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers,
        [string]$Body
    )

    $uri = "$BaseUrl$Path"
    $requestHeaders = Join-Headers $Headers

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $requestHeaders -ContentType "application/xml" -Body $Body
}

function Invoke-ValidatorJob {
    if ($SkipValidatorJob) {
        return
    }

    & $gcloud run jobs execute $ValidatorJob --region $Region --project $ProjectId --wait | Out-Host
}

function Get-SandboxApiKey {
    param(
        [string]$EnvName,
        [string]$SecretId
    )

    $envValue = [Environment]::GetEnvironmentVariable($EnvName)
    if ($envValue -and $envValue.Trim()) {
        return $envValue.Trim()
    }

    $secretValue = (& $gcloud secrets versions access latest --secret $SecretId --project $ProjectId 2>$null)
    if (-not $secretValue) {
        throw "Could not read sandbox API key from Secret Manager secret $SecretId. Set $EnvName or apply Terraform first."
    }

    return ($secretValue -join "`n").Trim()
}

$treasuryApiKey = Get-SandboxApiKey -EnvName "KANI_SANDBOX_TREASURY_API_KEY" -SecretId "$NamePrefix-treasury-api-key"
$corpAApiKey = Get-SandboxApiKey -EnvName "KANI_SANDBOX_CORP_A_API_KEY" -SecretId "$NamePrefix-corp-a-api-key"
$corpBApiKey = Get-SandboxApiKey -EnvName "KANI_SANDBOX_CORP_B_API_KEY" -SecretId "$NamePrefix-corp-b-api-key"
$adminApiKey = Get-SandboxApiKey -EnvName "KANI_SANDBOX_ADMIN_API_KEY" -SecretId "$NamePrefix-admin-api-key"

$asset = "KCAD_TEST_$(Get-Date -Format yyyyMMddHHmmss)"
$treasuryHeaders = @{
    "x-kani-institution-id" = "KANI_TREASURY"
    "x-kani-api-key" = $treasuryApiKey
}
$corpAHeaders = @{
    "x-kani-institution-id" = "CORP_A"
    "x-kani-api-key" = $corpAApiKey
}
$corpBHeaders = @{
    "x-kani-institution-id" = "CORP_B"
    "x-kani-api-key" = $corpBApiKey
}
$adminHeaders = @{
    "x-kani-institution-id" = "KANI_ADMIN"
    "x-kani-api-key" = $adminApiKey
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

$isoMessageId = "phase2-cloud-iso-$asset"
$isoEndToEndId = "phase2-cloud-iso-e2e-$asset"
$isoXml = @"
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
  <FIToFICstmrCdtTrf>
    <GrpHdr>
      <MsgId>$isoMessageId</MsgId>
    </GrpHdr>
    <CdtTrfTxInf>
      <PmtId>
        <InstrId>instr-$asset</InstrId>
        <EndToEndId>$isoEndToEndId</EndToEndId>
      </PmtId>
      <IntrBkSttlmAmt Ccy="$asset">25000</IntrBkSttlmAmt>
      <DbtrAcct>
        <Id>
          <Othr>
            <Id>CORP_A</Id>
          </Othr>
        </Id>
      </DbtrAcct>
      <CdtrAcct>
        <Id>
          <Othr>
            <Id>CORP_B</Id>
          </Othr>
        </Id>
      </CdtrAcct>
    </CdtTrfTxInf>
  </FIToFICstmrCdtTrf>
</Document>
"@
$isoTransfer = Invoke-KaniXml -Method Post -Path "/v1/iso20022/pacs008" -Headers $corpAHeaders -Body $isoXml
if ($isoTransfer.message_type -ne "pacs.008") {
    throw "Expected ISO response message_type pacs.008"
}
$expectedIsoReferenceId = "pacs.008:${isoMessageId}:${isoEndToEndId}"
if ($isoTransfer.payment.client_reference_id -ne $expectedIsoReferenceId) {
    throw "Expected ISO payment client_reference_id $expectedIsoReferenceId, got $($isoTransfer.payment.client_reference_id)"
}
Invoke-ValidatorJob

$balanceA = Invoke-KaniJson -Method Get -Path "/v1/accounts/CORP_A/balances/$asset" -Headers $corpAHeaders
$balanceB = Invoke-KaniJson -Method Get -Path "/v1/accounts/CORP_B/balances/$asset" -Headers $corpBHeaders
$latestBlock = Invoke-KaniJson -Method Get -Path "/v1/blocks/latest" -Headers $adminHeaders
$pending = Invoke-KaniJson -Method Get -Path "/v1/transactions/pending?limit=100&offset=0" -Headers $adminHeaders

if ([int64]$balanceA.amount -ne 875000) {
    throw "Expected CORP_A balance 875000, got $($balanceA.amount)"
}
if ([int64]$balanceB.amount -ne 125000) {
    throw "Expected CORP_B balance 125000, got $($balanceB.amount)"
}
if ([int64]$pending.count -ne 0) {
    throw "Expected no pending transactions, got $($pending.count)"
}

[pscustomobject]@{
    profile = "phase2-lean-no-gke"
    base_url = $BaseUrl
    health = $health.status
    asset = $asset
    mint_transaction = $mint.transaction_id
    transfer_transaction = $transfer.transaction_id
    iso_transaction = $isoTransfer.payment.transaction_id
    iso_message_id = $isoTransfer.message_id
    corp_a_balance = $balanceA.amount
    corp_b_balance = $balanceB.amount
    latest_block_height = $latestBlock.height
    latest_block_validator = $latestBlock.validator
    latest_block_finalized_by = $latestBlock.finalized_by -join ","
    pending_count = $pending.count
    status = "ok"
}
