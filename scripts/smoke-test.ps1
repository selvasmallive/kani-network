param(
  [string]$BaseUrl = "http://127.0.0.1:8080",
  [string]$Asset = "KCAD_SMOKE_$(Get-Date -Format 'yyyyMMddHHmmss')",
  [switch]$NoStartStack,
  [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoRoot = Split-Path -Parent $scriptRoot
$base = $BaseUrl.TrimEnd("/")

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

function Invoke-KaniPost {
  param(
    [string]$Url,
    [hashtable]$Body
  )

  Invoke-RestMethod -Method Post $Url `
    -ContentType "application/json" `
    -Body ($Body | ConvertTo-Json -Compress)
}

function Wait-KaniPaymentFinalized {
  param(
    [string]$Url,
    [string]$PaymentId
  )

  for ($i = 0; $i -lt 90; $i++) {
    $payment = Invoke-RestMethod "$Url/v1/payments/$PaymentId" -TimeoutSec 2
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
    docker compose up -d --build
  }

  Wait-KaniHealth -Url $base | Out-Null

  $mint = Invoke-KaniPost "$base/v1/sandbox/mint" @{
    treasury = "TREASURY_SANDBOX"
    to       = "CORP_A"
    asset    = $Asset
    amount   = 1000000
  }
  $mint = Wait-KaniPaymentFinalized -Url $base -PaymentId $mint.payment_id

  $payment = Invoke-KaniPost "$base/v1/payments" @{
    from   = "CORP_A"
    to     = "CORP_B"
    asset  = $Asset
    amount = 100000
  }
  $payment = Wait-KaniPaymentFinalized -Url $base -PaymentId $payment.payment_id

  $balanceA = Invoke-RestMethod "$base/v1/accounts/CORP_A/balances/$Asset"
  $balanceB = Invoke-RestMethod "$base/v1/accounts/CORP_B/balances/$Asset"
  $latestBeforeRestart = Invoke-RestMethod "$base/v1/blocks/latest"

  if ($balanceA.amount -ne 900000) {
    throw "expected CORP_A balance 900000, got $($balanceA.amount)"
  }

  if ($balanceB.amount -ne 100000) {
    throw "expected CORP_B balance 100000, got $($balanceB.amount)"
  }

  if (-not $NoRestart) {
    docker compose restart kani-api | Out-Null
    Wait-KaniHealth -Url $base | Out-Null
  }

  $balanceAAfterRestart = Invoke-RestMethod "$base/v1/accounts/CORP_A/balances/$Asset"
  $balanceBAfterRestart = Invoke-RestMethod "$base/v1/accounts/CORP_B/balances/$Asset"
  $latestAfterRestart = Invoke-RestMethod "$base/v1/blocks/latest"
  $blocks = Invoke-RestMethod "$base/v1/blocks"
  $auditEvents = Invoke-RestMethod "$base/v1/audit-events"
  $validators = Invoke-RestMethod "$base/v1/validators"
  $pendingTransactions = Invoke-RestMethod "$base/v1/transactions/pending"

  if ($balanceAAfterRestart.amount -ne 900000) {
    throw "expected persisted CORP_A balance 900000, got $($balanceAAfterRestart.amount)"
  }

  if ($balanceBAfterRestart.amount -ne 100000) {
    throw "expected persisted CORP_B balance 100000, got $($balanceBAfterRestart.amount)"
  }

  [pscustomobject]@{
    asset                        = $Asset
    mint_payment_id              = $mint.payment_id
    transfer_payment_id          = $payment.payment_id
    balance_a_before_restart     = $balanceA.amount
    balance_b_before_restart     = $balanceB.amount
    latest_height_before_restart = $latestBeforeRestart.height
    balance_a_after_restart      = $balanceAAfterRestart.amount
    balance_b_after_restart      = $balanceBAfterRestart.amount
    latest_height_after_restart  = $latestAfterRestart.height
    block_count                  = @($blocks).Count
    audit_event_count            = @($auditEvents).Count
    validator_count              = @($validators).Count
    pending_transaction_count    = @($pendingTransactions).Count
  }
} finally {
  Pop-Location
}
