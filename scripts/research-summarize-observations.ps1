param(
    [int]$WindowDays = 21,
    [string]$ObservationRoot = "docs/research/observations",
    [string]$OutputName = "KANI_RESEARCH_OBSERVATION_REPORT.md"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$observationRootPath = Join-Path $repoRoot $ObservationRoot
$csvPath = Join-Path $observationRootPath "kani_research_daily_observations.csv"

if (-not (Test-Path $csvPath)) {
    throw "Observation CSV not found: $csvPath"
}

$rows = @(Import-Csv $csvPath | Sort-Object captured_at_utc)
if ($rows.Count -eq 0) {
    throw "Observation CSV has no rows"
}

$cutoff = (Get-Date).ToUniversalTime().AddDays(-1 * $WindowDays)
$windowRows = @($rows | Where-Object {
    try {
        ([datetime]$_.captured_at_utc).ToUniversalTime() -ge $cutoff
    } catch {
        $false
    }
})

if ($windowRows.Count -eq 0) {
    $windowRows = $rows
}

$metricRows = @($windowRows | Where-Object { $_.status -ne "failed" })
if ($metricRows.Count -eq 0) {
    $metricRows = $windowRows
}

function To-Long {
    param($Value)

    if ($null -eq $Value -or "$Value" -eq "") {
        return $null
    }

    return [int64]$Value
}

function Get-Values {
    param(
        [array]$InputRows,
        [string]$Name
    )

    return @($InputRows | ForEach-Object { To-Long $_.$Name } | Where-Object { $null -ne $_ })
}

function Format-Nullable {
    param($Value)

    if ($null -eq $Value -or "$Value" -eq "") {
        return "n/a"
    }

    return "$Value"
}

$latest = $metricRows[-1]
$blockValues = Get-Values -InputRows $metricRows -Name "latest_block_height"
$pendingValues = Get-Values -InputRows $metricRows -Name "pending_count"
$restartValues = Get-Values -InputRows $metricRows -Name "validator_restarts_total"
$podValues = Get-Values -InputRows $metricRows -Name "validator_pods_running"
$apiErrorValues = Get-Values -InputRows $metricRows -Name "api_error_count_24h"
$systemErrorValues = Get-Values -InputRows $metricRows -Name "kani_system_error_count_24h"
$warningValues = Get-Values -InputRows $metricRows -Name "warning_count_24h"
$healthLatencyValues = Get-Values -InputRows $metricRows -Name "latency_health_ms"
$adminBlockLatencyValues = Get-Values -InputRows $metricRows -Name "latency_admin_latest_block_ms"
$corpALatencyValues = Get-Values -InputRows $metricRows -Name "latency_corp_a_balance_ms"
$corpBLatencyValues = Get-Values -InputRows $metricRows -Name "latency_corp_b_balance_ms"
$smokeDurationValues = Get-Values -InputRows $metricRows -Name "smoke_duration_ms"

$firstBlock = if ($blockValues.Count -gt 0) { $blockValues[0] } else { $null }
$latestBlock = if ($blockValues.Count -gt 0) { $blockValues[-1] } else { $null }
$blockGrowth = if ($null -ne $firstBlock -and $null -ne $latestBlock) { $latestBlock - $firstBlock } else { $null }

$presentationSeriesPath = Join-Path $observationRootPath "kani_research_presentation_series.csv"
$metricRows | Select-Object `
    collection_id,
    captured_at_utc,
    api_health,
    gke_cluster_status,
    validator_pods_running,
    validator_restarts_total,
    latest_block_height,
    pending_count,
    settlement_report_transactions,
    compliance_report_events,
    validator_report_finalized_blocks,
    latency_health_ms,
    latency_admin_latest_block_ms,
    latency_admin_pending_ms,
    latency_admin_settlement_report_ms,
    latency_admin_validator_report_ms,
    latency_corp_a_balance_ms,
    latency_corp_b_balance_ms,
    smoke_duration_ms,
    institution_latency_paths_recorded,
    api_error_count_24h,
    kani_system_error_count_24h,
    warning_count_24h,
    smoke_status |
    Export-Csv -Path $presentationSeriesPath -NoTypeInformation

$rollup = [ordered]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    window_days = $WindowDays
    observation_count = $windowRows.Count
    successful_observation_count = $metricRows.Count
    first_collection_id = $metricRows[0].collection_id
    latest_collection_id = $latest.collection_id
    first_block_height = $firstBlock
    latest_block_height = $latestBlock
    block_growth = $blockGrowth
    max_pending_count = if ($pendingValues.Count -gt 0) { ($pendingValues | Measure-Object -Maximum).Maximum } else { $null }
    max_validator_restarts_total = if ($restartValues.Count -gt 0) { ($restartValues | Measure-Object -Maximum).Maximum } else { $null }
    min_validator_pods_running = if ($podValues.Count -gt 0) { ($podValues | Measure-Object -Minimum).Minimum } else { $null }
    max_api_errors_24h = if ($apiErrorValues.Count -gt 0) { ($apiErrorValues | Measure-Object -Maximum).Maximum } else { $null }
    max_kani_system_errors_24h = if ($systemErrorValues.Count -gt 0) { ($systemErrorValues | Measure-Object -Maximum).Maximum } else { $null }
    max_warning_count_24h = if ($warningValues.Count -gt 0) { ($warningValues | Measure-Object -Maximum).Maximum } else { $null }
    avg_health_latency_ms = if ($healthLatencyValues.Count -gt 0) { [int][math]::Round(($healthLatencyValues | Measure-Object -Average).Average) } else { $null }
    avg_admin_latest_block_latency_ms = if ($adminBlockLatencyValues.Count -gt 0) { [int][math]::Round(($adminBlockLatencyValues | Measure-Object -Average).Average) } else { $null }
    avg_corp_a_balance_latency_ms = if ($corpALatencyValues.Count -gt 0) { [int][math]::Round(($corpALatencyValues | Measure-Object -Average).Average) } else { $null }
    avg_corp_b_balance_latency_ms = if ($corpBLatencyValues.Count -gt 0) { [int][math]::Round(($corpBLatencyValues | Measure-Object -Average).Average) } else { $null }
    avg_smoke_duration_ms = if ($smokeDurationValues.Count -gt 0) { [int][math]::Round(($smokeDurationValues | Measure-Object -Average).Average) } else { $null }
    smoke_ok_count = @($metricRows | Where-Object { $_.smoke_status -eq "ok" }).Count
    failed_collection_count = @($windowRows | Where-Object { $_.status -eq "failed" }).Count
}

$rollupPath = Join-Path $observationRootPath "kani_research_observation_rollup.json"
$rollup | ConvertTo-Json -Depth 20 | Set-Content -Path $rollupPath -Encoding utf8

$reportPath = Join-Path $observationRootPath $OutputName
$generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$report = @"
# KANI Research Observation Report

Generated: $generatedAt

Window: last $WindowDays days

Status: sandbox research observation data pack

## Executive Signal

This report summarizes daily sandbox observations for presentation and research use. It does not claim production readiness, regulatory approval, or real-value settlement capability.

## Latest Observation

| Metric | Value |
|---|---:|
| Collection ID | $(Format-Nullable $latest.collection_id) |
| Captured at UTC | $(Format-Nullable $latest.captured_at_utc) |
| API health | $(Format-Nullable $latest.api_health) |
| Cloud SQL state | $(Format-Nullable $latest.cloud_sql_state) |
| GKE cluster status | $(Format-Nullable $latest.gke_cluster_status) |
| Validator pods running | $(Format-Nullable $latest.validator_pods_running) |
| Validator restarts total | $(Format-Nullable $latest.validator_restarts_total) |
| Latest block height | $(Format-Nullable $latest.latest_block_height) |
| Pending transaction count | $(Format-Nullable $latest.pending_count) |
| Settlement report transactions | $(Format-Nullable $latest.settlement_report_transactions) |
| Compliance report events | $(Format-Nullable $latest.compliance_report_events) |
| Validator finality report blocks | $(Format-Nullable $latest.validator_report_finalized_blocks) |
| Health latency ms | $(Format-Nullable $latest.latency_health_ms) |
| Admin latest-block latency ms | $(Format-Nullable $latest.latency_admin_latest_block_ms) |
| CORP_A balance latency ms | $(Format-Nullable $latest.latency_corp_a_balance_ms) |
| CORP_B balance latency ms | $(Format-Nullable $latest.latency_corp_b_balance_ms) |
| Smoke lifecycle duration ms | $(Format-Nullable $latest.smoke_duration_ms) |
| Institution paths timed | $(Format-Nullable $latest.institution_latency_paths_recorded) |
| Smoke test status | $(Format-Nullable $latest.smoke_status) |

## Window Rollup

| Signal | Value |
|---|---:|
| Observation rows | $($rollup.observation_count) |
| Successful observation rows used for charts | $($rollup.successful_observation_count) |
| First block height | $(Format-Nullable $rollup.first_block_height) |
| Latest block height | $(Format-Nullable $rollup.latest_block_height) |
| Block growth | $(Format-Nullable $rollup.block_growth) |
| Max pending count | $(Format-Nullable $rollup.max_pending_count) |
| Max validator restarts | $(Format-Nullable $rollup.max_validator_restarts_total) |
| Minimum validator pods running | $(Format-Nullable $rollup.min_validator_pods_running) |
| Max API errors in a 24h window | $(Format-Nullable $rollup.max_api_errors_24h) |
| Max KANI system errors in a 24h window | $(Format-Nullable $rollup.max_kani_system_errors_24h) |
| Max warnings in a 24h window | $(Format-Nullable $rollup.max_warning_count_24h) |
| Avg health latency ms | $(Format-Nullable $rollup.avg_health_latency_ms) |
| Avg admin latest-block latency ms | $(Format-Nullable $rollup.avg_admin_latest_block_latency_ms) |
| Avg CORP_A balance latency ms | $(Format-Nullable $rollup.avg_corp_a_balance_latency_ms) |
| Avg CORP_B balance latency ms | $(Format-Nullable $rollup.avg_corp_b_balance_latency_ms) |
| Avg smoke lifecycle duration ms | $(Format-Nullable $rollup.avg_smoke_duration_ms) |
| Smoke tests passed | $($rollup.smoke_ok_count) |
| Failed collections | $($rollup.failed_collection_count) |

## PowerPoint-Ready Data Files

~~~text
docs/research/observations/kani_research_daily_observations.csv
docs/research/observations/kani_research_presentation_series.csv
docs/research/observations/kani_research_observation_rollup.json
~~~

## Presentation Use

Recommended charts:

1. Latest block height over time.
2. Pending transactions over time.
3. Validator pods running and validator restarts over time.
4. API, KANI system, and Cloud SQL errors by daily collection.
5. Settlement, compliance, and validator-finality report growth.
6. Institution-path latency for KANI_ADMIN, CORP_A, and CORP_B.

## Boundary

The observation remains sandbox-only:

~~~text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
~~~
"@

$report | Set-Content -Path $reportPath -Encoding utf8

[pscustomobject]@{
    status = "ok"
    window_days = $WindowDays
    observation_count = $windowRows.Count
    report = $reportPath
    presentation_series = $presentationSeriesPath
    rollup = $rollupPath
    latest_block_height = $rollup.latest_block_height
    block_growth = $rollup.block_growth
}
