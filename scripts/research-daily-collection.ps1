param(
    [string]$ProjectId = "kani-network-sandbox",
    [string]$Region = "northamerica-northeast1",
    [string]$Zone = "northamerica-northeast1-a",
    [string]$ClusterName = "kani-sandbox-validators",
    [string]$Namespace = "kani-system",
    [string]$ServiceName = "kani-sandbox-api",
    [string]$CostGuardServiceName = "kani-sandbox-cost-guard",
    [string]$CloudSqlInstance = "kani-sandbox-ledger",
    [string]$NamePrefix = "kani-sandbox",
    [string]$OutputRoot = "docs/research/observations",
    [switch]$RunSmoke,
    [switch]$GenerateSummary,
    [switch]$SkipKubectl
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

function Get-ToolPath {
    param(
        [string]$Name,
        [string]$PreferredPath = ""
    )

    if ($PreferredPath -and (Test-Path $PreferredPath)) {
        return $PreferredPath
    }

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Required tool not found on PATH: $Name"
}

function ConvertTo-PlainText {
    param($Value)

    if ($null -eq $Value) {
        return ""
    }

    if ($Value -is [array]) {
        return ($Value | ForEach-Object { "$_" }) -join "`n"
    }

    return "$Value"
}

function Write-JsonFile {
    param(
        [string]$Path,
        $Value
    )

    $Value | ConvertTo-Json -Depth 80 | Set-Content -Path $Path -Encoding utf8
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Value
    )

    $Value | Set-Content -Path $Path -Encoding utf8
}

function Invoke-External {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        if (-not $AllowFailure) {
            throw
        }

        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    if ($null -eq $exitCode) {
        $exitCode = 0
    }

    $result = [pscustomobject]@{
        command = "$FilePath $($Arguments -join ' ')"
        started_at_utc = $startedAt
        completed_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        exit_code = $exitCode
        output = ConvertTo-PlainText $output
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "Command failed with exit code ${exitCode}: $($result.command)`n$($result.output)"
    }

    return $result
}

function Invoke-GcloudJson {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $argsWithFormat = @($Arguments + @("--format=json"))
    $commandResult = Invoke-External -FilePath $gcloud -Arguments $argsWithFormat -AllowFailure:$AllowFailure
    Write-JsonFile -Path (Join-Path $rawDir "$FileName.command.json") -Value $commandResult

    if ($commandResult.exit_code -ne 0 -or -not $commandResult.output.Trim()) {
        return $null
    }

    try {
        $json = $commandResult.output | ConvertFrom-Json
        Write-JsonFile -Path (Join-Path $rawDir $FileName) -Value $json
        return $json
    } catch {
        $summary.errors += "Could not parse JSON for ${FileName}: $($_.Exception.Message)"
        Write-TextFile -Path (Join-Path $rawDir "$FileName.raw.txt") -Value $commandResult.output
        return $null
    }
}

function Invoke-GcloudText {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $commandResult = Invoke-External -FilePath $gcloud -Arguments $Arguments -AllowFailure:$AllowFailure
    Write-JsonFile -Path (Join-Path $rawDir "$FileName.command.json") -Value $commandResult
    Write-TextFile -Path (Join-Path $rawDir $FileName) -Value $commandResult.output
    return $commandResult
}

function Invoke-KubectlJson {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    if ($SkipKubectl) {
        return $null
    }

    $argsWithOutput = @($Arguments + @("-o", "json"))
    $commandResult = Invoke-External -FilePath $kubectl -Arguments $argsWithOutput -AllowFailure:$AllowFailure
    Write-JsonFile -Path (Join-Path $rawDir "$FileName.command.json") -Value $commandResult

    if ($commandResult.exit_code -ne 0 -or -not $commandResult.output.Trim()) {
        return $null
    }

    try {
        $json = $commandResult.output | ConvertFrom-Json
        Write-JsonFile -Path (Join-Path $rawDir $FileName) -Value $json
        return $json
    } catch {
        $summary.errors += "Could not parse kubectl JSON for ${FileName}: $($_.Exception.Message)"
        Write-TextFile -Path (Join-Path $rawDir "$FileName.raw.txt") -Value $commandResult.output
        return $null
    }
}

