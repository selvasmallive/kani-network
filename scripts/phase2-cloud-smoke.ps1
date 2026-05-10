param(
    [string]$ProjectId = "kani-network-sandbox",
    [string]$Region = "northamerica-northeast1",
    [string]$NamePrefix = "kani-sandbox",
    [string]$ServiceName = "kani-sandbox-api",
    [string]$ValidatorJob = "kani-sandbox-validator",
    [string]$BaseUrl = "",
    [switch]$SkipIdentityToken,
    [switch]$SkipValidatorJob,
    [switch]$WaitForContinuousValidators
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

function Invoke-KaniJsonError {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers,
        [int]$ExpectedStatus,
        $Body = $null
    )

    $uri = "$BaseUrl$Path"
    $requestHeaders = Join-Headers $Headers
    $json = $null
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 10
    }

    try {
        if ($null -eq $Body) {
            Invoke-RestMethod -Method $Method -Uri $uri -Headers $requestHeaders | Out-Null
        } else {
            Invoke-RestMethod -Method $Method -Uri $uri -Headers $requestHeaders -ContentType "application/json" -Body $json | Out-Null
        }
        throw "Expected HTTP $ExpectedStatus from $Path"
    } catch {
        $errorRecord = $_
        $response = $errorRecord.Exception.Response
        if (-not $response) {
            throw
        }

        $statusCode = [int]$response.StatusCode
        $content = ""
        if ($errorRecord.ErrorDetails -and $errorRecord.ErrorDetails.Message) {
            $content = $errorRecord.ErrorDetails.Message
        }
        if (-not $content) {
            try {
                $stream = $response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $content = $reader.ReadToEnd()
                    $reader.Dispose()
                }
            } catch {
                $content = ""
            }
        }

        if ($statusCode -ne $ExpectedStatus) {
            throw "Expected HTTP $ExpectedStatus from $Path, got $statusCode with body $content"
        }

        try {
            return $content | ConvertFrom-Json
        } catch {
            return [pscustomobject]@{ error = $content }
        }
    }
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

function Invoke-KaniRaw {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers
    )

    $uri = "$BaseUrl$Path"
    $requestHeaders = Join-Headers $Headers

    return (Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $uri -Headers $requestHeaders).Content
}

