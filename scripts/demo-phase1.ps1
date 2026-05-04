param(
  [string]$BaseUrl = "http://localhost:8080",
  [string]$Asset = "KCAD_DEMO_$(Get-Date -Format 'yyyyMMddHHmmss')",
  [switch]$NoStartStack
)

$ErrorActionPreference = "Stop"

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoRoot = Split-Path -Parent $scriptRoot
$base = $BaseUrl.TrimEnd("/")

function Invoke-KaniNative {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [string[]]$Arguments = @()
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
  }
}

function Wait-KaniHealth {
  param([string]$Url)

  for ($i = 0; $i -lt 60; $i++) {
    try {
      return Invoke-RestMethod "$Url/health" -TimeoutSec 2
    } catch {
      Start-Sleep -Seconds 1
    }
  }

  throw "kani-api did not become healthy at $Url"
}

function Invoke-KaniGet {
  param(
    [string]$Url,
    [hashtable]$Headers = @{}
  )

  Invoke-RestMethod $Url -Headers $Headers -TimeoutSec 2
}

function Invoke-KaniPost {
  param(
    [string]$Url,
    [hashtable]$Body,
    [hashtable]$Headers
  )

  Invoke-RestMethod -Method Post $Url `
    -ContentType "application/json" `
    -Headers $Headers `
    -Body ($Body | ConvertTo-Json -Compress)
}

function Wait-KaniPaymentFinalized {
  param(
    [string]$Url,
    [string]$PaymentId,
    [hashtable]$Headers
  )

  for ($i = 0; $i -lt 90; $i++) {
    $payment = Invoke-KaniGet "$Url/v1/payments/$PaymentId" $Headers
    if ($payment.status -eq "FINALIZED") {
      return $payment
    }

    if ($payment.status -eq "REJECTED") {
      throw "payment $PaymentId rejected: $($payment.failure_reason)"
    }

    Start-Sleep -Seconds 1
  }

  throw "payment $PaymentId was not finalized in time"
}

Push-Location $repoRoot
try {
  if (-not $NoStartStack) {
    Invoke-KaniNative docker @("compose", "up", "-d", "--build")
  }

  $health = Wait-KaniHealth -Url $base
  $demoStartedAt = (Get-Date).ToUniversalTime().AddMinutes(-1)

  $treasuryHeaders = @{
    "x-kani-institution-id" = "KANI_TREASURY"
    "x-kani-api-key"        = "sandbox-treasury-token"
  }
  $corpAHeaders = @{
    "x-kani-institution-id" = "CORP_A"
    "x-kani-api-key"        = "sandbox-corp-a-token"
  }
  $corpBHeaders = @{
    "x-kani-institution-id" = "CORP_B"
    "x-kani-api-key"        = "sandbox-corp-b-token"
  }
  $adminHeaders = @{
    "x-kani-institution-id" = "KANI_ADMIN"
    "x-kani-api-key"        = "sandbox-admin-token"
  }

  $mint = Invoke-KaniPost "$base/v1/sandbox/mint" @{
    treasury = "TREASURY_SANDBOX"
    to       = "CORP_A"
    asset    = $Asset
    amount   = 1000000
  } $treasuryHeaders
  $mint = Wait-KaniPaymentFinalized -Url $base -PaymentId $mint.payment_id -Headers $treasuryHeaders

  $transfer = Invoke-KaniPost "$base/v1/payments" @{
    from                = "CORP_A"
    to                  = "CORP_B"
    asset               = $Asset
    amount              = 100000
    client_reference_id = "demo-$Asset-transfer"
  } $corpAHeaders
  $transfer = Wait-KaniPaymentFinalized -Url $base -PaymentId $transfer.payment_id -Headers $corpAHeaders

  $balanceA = Invoke-KaniGet "$base/v1/accounts/CORP_A/balances/$Asset" $corpAHeaders
  $balanceB = Invoke-KaniGet "$base/v1/accounts/CORP_B/balances/$Asset" $corpBHeaders
  $issued = Invoke-KaniGet "$base/v1/assets/$Asset/issued" $adminHeaders
  $latest = Invoke-KaniGet "$base/v1/blocks/latest" $adminHeaders
  $accounts = Invoke-KaniGet "$base/v1/accounts" $adminHeaders
  $validators = Invoke-KaniGet "$base/v1/validators" $adminHeaders
  $pending = Invoke-KaniGet "$base/v1/transactions/pending?limit=100&offset=0" $adminHeaders
  $createdFrom = [uri]::EscapeDataString($demoStartedAt.ToString("o"))
  $audit = Invoke-KaniGet "$base/v1/audit-events?event_type=TRANSACTION_FINALIZED&created_from=$createdFrom&limit=100&offset=0" $adminHeaders

  if ($balanceA.amount -ne 900000) {
    throw "expected CORP_A balance 900000, got $($balanceA.amount)"
  }

  if ($balanceB.amount -ne 100000) {
    throw "expected CORP_B balance 100000, got $($balanceB.amount)"
  }

  if ($issued.amount -ne 1000000) {
    throw "expected issued supply 1000000, got $($issued.amount)"
  }

  $latestFinalityVotes = @($latest.finalized_by).Count
  if ($latestFinalityVotes -lt 2) {
    throw "expected latest block to have at least 2 finality votes, got $latestFinalityVotes"
  }

  $validatorCount = @($validators).Count
  if ($validatorCount -ne 3) {
    throw "expected 3 validators, got $validatorCount"
  }

  $validatorsWithHeartbeat = @($validators | Where-Object { $null -ne $_.last_seen_at }).Count
  if ($validatorsWithHeartbeat -ne 3) {
    throw "expected all 3 validators to report heartbeat state, got $validatorsWithHeartbeat"
  }

  if ($pending.count -ne 0) {
    throw "expected no pending transactions after demo finality, got $($pending.count)"
  }

  if ($audit.count -lt 2) {
    throw "expected at least 2 finalized transaction audit events for this demo, got $($audit.count)"
  }

  [pscustomobject]@{
    phase                         = "Phase 1 Local MVP"
    api_status                    = $health.status
    sandbox_environment           = $health.environment
    real_value                    = $health.real_value
    redeemable                    = $health.redeemable
    asset                         = $Asset
    mint_payment_id               = $mint.payment_id
    mint_status                   = $mint.status
    transfer_payment_id           = $transfer.payment_id
    transfer_status               = $transfer.status
    corp_a_balance                = $balanceA.amount
    corp_b_balance                = $balanceB.amount
    issued_supply                 = $issued.amount
    latest_block_height           = $latest.height
    latest_block_hash             = $latest.hash
    latest_block_validator        = $latest.validator
    latest_block_finality_votes   = $latestFinalityVotes
    account_count                 = @($accounts).Count
    validator_count               = $validatorCount
    validators_with_heartbeat     = $validatorsWithHeartbeat
    pending_transaction_count     = $pending.count
    finalized_audit_event_count   = $audit.count
    acceptance_summary            = "mint, transfer, balances, finality, validators, and audit verified"
  }
} finally {
  Pop-Location
}