function Invoke-KubectlText {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    if ($SkipKubectl) {
        return $null
    }

    $commandResult = Invoke-External -FilePath $kubectl -Arguments $Arguments -AllowFailure:$AllowFailure
    Write-JsonFile -Path (Join-Path $rawDir "$FileName.command.json") -Value $commandResult
    Write-TextFile -Path (Join-Path $rawDir $FileName) -Value $commandResult.output
    return $commandResult
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

function Get-SandboxApiKey {
    param([string]$SecretId)

    $secretValue = (& $gcloud secrets versions access latest --secret $SecretId --project $ProjectId 2>$null)
    if (-not $secretValue) {
        throw "Could not read sandbox API key from Secret Manager secret $SecretId"
    }

    return ($secretValue -join "`n").Trim()
}

function Get-AuthorizationHeaders {
    param([string]$BaseUrl)

    $headers = @{}
    $activeAccount = (& $gcloud config get-value account 2>$null).Trim()
    if ($activeAccount -match "gserviceaccount\.com$") {
        $token = (& $gcloud auth print-identity-token "--audiences=$BaseUrl").Trim()
    } else {
        $token = (& $gcloud auth print-identity-token).Trim()
    }

    if ($token) {
        $headers["Authorization"] = "Bearer $token"
    }

    return $headers
}

function Join-Headers {
    param(
        [hashtable]$BaseHeaders,
        [hashtable]$SpecificHeaders
    )

    $headers = @{}
    foreach ($key in $BaseHeaders.Keys) {
        $headers[$key] = $BaseHeaders[$key]
    }
    foreach ($key in $SpecificHeaders.Keys) {
        $headers[$key] = $SpecificHeaders[$key]
    }
    return $headers
}

function Invoke-KaniJson {
    param(
        [string]$Path,
        [hashtable]$Headers
    )

    $requestHeaders = Join-Headers -BaseHeaders $authorizationHeaders -SpecificHeaders $Headers
    return Invoke-RestMethod -Method Get -Uri "$baseUrl$Path" -Headers $requestHeaders
}

function Invoke-TimedKaniJson {
    param(
        [string]$MetricName,
        [string]$Path,
        [hashtable]$Headers
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-KaniJson -Path $Path -Headers $Headers
    $stopwatch.Stop()
    $summary[$MetricName] = [int][math]::Round($stopwatch.Elapsed.TotalMilliseconds)
    return $response
}

function Measure-LogRows {
    param($Rows)

    if ($null -eq $Rows) {
        return $null
    }

    return @($Rows).Count
}

$gcloud = Get-ToolPath -Name "gcloud" -PreferredPath "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
$kubectl = Get-ToolPath -Name "kubectl"

$startedAt = Get-Date
$collectionId = $startedAt.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$observationRoot = Join-Path $repoRoot $OutputRoot
$sessionDir = Join-Path $observationRoot $collectionId
$rawDir = Join-Path $sessionDir "raw"
$derivedDir = Join-Path $sessionDir "derived"

New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
New-Item -ItemType Directory -Path $derivedDir -Force | Out-Null

$summary = [ordered]@{
    collection_id = $collectionId
    captured_at_utc = $startedAt.ToUniversalTime().ToString("o")
    captured_at_local = $startedAt.ToString("o")
    project_id = $ProjectId
    region = $Region
    zone = $Zone
    cluster_name = $ClusterName
    namespace = $Namespace
    service_name = $ServiceName
    environment = "SANDBOX"
    real_value = $false
    redeemable = $false
    collector_version = "research-observation-v1"
    status = "started"
    errors = @()
    artifacts = [ordered]@{}
}

try {
    $summary.gcloud_account = (Invoke-External -FilePath $gcloud -Arguments @("config", "get-value", "account") -AllowFailure).output.Trim()
    $summary.gcloud_project = (Invoke-External -FilePath $gcloud -Arguments @("config", "get-value", "project") -AllowFailure).output.Trim()

    $runApi = Invoke-GcloudJson -FileName "cloud_run_api.json" -Arguments @("run", "services", "describe", $ServiceName, "--region", $Region, "--project", $ProjectId) -AllowFailure
    $costGuard = Invoke-GcloudJson -FileName "cloud_run_cost_guard.json" -Arguments @("run", "services", "describe", $CostGuardServiceName, "--region", $Region, "--project", $ProjectId) -AllowFailure
    $cloudSql = Invoke-GcloudJson -FileName "cloud_sql_instance.json" -Arguments @("sql", "instances", "describe", $CloudSqlInstance, "--project", $ProjectId) -AllowFailure
    $scheduler = Invoke-GcloudJson -FileName "cloud_scheduler_validator.json" -Arguments @("scheduler", "jobs", "describe", "$NamePrefix-validator-schedule", "--location", $Region, "--project", $ProjectId) -AllowFailure
    $cluster = Invoke-GcloudJson -FileName "gke_cluster.json" -Arguments @("container", "clusters", "describe", $ClusterName, "--zone", $Zone, "--project", $ProjectId) -AllowFailure

    $apiErrorFilter = "resource.type=`"cloud_run_revision`" AND resource.labels.service_name=`"$ServiceName`" AND severity>=ERROR"
    $kaniSystemErrorFilter = "resource.labels.namespace_name=`"$Namespace`" AND severity>=ERROR"
    $cloudSqlErrorFilter = "resource.type=`"cloudsql_database`" AND severity>=ERROR"
    $warningFilter = "severity>=WARNING AND (resource.labels.namespace_name=`"$Namespace`" OR resource.labels.service_name=`"$ServiceName`")"

    $apiErrors = Invoke-GcloudJson -FileName "log_api_errors_24h.json" -Arguments @("logging", "read", $apiErrorFilter, "--project", $ProjectId, "--freshness", "24h", "--limit", "200") -AllowFailure
    $kaniSystemErrors = Invoke-GcloudJson -FileName "log_kani_system_errors_24h.json" -Arguments @("logging", "read", $kaniSystemErrorFilter, "--project", $ProjectId, "--freshness", "24h", "--limit", "200") -AllowFailure
    $cloudSqlErrors = Invoke-GcloudJson -FileName "log_cloud_sql_errors_24h.json" -Arguments @("logging", "read", $cloudSqlErrorFilter, "--project", $ProjectId, "--freshness", "24h", "--limit", "200") -AllowFailure
    $warnings = Invoke-GcloudJson -FileName "log_warnings_24h.json" -Arguments @("logging", "read", $warningFilter, "--project", $ProjectId, "--freshness", "24h", "--limit", "200") -AllowFailure

    $summary.cloud_run_api_url = Get-JsonProperty -Object $runApi.status -Name "url"
    $summary.cloud_run_api_ready_revision = Get-JsonProperty -Object $runApi.status -Name "latestReadyRevisionName"
    $summary.cost_guard_ready_revision = Get-JsonProperty -Object $costGuard.status -Name "latestReadyRevisionName"
    $summary.cloud_sql_state = Get-JsonProperty -Object $cloudSql -Name "state"
    $summary.cloud_sql_database_version = Get-JsonProperty -Object $cloudSql -Name "databaseVersion"
    $summary.cloud_sql_tier = Get-JsonProperty -Object $cloudSql.settings -Name "tier"
    $summary.cloud_sql_backups_enabled = Get-JsonProperty -Object $cloudSql.settings.backupConfiguration -Name "enabled"
    $summary.cloud_sql_pitr_enabled = Get-JsonProperty -Object $cloudSql.settings.backupConfiguration -Name "pointInTimeRecoveryEnabled"
    $summary.scheduler_state = Get-JsonProperty -Object $scheduler -Name "state"
    $summary.gke_cluster_status = Get-JsonProperty -Object $cluster -Name "status"
    $summary.gke_current_master_version = Get-JsonProperty -Object $cluster -Name "currentMasterVersion"
    $summary.gke_current_node_version = Get-JsonProperty -Object $cluster -Name "currentNodeVersion"
    $summary.api_error_count_24h = Measure-LogRows $apiErrors
    $summary.kani_system_error_count_24h = Measure-LogRows $kaniSystemErrors
    $summary.cloud_sql_error_count_24h = Measure-LogRows $cloudSqlErrors
    $summary.warning_count_24h = Measure-LogRows $warnings

    if (-not $SkipKubectl) {
        Invoke-GcloudText -FileName "gke_get_credentials.txt" -Arguments @("container", "clusters", "get-credentials", $ClusterName, "--zone", $Zone, "--project", $ProjectId) -AllowFailure | Out-Null
        $pods = Invoke-KubectlJson -FileName "kubectl_pods.json" -Arguments @("get", "pods", "-n", $Namespace) -AllowFailure
        $deployments = Invoke-KubectlJson -FileName "kubectl_deployments.json" -Arguments @("get", "deployments", "-n", $Namespace) -AllowFailure
        $nodes = Invoke-KubectlJson -FileName "kubectl_nodes.json" -Arguments @("get", "nodes") -AllowFailure
        $events = Invoke-KubectlJson -FileName "kubectl_events.json" -Arguments @("get", "events", "-n", $Namespace, "--sort-by=.lastTimestamp") -AllowFailure
        Invoke-KubectlText -FileName "kubectl_top_pods.txt" -Arguments @("top", "pods", "-n", $Namespace) -AllowFailure | Out-Null
        Invoke-KubectlText -FileName "kubectl_top_nodes.txt" -Arguments @("top", "nodes") -AllowFailure | Out-Null
        Invoke-KubectlText -FileName "kubectl_validator_logs_24h.txt" -Arguments @("logs", "-n", $Namespace, "-l", "app.kubernetes.io/name=kani-validator", "--all-containers=true", "--since=24h", "--tail=500", "--prefix") -AllowFailure | Out-Null

        $validatorPods = @($pods.items | Where-Object { $_.metadata.name -match "^validator-" })
        $podRows = @()
        $restartTotal = 0
        $containersReady = 0
        $containersTotal = 0

        foreach ($pod in $validatorPods) {
            $statuses = @($pod.status.containerStatuses)
            $readyForPod = @($statuses | Where-Object { $_.ready }).Count
            $totalForPod = $statuses.Count
            $restartForPod = 0
            foreach ($container in $statuses) {
                $restartForPod += [int]$container.restartCount
            }

            $containersReady += $readyForPod
            $containersTotal += $totalForPod
            $restartTotal += $restartForPod

            $podRows += [pscustomobject]@{
                name = $pod.metadata.name
                phase = $pod.status.phase
                ready_containers = $readyForPod
                total_containers = $totalForPod
                restarts = $restartForPod
                node = $pod.spec.nodeName
                started_at = $pod.status.startTime
            }
        }

        Write-JsonFile -Path (Join-Path $derivedDir "validator_pods_summary.json") -Value $podRows

        $summary.validator_pods_total = $validatorPods.Count
        $summary.validator_pods_running = @($validatorPods | Where-Object { $_.status.phase -eq "Running" }).Count
        $summary.validator_containers_ready = $containersReady
        $summary.validator_containers_total = $containersTotal
        $summary.validator_restarts_total = $restartTotal
        $summary.gke_node_count = @($nodes.items).Count
        $summary.kubernetes_event_count = @($events.items).Count
        $summary.gke_deployment_count = @($deployments.items).Count
    }

    $baseUrl = $summary.cloud_run_api_url
    if (-not $baseUrl) {
        $baseUrl = (& $gcloud run services describe $ServiceName --region $Region --project $ProjectId --format "value(status.url)").Trim()
        $summary.cloud_run_api_url = $baseUrl
    }

    if ($baseUrl) {
        $authorizationHeaders = Get-AuthorizationHeaders -BaseUrl $baseUrl
        $adminApiKey = Get-SandboxApiKey -SecretId "$NamePrefix-admin-api-key"
        $corpAApiKey = Get-SandboxApiKey -SecretId "$NamePrefix-corp-a-api-key"
        $corpBApiKey = Get-SandboxApiKey -SecretId "$NamePrefix-corp-b-api-key"
        $adminHeaders = @{
            "x-kani-institution-id" = "KANI_ADMIN"
            "x-kani-api-key" = $adminApiKey
        }
        $corpAHeaders = @{
            "x-kani-institution-id" = "CORP_A"
            "x-kani-api-key" = $corpAApiKey
        }
        $corpBHeaders = @{
            "x-kani-institution-id" = "CORP_B"
            "x-kani-api-key" = $corpBApiKey
        }

        $health = Invoke-TimedKaniJson -MetricName "latency_health_ms" -Path "/health" -Headers @{}
        $latestBlock = Invoke-TimedKaniJson -MetricName "latency_admin_latest_block_ms" -Path "/v1/blocks/latest" -Headers $adminHeaders
        $pending = Invoke-TimedKaniJson -MetricName "latency_admin_pending_ms" -Path "/v1/transactions/pending?limit=100&offset=0" -Headers $adminHeaders
        $validators = Invoke-TimedKaniJson -MetricName "latency_admin_validators_ms" -Path "/v1/validators" -Headers $adminHeaders
        $accounts = Invoke-TimedKaniJson -MetricName "latency_admin_accounts_ms" -Path "/v1/accounts" -Headers $adminHeaders
        $settlementReport = Invoke-TimedKaniJson -MetricName "latency_admin_settlement_report_ms" -Path "/v1/reports/settlement-summary?limit=500&offset=0" -Headers $adminHeaders
        $complianceReport = Invoke-TimedKaniJson -MetricName "latency_admin_compliance_report_ms" -Path "/v1/reports/compliance-decisions?limit=500&offset=0" -Headers $adminHeaders
        $validatorReport = Invoke-TimedKaniJson -MetricName "latency_admin_validator_report_ms" -Path "/v1/reports/validator-finality?limit=500&offset=0" -Headers $adminHeaders

        Write-JsonFile -Path (Join-Path $rawDir "api_health.json") -Value $health
        Write-JsonFile -Path (Join-Path $rawDir "api_latest_block.json") -Value $latestBlock
        Write-JsonFile -Path (Join-Path $rawDir "api_pending_transactions.json") -Value $pending
        Write-JsonFile -Path (Join-Path $rawDir "api_validators.json") -Value $validators
        Write-JsonFile -Path (Join-Path $rawDir "api_accounts.json") -Value $accounts
        Write-JsonFile -Path (Join-Path $rawDir "api_settlement_report.json") -Value $settlementReport
        Write-JsonFile -Path (Join-Path $rawDir "api_compliance_report.json") -Value $complianceReport
        Write-JsonFile -Path (Join-Path $rawDir "api_validator_finality_report.json") -Value $validatorReport

        $summary.api_health = $health.status
        $summary.latest_block_height = $latestBlock.height
        $summary.latest_block_validator = $latestBlock.validator
        $summary.latest_block_finality_votes = @($latestBlock.finalized_by).Count
        $summary.pending_count = $pending.count
        $summary.api_validator_count = @($validators).Count
        $summary.api_validator_heartbeat_count = @($validators | Where-Object { $null -ne $_.last_seen_at }).Count
        $summary.api_validator_finalized_count = @($validators | Where-Object { $null -ne $_.last_finalized_height }).Count
        $summary.account_count = @($accounts).Count
        $summary.settlement_report_transactions = $settlementReport.transaction_count
        $summary.compliance_report_events = $complianceReport.event_count
        $summary.validator_report_finalized_blocks = $validatorReport.finalized_block_count
        $summary.validator_required_finality_votes = $validatorReport.required_finality_votes
        $summary.institution_latency_paths_recorded = "KANI_ADMIN"
    }

    if ($RunSmoke) {
        try {
            $smokeScript = Join-Path $PSScriptRoot "phase2-cloud-smoke.ps1"
            $smokeStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $smoke = & $smokeScript -ProjectId $ProjectId -Region $Region -NamePrefix $NamePrefix -ServiceName $ServiceName -SkipValidatorJob -WaitForContinuousValidators
            $smokeStopwatch.Stop()
            Write-JsonFile -Path (Join-Path $rawDir "daily_smoke_result.json") -Value $smoke
            $summary.smoke_status = $smoke.status
            $summary.smoke_duration_ms = [int][math]::Round($smokeStopwatch.Elapsed.TotalMilliseconds)
            $summary.smoke_asset = $smoke.asset
            $summary.smoke_latest_block_height = $smoke.latest_block_height
            $summary.smoke_pending_count = $smoke.pending_count
            $summary.smoke_iso_status = $smoke.iso_status

            if ($baseUrl -and $corpAHeaders -and $corpBHeaders -and $adminHeaders) {
                $corpABalance = Invoke-TimedKaniJson -MetricName "latency_corp_a_balance_ms" -Path "/v1/accounts/CORP_A/balances/$($smoke.asset)" -Headers $corpAHeaders
                $corpBBalance = Invoke-TimedKaniJson -MetricName "latency_corp_b_balance_ms" -Path "/v1/accounts/CORP_B/balances/$($smoke.asset)" -Headers $corpBHeaders
                $postSmokeLatestBlock = Invoke-TimedKaniJson -MetricName "latency_admin_post_smoke_latest_block_ms" -Path "/v1/blocks/latest" -Headers $adminHeaders
                $postSmokePending = Invoke-TimedKaniJson -MetricName "latency_admin_post_smoke_pending_ms" -Path "/v1/transactions/pending?limit=100&offset=0" -Headers $adminHeaders

                Write-JsonFile -Path (Join-Path $rawDir "post_smoke_corp_a_balance.json") -Value $corpABalance
                Write-JsonFile -Path (Join-Path $rawDir "post_smoke_corp_b_balance.json") -Value $corpBBalance
                Write-JsonFile -Path (Join-Path $rawDir "post_smoke_latest_block.json") -Value $postSmokeLatestBlock
                Write-JsonFile -Path (Join-Path $rawDir "post_smoke_pending_transactions.json") -Value $postSmokePending

                $summary.corp_a_smoke_asset_balance = $corpABalance.amount
                $summary.corp_b_smoke_asset_balance = $corpBBalance.amount
                $summary.latest_block_height = $postSmokeLatestBlock.height
                $summary.latest_block_validator = $postSmokeLatestBlock.validator
                $summary.latest_block_finality_votes = @($postSmokeLatestBlock.finalized_by).Count
                $summary.pending_count = $postSmokePending.count
                $summary.institution_latency_paths_recorded = "KANI_ADMIN,CORP_A,CORP_B"
            }
        } catch {
            $summary.smoke_status = "failed"
            $summary.errors += "Daily smoke test failed: $($_.Exception.Message)"
            Write-TextFile -Path (Join-Path $rawDir "daily_smoke_error.txt") -Value "$($_.Exception.Message)"
        }
    } else {
        $summary.smoke_status = "skipped"
    }

    if (@($summary.errors).Count -eq 0) {
        $summary.status = "ok"
    } else {
        $summary.status = "warning"
    }
} catch {
    $summary.status = "failed"
    $summary.errors += $_.Exception.Message
} finally {
    $summary.completed_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    $summary.artifacts.session_dir = $sessionDir
    $summary.artifacts.raw_dir = $rawDir
    $summary.artifacts.derived_dir = $derivedDir

    Write-JsonFile -Path (Join-Path $derivedDir "observation-summary.json") -Value $summary

    $csvPath = Join-Path $observationRoot "kani_research_daily_observations.csv"
    $csvRow = [pscustomobject]@{
        collection_id = $summary.collection_id
        captured_at_utc = $summary.captured_at_utc
        project_id = $summary.project_id
        api_health = $summary.api_health
        cloud_run_ready_revision = $summary.cloud_run_api_ready_revision
        cloud_sql_state = $summary.cloud_sql_state
        gke_cluster_status = $summary.gke_cluster_status
        gke_node_count = $summary.gke_node_count
        validator_pods_total = $summary.validator_pods_total
        validator_pods_running = $summary.validator_pods_running
        validator_containers_ready = $summary.validator_containers_ready
        validator_containers_total = $summary.validator_containers_total
        validator_restarts_total = $summary.validator_restarts_total
        latest_block_height = $summary.latest_block_height
        latest_block_validator = $summary.latest_block_validator
        latest_block_finality_votes = $summary.latest_block_finality_votes
        pending_count = $summary.pending_count
        settlement_report_transactions = $summary.settlement_report_transactions
        compliance_report_events = $summary.compliance_report_events
        validator_report_finalized_blocks = $summary.validator_report_finalized_blocks
        latency_health_ms = $summary.latency_health_ms
        latency_admin_latest_block_ms = $summary.latency_admin_latest_block_ms
        latency_admin_pending_ms = $summary.latency_admin_pending_ms
        latency_admin_settlement_report_ms = $summary.latency_admin_settlement_report_ms
        latency_admin_validator_report_ms = $summary.latency_admin_validator_report_ms
        latency_corp_a_balance_ms = $summary.latency_corp_a_balance_ms
        latency_corp_b_balance_ms = $summary.latency_corp_b_balance_ms
        latency_admin_post_smoke_latest_block_ms = $summary.latency_admin_post_smoke_latest_block_ms
        smoke_duration_ms = $summary.smoke_duration_ms
        institution_latency_paths_recorded = $summary.institution_latency_paths_recorded
        api_error_count_24h = $summary.api_error_count_24h
        kani_system_error_count_24h = $summary.kani_system_error_count_24h
        cloud_sql_error_count_24h = $summary.cloud_sql_error_count_24h
        warning_count_24h = $summary.warning_count_24h
        smoke_status = $summary.smoke_status
        smoke_asset = $summary.smoke_asset
        smoke_latest_block_height = $summary.smoke_latest_block_height
        smoke_pending_count = $summary.smoke_pending_count
        status = $summary.status
        observation_dir = $sessionDir
    }

    $csvColumns = @($csvRow.PSObject.Properties.Name)
    if (Test-Path $csvPath) {
        $existingRows = @(Import-Csv $csvPath)
        if ($existingRows.Count -gt 0) {
            $existingColumns = @($existingRows[0].PSObject.Properties.Name)
            $missingColumns = @($csvColumns | Where-Object { $existingColumns -notcontains $_ })
            if ($missingColumns.Count -gt 0) {
                $migratedRows = foreach ($row in $existingRows) {
                    $ordered = [ordered]@{}
                    foreach ($column in $csvColumns) {
                        $property = $row.PSObject.Properties[$column]
                        if ($property) {
                            $ordered[$column] = $property.Value
                        } else {
                            $ordered[$column] = ""
                        }
                    }
                    [pscustomobject]$ordered
                }
                $migratedRows | Export-Csv -Path $csvPath -NoTypeInformation
            }
        }
        $csvRow | Export-Csv -Path $csvPath -NoTypeInformation -Append
    } else {
        $csvRow | Export-Csv -Path $csvPath -NoTypeInformation
    }

    if ($GenerateSummary) {
        & (Join-Path $PSScriptRoot "research-summarize-observations.ps1") -WindowDays 21 | Out-Host
    }

    $summary
}
