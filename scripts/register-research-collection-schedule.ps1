param(
    [string]$StartTime = "09:00",
    [int]$TotalDays = 21,
    [int]$FirstCheckpointDays = 7,
    [int]$SecondCheckpointDays = 14,
    [switch]$RunNow,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$collector = Join-Path $PSScriptRoot "research-daily-collection.ps1"
$summarizer = Join-Path $PSScriptRoot "research-summarize-observations.ps1"

if (-not (Test-Path $collector)) {
    throw "Missing collector script: $collector"
}

if (-not (Test-Path $summarizer)) {
    throw "Missing summarizer script: $summarizer"
}

function Get-ScheduledStart {
    param([string]$TimeText)

    $today = Get-Date
    $parts = $TimeText.Split(":")
    if ($parts.Count -lt 2) {
        throw "StartTime must be HH:mm"
    }

    $candidate = Get-Date -Year $today.Year -Month $today.Month -Day $today.Day -Hour ([int]$parts[0]) -Minute ([int]$parts[1]) -Second 0
    if ($candidate -le (Get-Date).AddMinutes(2)) {
        $candidate = $candidate.AddDays(1)
    }

    return $candidate
}

function Register-OrReplaceTask {
    param(
        [string]$TaskName,
        [string]$Description,
        $Action,
        $Trigger,
        $Settings
    )

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing -and $Force) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Description $Description `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Force | Out-Null
}

$start = Get-ScheduledStart -TimeText $StartTime
$end = $start.AddDays($TotalDays)
$checkpoint7 = $start.AddDays($FirstCheckpointDays)
$checkpoint14 = $start.AddDays($SecondCheckpointDays)
$checkpoint21 = $start.AddDays($TotalDays)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

$dailyTaskName = "KANI Research Daily Observation"
$dailyAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$collector`" -RunSmoke -GenerateSummary" `
    -WorkingDirectory $repoRoot

$dailyTrigger = New-ScheduledTaskTrigger -Daily -At $start
$dailyTrigger.StartBoundary = $start.ToString("s")
$dailyTrigger.EndBoundary = $end.ToString("s")

Register-OrReplaceTask `
    -TaskName $dailyTaskName `
    -Description "Daily KANI sandbox research collection for 21 days: API, ledger, validators, GKE, Cloud SQL, logs, and smoke proof." `
    -Action $dailyAction `
    -Trigger $dailyTrigger `
    -Settings $settings

$sevenDayTaskName = "KANI Research 7 Day Summary"
$sevenDayAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$summarizer`" -WindowDays 7 -OutputName KANI_RESEARCH_7_DAY_REPORT.md" `
    -WorkingDirectory $repoRoot
$sevenDayTrigger = New-ScheduledTaskTrigger -Once -At $checkpoint7

Register-OrReplaceTask `
    -TaskName $sevenDayTaskName `
    -Description "Generate the KANI 7-day research observation summary for PowerPoint and research use." `
    -Action $sevenDayAction `
    -Trigger $sevenDayTrigger `
    -Settings $settings

$fourteenDayTaskName = "KANI Research 14 Day Summary"
$fourteenDayAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$summarizer`" -WindowDays 14 -OutputName KANI_RESEARCH_14_DAY_REPORT.md" `
    -WorkingDirectory $repoRoot
$fourteenDayTrigger = New-ScheduledTaskTrigger -Once -At $checkpoint14

Register-OrReplaceTask `
    -TaskName $fourteenDayTaskName `
    -Description "Generate the KANI 14-day research observation summary for PowerPoint and research use." `
    -Action $fourteenDayAction `
    -Trigger $fourteenDayTrigger `
    -Settings $settings

$twentyOneDayTaskName = "KANI Research 21 Day Summary"
$twentyOneDayAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$summarizer`" -WindowDays 21 -OutputName KANI_RESEARCH_21_DAY_REPORT.md" `
    -WorkingDirectory $repoRoot
$twentyOneDayTrigger = New-ScheduledTaskTrigger -Once -At $checkpoint21

Register-OrReplaceTask `
    -TaskName $twentyOneDayTaskName `
    -Description "Generate the KANI 21-day research observation summary for PowerPoint and research use." `
    -Action $twentyOneDayAction `
    -Trigger $twentyOneDayTrigger `
    -Settings $settings

if ($RunNow) {
    & $collector -RunSmoke -GenerateSummary | Out-Host
}

[pscustomobject]@{
    status = "ok"
    daily_task = $dailyTaskName
    seven_day_summary_task = $sevenDayTaskName
    fourteen_day_summary_task = $fourteenDayTaskName
    twenty_one_day_summary_task = $twentyOneDayTaskName
    first_daily_run_local = $start.ToString("o")
    daily_end_boundary_local = $end.ToString("o")
    seven_day_summary_local = $checkpoint7.ToString("o")
    fourteen_day_summary_local = $checkpoint14.ToString("o")
    twenty_one_day_summary_local = $checkpoint21.ToString("o")
    run_now = [bool]$RunNow
    note = "Tasks run when this Windows workstation is on and the configured user context can access gcloud credentials."
}
