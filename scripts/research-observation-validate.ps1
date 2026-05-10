$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "config/research-observation-schedule.yaml",
    "docs/research/observations/README.md",
    "scripts/research-daily-collection.ps1",
    "scripts/research-summarize-observations.ps1",
    "scripts/register-research-collection-schedule.ps1"
)

foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
        throw "Missing research observation file: $path"
    }
}

$config = Get-Content "config/research-observation-schedule.yaml" -Raw
$readme = Get-Content "docs/research/observations/README.md" -Raw
$collector = Get-Content "scripts/research-daily-collection.ps1" -Raw
$scheduler = Get-Content "scripts/register-research-collection-schedule.ps1" -Raw

$expectedConfig = @(
    "research-observation-schedule-rc1",
    "status: scheduled_research_collection_ready",
    "cadence: daily",
    "total_days: 21",
    "first_checkpoint_days: 7",
    "second_checkpoint_days: 14",
    "third_checkpoint_days: 21",
    "scheduler_type: windows_task_scheduler",
    "run_smoke_test_daily: true",
    "generate_summary_after_collection: true",
    "real_value: false",
    "redeemable: false",
    "production_value_movement_allowed: false"
)

foreach ($expected in $expectedConfig) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Research observation config missing expected value: $expected"
    }
}

foreach ($expected in @(
    "kani_research_daily_observations.csv",
    "kani_research_presentation_series.csv",
    "KANI_RESEARCH_OBSERVATION_REPORT.md",
    "Latest finalized block height over time",
    "Validator pods running and restart count over time"
)) {
    if ($readme -notmatch [regex]::Escape($expected)) {
        throw "Research observation README missing expected value: $expected"
    }
}

foreach ($expected in @(
    "cloud_run_api.json",
    "cloud_sql_instance.json",
    "gke_cluster.json",
    "api_latest_block.json",
    "api_pending_transactions.json",
    "api_settlement_report.json",
    "daily_smoke_result.json",
    "latency_corp_a_balance_ms",
    "latency_corp_b_balance_ms",
    "institution_latency_paths_recorded"
)) {
    if ($collector -notmatch [regex]::Escape($expected)) {
        throw "Collector script missing expected artifact reference: $expected"
    }
}

foreach ($expected in @(
    "KANI Research Daily Observation",
    "KANI Research 7 Day Summary",
    "KANI Research 14 Day Summary",
    "KANI Research 21 Day Summary",
    "-RunSmoke -GenerateSummary"
)) {
    if ($scheduler -notmatch [regex]::Escape($expected)) {
        throw "Scheduler registration script missing expected value: $expected"
    }
}

foreach ($forbidden in @(
    "real_value: true",
    "redeemable: true",
    "production_value_movement_allowed: true",
    "external_institution_onboarding_enabled: true",
    "fiat_deposit_redemption_enabled: true"
)) {
    if ($config -match [regex]::Escape($forbidden)) {
        throw "Research observation schedule must not enable forbidden boundary: $forbidden"
    }
}

$csvPath = "docs/research/observations/kani_research_daily_observations.csv"
$observationRows = 0
if (Test-Path $csvPath) {
    $rows = @(Import-Csv $csvPath)
    $observationRows = $rows.Count
    foreach ($requiredColumn in @(
        "collection_id",
        "captured_at_utc",
        "api_health",
        "latest_block_height",
        "pending_count",
        "validator_pods_running",
        "validator_restarts_total",
        "latency_admin_latest_block_ms",
        "latency_corp_a_balance_ms",
        "latency_corp_b_balance_ms",
        "smoke_duration_ms",
        "smoke_status"
    )) {
        if (-not ($rows[0].PSObject.Properties.Name -contains $requiredColumn)) {
            throw "Observation CSV missing required column: $requiredColumn"
        }
    }
}

[pscustomobject]@{
    package = "kani-research-observation-schedule"
    release_candidate = "research-observation-schedule-rc1"
    status = "ok"
    total_days = 21
    first_checkpoint_days = 7
    second_checkpoint_days = 14
    third_checkpoint_days = 21
    observation_rows = $observationRows
    scheduler_type = "windows_task_scheduler"
    real_value = $false
    redeemable = $false
}
