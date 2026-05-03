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
    [hashtable]$Body,
    [hashtable]$Headers = @{}
  )

  Invoke-RestMethod -Method Post $Url `
    -ContentType "application/json" `
    -Headers $Headers `
    -Body ($Body | ConvertTo-Json -Compress)
}

function Invoke-KaniGet {
  param(
    [string]$Url,
    [hashtable]$Headers = @{}
  )

  Invoke-RestMethod $Url -Headers $Headers -TimeoutSec 2
}

function Assert-KaniStatusPost {
  param(
    [string]$Url,
    [hashtable]$Body,
    [hashtable]$Headers,
    [int]$ExpectedStatusCode
  )

  try {
    Invoke-KaniPost $Url $Body $Headers | Out-Null
  } catch {
    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    if ($statusCode -eq $ExpectedStatusCode) {
      return
    }

    throw
  }

  throw "expected HTTP $ExpectedStatusCode, but request succeeded"
}

function Assert-KaniStatusGet {
  param(
    [string]$Url,
    [hashtable]$Headers,
    [int]$ExpectedStatusCode
  )

  try {
    Invoke-KaniGet $Url $Headers | Out-Null
  } catch {
    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    if ($statusCode -eq $ExpectedStatusCode) {
      return
    }

    throw
  }

  throw "expected HTTP $ExpectedStatusCode, but request succeeded"
}

function Assert-KaniConflictPost {
  param(
    [string]$Url,
    [hashtable]$Body,
    [hashtable]$Headers
  )

  Assert-KaniStatusPost $Url $Body $Headers 409
}

function Assert-KaniForbiddenPost {
  param(
    [string]$Url,
    [hashtable]$Body,
    [hashtable]$Headers
  )

  Assert-KaniStatusPost $Url $Body $Headers 403
}

function Assert-KaniForbiddenGet {
  param(
    [string]$Url,
    [hashtable]$Headers
  )

  Assert-KaniStatusGet $Url $Headers 403
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
    docker compose up -d --build
  }

  Wait-KaniHealth -Url $base | Out-Null

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

  $paymentRequest = @{
    from                = "CORP_A"
    to                  = "CORP_B"
    asset               = $Asset
    amount              = 100000
    client_reference_id = "smoke-$Asset-transfer"
  }
  $payment = Invoke-KaniPost "$base/v1/payments" $paymentRequest $corpAHeaders
  $paymentRetry = Invoke-KaniPost "$base/v1/payments" $paymentRequest $corpAHeaders

  if ($paymentRetry.payment_id -ne $payment.payment_id) {
    throw "expected idempotent retry to return payment $($payment.payment_id), got $($paymentRetry.payment_id)"
  }

  $conflictingPaymentRequest = $paymentRequest.Clone()
  $conflictingPaymentRequest.amount = 200000
  Assert-KaniConflictPost "$base/v1/payments" $conflictingPaymentRequest $corpAHeaders

  $forbiddenPaymentRequest = $paymentRequest.Clone()
  $forbiddenPaymentRequest.client_reference_id = "smoke-$Asset-forbidden"
  Assert-KaniForbiddenPost "$base/v1/payments" $forbiddenPaymentRequest $corpBHeaders
  Assert-KaniForbiddenGet "$base/v1/payments/$($payment.payment_id)" $treasuryHeaders
  Assert-KaniForbiddenGet "$base/v1/accounts/CORP_A/balances/$Asset" $corpBHeaders
  Assert-KaniForbiddenGet "$base/v1/blocks/latest" $corpAHeaders
  Assert-KaniForbiddenGet "$base/v1/blocks" $corpAHeaders
  Assert-KaniForbiddenGet "$base/v1/audit-events" $corpAHeaders
  Assert-KaniForbiddenGet "$base/v1/validators" $corpAHeaders
  Assert-KaniForbiddenGet "$base/v1/transactions/pending" $corpAHeaders

  $payment = Wait-KaniPaymentFinalized -Url $base -PaymentId $payment.payment_id -Headers $corpAHeaders
  Invoke-KaniGet "$base/v1/payments/$($payment.payment_id)" $corpBHeaders | Out-Null
  $paymentRetryAfterFinality = Invoke-KaniPost "$base/v1/payments" $paymentRequest $corpAHeaders

  if ($paymentRetryAfterFinality.payment_id -ne $payment.payment_id) {
    throw "expected finalized idempotent retry to return payment $($payment.payment_id), got $($paymentRetryAfterFinality.payment_id)"
  }

  $balanceA = Invoke-KaniGet "$base/v1/accounts/CORP_A/balances/$Asset" $corpAHeaders
  $balanceB = Invoke-KaniGet "$base/v1/accounts/CORP_B/balances/$Asset" $corpBHeaders
  $latestBeforeRestart = Invoke-KaniGet "$base/v1/blocks/latest" $adminHeaders

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

  $balanceAAfterRestart = Invoke-KaniGet "$base/v1/accounts/CORP_A/balances/$Asset" $corpAHeaders
  $balanceBAfterRestart = Invoke-KaniGet "$base/v1/accounts/CORP_B/balances/$Asset" $corpBHeaders
  $latestAfterRestart = Invoke-KaniGet "$base/v1/blocks/latest" $adminHeaders
  $blocks = Invoke-KaniGet "$base/v1/blocks" $adminHeaders
  $auditEvents = Invoke-KaniGet "$base/v1/audit-events" $adminHeaders
  $validators = Invoke-KaniGet "$base/v1/validators" $adminHeaders
  $pendingTransactions = Invoke-KaniGet "$base/v1/transactions/pending" $adminHeaders
  $authorizationAuditEvents = @($auditEvents | Where-Object { $_.event_type -eq "API_AUTHORIZATION_DECISION" })
  $deniedAuthorizationAuditEvents = @($authorizationAuditEvents | Where-Object { $_.metadata.decision -eq "DENIED" })
  $allowedAuthorizationAuditEvents = @($authorizationAuditEvents | Where-Object { $_.metadata.decision -eq "ALLOWED" })
  $validatorsWithHeartbeat = @($validators | Where-Object { $null -ne $_.last_seen_at })
  $validatorsWithFinalizedBlock = @($validators | Where-Object { $null -ne $_.last_finalized_height })

  if ($balanceAAfterRestart.amount -ne 900000) {
    throw "expected persisted CORP_A balance 900000, got $($balanceAAfterRestart.amount)"
  }

  if ($balanceBAfterRestart.amount -ne 100000) {
    throw "expected persisted CORP_B balance 100000, got $($balanceBAfterRestart.amount)"
  }

  if ($validatorsWithHeartbeat.Count -ne 3) {
    throw "expected all 3 validators to report heartbeat state, got $($validatorsWithHeartbeat.Count)"
  }

  if ($validatorsWithFinalizedBlock.Count -lt 1) {
    throw "expected at least one validator to report finalized block state"
  }

  if ($deniedAuthorizationAuditEvents.Count -lt 7) {
    throw "expected at least 7 denied authorization audit events, got $($deniedAuthorizationAuditEvents.Count)"
  }

  if ($allowedAuthorizationAuditEvents.Count -lt 1) {
    throw "expected allowed authorization audit events"
  }

  $deniedBalanceAuditEvents = @($deniedAuthorizationAuditEvents | Where-Object {
      $_.metadata.action -eq "read_balance" -and
      $_.metadata.resource -eq "account:CORP_A:balance:$Asset" -and
      $_.metadata.institution_id -eq "CORP_B"
    })
  if ($deniedBalanceAuditEvents.Count -lt 1) {
    throw "expected denied read_balance audit event for CORP_B reading CORP_A"
  }

  $deniedNetworkAuditEvents = @($deniedAuthorizationAuditEvents | Where-Object {
      $_.metadata.action -eq "read_blocks" -and
      $_.metadata.resource -eq "network:blocks" -and
      $_.metadata.institution_id -eq "CORP_A"
    })
  if ($deniedNetworkAuditEvents.Count -lt 1) {
    throw "expected denied read_blocks audit event for non-admin CORP_A"
  }

  [pscustomobject]@{
    asset                        = $Asset
    mint_payment_id              = $mint.payment_id
    transfer_payment_id          = $payment.payment_id
    transfer_client_reference_id = $payment.client_reference_id
    idempotency_conflict_checked = $true
    authorization_checked        = $true
    read_authorization_checked   = $true
    admin_authorization_checked  = $true
    authorization_audit_checked  = $true
    balance_a_before_restart     = $balanceA.amount
    balance_b_before_restart     = $balanceB.amount
    latest_height_before_restart = $latestBeforeRestart.height
    balance_a_after_restart      = $balanceAAfterRestart.amount
    balance_b_after_restart      = $balanceBAfterRestart.amount
    latest_height_after_restart  = $latestAfterRestart.height
    block_count                  = @($blocks).Count
    audit_event_count            = @($auditEvents).Count
    authorization_audit_count    = $authorizationAuditEvents.Count
    denied_authorization_count   = $deniedAuthorizationAuditEvents.Count
    validator_count              = @($validators).Count
    validator_heartbeat_count    = $validatorsWithHeartbeat.Count
    validator_finalized_count    = $validatorsWithFinalizedBlock.Count
    pending_transaction_count    = @($pendingTransactions).Count
  }
} finally {
  Pop-Location
}