function Get-JsonProperty {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

function Invoke-ValidatorJob {
    if ($SkipValidatorJob) {
        if ($WaitForContinuousValidators) {
            Wait-KaniPendingTransactions
        }
        return
    }

    & $gcloud run jobs execute $ValidatorJob --region $Region --project $ProjectId --wait | Out-Host
}

function Wait-KaniPendingTransactions {
    $deadline = (Get-Date).AddSeconds(90)
    do {
        Start-Sleep -Milliseconds 750
        $pending = Invoke-KaniJson -Method Get -Path "/v1/transactions/pending?limit=100&offset=0" -Headers $adminHeaders
        if ([int64]$pending.count -eq 0) {
            return
        }
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for continuous validators to clear pending transactions"
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

$blockedSelfTransfer = Invoke-KaniJsonError -Method Post -Path "/v1/payments" -Headers $corpAHeaders -ExpectedStatus 403 -Body @{
    from = "CORP_A"
    to = "CORP_A"
    asset = $asset
    amount = 1
    client_reference_id = "phase2-compliance-self-$asset"
}
if ($blockedSelfTransfer.error -notmatch "NO_SELF_TRANSFER") {
    throw "Expected compliance self-transfer block, got $($blockedSelfTransfer.error)"
}

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

$isoStatusXml = Invoke-KaniRaw -Method Get -Path "/v1/iso20022/pacs002/$($isoTransfer.payment.payment_id)" -Headers $corpAHeaders
foreach ($expected in @(
    "pacs.002.001.10",
    "<OrgnlMsgId>$isoMessageId</OrgnlMsgId>",
    "<OrgnlEndToEndId>$isoEndToEndId</OrgnlEndToEndId>",
    "<TxSts>ACSC</TxSts>",
    "<TxId>$($isoTransfer.payment.transaction_id)</TxId>"
)) {
    if ($isoStatusXml -notmatch [regex]::Escape($expected)) {
        throw "Expected pacs.002 XML to contain $expected"
    }
}

$statementXml = Invoke-KaniRaw -Method Get -Path "/v1/iso20022/camt053/accounts/CORP_A?asset=$asset&limit=20&offset=0" -Headers $corpAHeaders
foreach ($expected in @(
    "camt.053.001.08",
    "<BkToCstmrStmt>",
    "<Id>CORP_A</Id>",
    "<Cd>CLBD</Cd>",
    "<CdtDbtInd>CRDT</CdtDbtInd>",
    "<CdtDbtInd>DBIT</CdtDbtInd>",
    "<Amt Ccy=`"$asset`">875000</Amt>"
)) {
    if ($statementXml -notmatch [regex]::Escape($expected)) {
        throw "Expected camt.053 XML to contain $expected"
    }
}

$balanceA = Invoke-KaniJson -Method Get -Path "/v1/accounts/CORP_A/balances/$asset" -Headers $corpAHeaders
$balanceB = Invoke-KaniJson -Method Get -Path "/v1/accounts/CORP_B/balances/$asset" -Headers $corpBHeaders
$latestBlock = Invoke-KaniJson -Method Get -Path "/v1/blocks/latest" -Headers $adminHeaders
$pending = Invoke-KaniJson -Method Get -Path "/v1/transactions/pending?limit=100&offset=0" -Headers $adminHeaders
$settlementReport = Invoke-KaniJson -Method Get -Path "/v1/reports/settlement-summary?limit=500&offset=0" -Headers $adminHeaders
$complianceReport = Invoke-KaniJson -Method Get -Path "/v1/reports/compliance-decisions?limit=500&offset=0" -Headers $adminHeaders
$validatorReport = Invoke-KaniJson -Method Get -Path "/v1/reports/validator-finality?limit=500&offset=0" -Headers $adminHeaders

if ([int64]$balanceA.amount -ne 875000) {
    throw "Expected CORP_A balance 875000, got $($balanceA.amount)"
}
if ([int64]$balanceB.amount -ne 125000) {
    throw "Expected CORP_B balance 125000, got $($balanceB.amount)"
}
if ([int64]$pending.count -ne 0) {
    throw "Expected no pending transactions, got $($pending.count)"
}
if ($settlementReport.report_type -ne "settlement_summary") {
    throw "Expected settlement summary report"
}
$mintedForAsset = Get-JsonProperty -Object $settlementReport.minted_amount_by_asset -Name $asset
$transferredForAsset = Get-JsonProperty -Object $settlementReport.gross_transfer_amount_by_asset -Name $asset
if ([int64]$mintedForAsset -ne 1000000) {
    throw "Expected settlement report minted amount 1000000 for $asset, got $mintedForAsset"
}
if ([int64]$transferredForAsset -ne 125000) {
    throw "Expected settlement report gross transfer amount 125000 for $asset, got $transferredForAsset"
}
if ($complianceReport.report_type -ne "compliance_decisions") {
    throw "Expected compliance decision report"
}
$selfTransferRejections = Get-JsonProperty -Object $complianceReport.decisions_by_rule_id -Name "NO_SELF_TRANSFER"
if ([int64]$selfTransferRejections -lt 1) {
    throw "Expected compliance report to include at least one NO_SELF_TRANSFER decision"
}
if ($validatorReport.report_type -ne "validator_finality") {
    throw "Expected validator finality report"
}
if ([int64]$validatorReport.required_finality_votes -ne 2) {
    throw "Expected validator finality report required_finality_votes 2, got $($validatorReport.required_finality_votes)"
}
if ([int64]$validatorReport.finalized_block_count -lt 1) {
    throw "Expected validator finality report to include finalized blocks"
}

[pscustomobject]@{
    profile = if ($WaitForContinuousValidators) { "phase5b-gke-continuous-validators" } else { "phase2-lean-no-gke" }
    base_url = $BaseUrl
    health = $health.status
    asset = $asset
    mint_transaction = $mint.transaction_id
    transfer_transaction = $transfer.transaction_id
    iso_transaction = $isoTransfer.payment.transaction_id
    iso_message_id = $isoTransfer.message_id
    iso_status = "ACSC"
    iso_statement_account = "CORP_A"
    compliance_blocked_self_transfer = $true
    corp_a_balance = $balanceA.amount
    corp_b_balance = $balanceB.amount
    latest_block_height = $latestBlock.height
    latest_block_validator = $latestBlock.validator
    latest_block_finalized_by = $latestBlock.finalized_by -join ","
    pending_count = $pending.count
    audit_reports_verified = $true
    settlement_report_transactions = $settlementReport.transaction_count
    compliance_report_events = $complianceReport.event_count
    validator_report_finalized_blocks = $validatorReport.finalized_block_count
    status = "ok"
}
