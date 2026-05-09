param(
    [string]$ProjectId = "kani-network-sandbox",
    [string]$Region = "northamerica-northeast1",
    [string]$NamePrefix = "kani-sandbox",
    [string]$ServiceName = "kani-sandbox-api",
    [string]$CostGuardServiceName = "kani-sandbox-cost-guard",
    [string]$ValidatorJob = "kani-sandbox-validator",
    [string]$BaseUrl = "",
    [switch]$SkipIdentityToken
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

    throw "Could not find gcloud"
}

function ConvertFrom-GcloudJson {
    param([string[]]$Lines)

    $json = ($Lines -join "`n").Trim()
    if (-not $json) {
        return $null
    }

    return $json | ConvertFrom-Json
}

function Get-Bindings {
    param($Policy)

    if ($Policy -and $Policy.bindings) {
        return @($Policy.bindings)
    }

    return @()
}

function Assert-NoPublicMembers {
    param(
        $Policy,
        [string]$Resource
    )

    foreach ($binding in Get-Bindings $Policy) {
        foreach ($member in @($binding.members)) {
            if ($member -eq "allUsers" -or $member -eq "allAuthenticatedUsers") {
                throw "$Resource grants $($binding.role) to public member $member"
            }
        }
    }
}

function Get-PropertyValue {
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

function Get-ServiceContainers {
    param($Service)

    $template = Get-PropertyValue $Service "template"
    $containers = Get-PropertyValue $template "containers"
    if ($null -ne $containers) {
        return @($containers)
    }

    $spec = Get-PropertyValue $Service "spec"
    $specTemplate = Get-PropertyValue $spec "template"
    $templateSpec = Get-PropertyValue $specTemplate "spec"
    $containers = Get-PropertyValue $templateSpec "containers"
    if ($null -ne $containers) {
        return @($containers)
    }

    throw "Could not read Cloud Run service containers"
}

function Get-ServiceIngress {
    param($Service)

    $ingress = Get-PropertyValue $Service "ingress"
    if ($ingress) {
        return $ingress
    }

    $metadata = Get-PropertyValue $Service "metadata"
    $annotations = Get-PropertyValue $metadata "annotations"
    $annotation = Get-PropertyValue $annotations "run.googleapis.com/ingress"
    if ($annotation) {
        return $annotation
    }

    return ""
}

function Get-ServiceAccountName {
    param($Service)

    $template = Get-PropertyValue $Service "template"
    $serviceAccount = Get-PropertyValue $template "serviceAccount"
    if ($serviceAccount) {
        return $serviceAccount
    }

    $spec = Get-PropertyValue $Service "spec"
    $specTemplate = Get-PropertyValue $spec "template"
    $templateSpec = Get-PropertyValue $specTemplate "spec"
    $serviceAccount = Get-PropertyValue $templateSpec "serviceAccountName"
    if ($serviceAccount) {
        return $serviceAccount
    }

    return ""
}

function Get-EnvByName {
    param($Service)

    $containers = @(Get-ServiceContainers $Service)
    if ($containers.Count -lt 1) {
        throw "Cloud Run service has no containers"
    }

    $envByName = @{}
    foreach ($env in @($containers[0].env)) {
        $envByName[$env.name] = $env
    }

    return $envByName
}

function Assert-SecretBackedEnv {
    param(
        [hashtable]$EnvByName,
        [string]$Name
    )

    if (-not $EnvByName.ContainsKey($Name)) {
        throw "Missing required secret-backed env var $Name"
    }

    $env = $EnvByName[$Name]
    $secretName = $null
    $valueSource = Get-PropertyValue $env "valueSource"
    $valueSourceSecretRef = Get-PropertyValue $valueSource "secretKeyRef"
    if ($valueSourceSecretRef) {
        $secretName = Get-PropertyValue $valueSourceSecretRef "secret"
    }

    $valueFrom = Get-PropertyValue $env "valueFrom"
    $valueFromSecretRef = Get-PropertyValue $valueFrom "secretKeyRef"
    if ($valueFromSecretRef) {
        $secretName = Get-PropertyValue $valueFromSecretRef "name"
    }

    if (-not $secretName) {
        throw "Expected $Name to be backed by Secret Manager, but it has a literal value"
    }
}

function Invoke-ExpectedHttpError {
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [int[]]$ExpectedStatuses
    )

    try {
        Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Uri -Headers $Headers | Out-Null
        throw "Expected HTTP error from $Uri"
    } catch {
        $response = $_.Exception.Response
        if (-not $response) {
            throw
        }

        $statusCode = [int]$response.StatusCode
        if ($ExpectedStatuses -notcontains $statusCode) {
            throw "Expected HTTP $($ExpectedStatuses -join '/') from $Uri, got $statusCode"
        }

        return $statusCode
    }
}

$gcloud = Get-Gcloud

if (-not $BaseUrl) {
    $BaseUrl = (& $gcloud run services describe $ServiceName --region $Region --project $ProjectId --format "value(status.url)").Trim()
}
if (-not $BaseUrl) {
    throw "Could not resolve Cloud Run service URL for $ServiceName"
}

$apiService = ConvertFrom-GcloudJson (& $gcloud run services describe $ServiceName --region $Region --project $ProjectId --format json)
$costGuardService = ConvertFrom-GcloudJson (& $gcloud run services describe $CostGuardServiceName --region $Region --project $ProjectId --format json)
$apiPolicy = ConvertFrom-GcloudJson (& $gcloud run services get-iam-policy $ServiceName --region $Region --project $ProjectId --format json)
$costGuardPolicy = ConvertFrom-GcloudJson (& $gcloud run services get-iam-policy $CostGuardServiceName --region $Region --project $ProjectId --format json)
$validatorPolicy = ConvertFrom-GcloudJson (& $gcloud run jobs get-iam-policy $ValidatorJob --region $Region --project $ProjectId --format json)

Assert-NoPublicMembers -Policy $apiPolicy -Resource "Cloud Run service $ServiceName"
Assert-NoPublicMembers -Policy $costGuardPolicy -Resource "Cloud Run service $CostGuardServiceName"
Assert-NoPublicMembers -Policy $validatorPolicy -Resource "Cloud Run job $ValidatorJob"

$apiIngress = Get-ServiceIngress $apiService
if ($apiIngress -notin @("all", "INGRESS_TRAFFIC_ALL")) {
    throw "Expected $ServiceName ingress to allow direct sandbox testing, got $apiIngress"
}

$apiServiceAccount = Get-ServiceAccountName $apiService
$expectedApiServiceAccount = "$NamePrefix-api@$ProjectId.iam.gserviceaccount.com"
if ($apiServiceAccount -ne $expectedApiServiceAccount) {
    throw "Expected $ServiceName to run as $expectedApiServiceAccount, got $apiServiceAccount"
}

$envByName = Get-EnvByName $apiService
if (-not $envByName.ContainsKey("KANI_REQUIRE_CONFIGURED_SANDBOX_API_KEYS") -or $envByName["KANI_REQUIRE_CONFIGURED_SANDBOX_API_KEYS"].value -ne "TRUE") {
    throw "Expected KANI_REQUIRE_CONFIGURED_SANDBOX_API_KEYS=TRUE on $ServiceName"
}

foreach ($envName in @(
    "DATABASE_URL",
    "KANI_SANDBOX_TREASURY_API_KEY",
    "KANI_SANDBOX_CORP_A_API_KEY",
    "KANI_SANDBOX_CORP_B_API_KEY",
    "KANI_SANDBOX_ADMIN_API_KEY"
)) {
    Assert-SecretBackedEnv -EnvByName $envByName -Name $envName
}

foreach ($secretId in @(
    "$NamePrefix-database-url",
    "$NamePrefix-treasury-api-key",
    "$NamePrefix-corp-a-api-key",
    "$NamePrefix-corp-b-api-key",
    "$NamePrefix-admin-api-key"
)) {
    $secretPolicy = ConvertFrom-GcloudJson (& $gcloud secrets get-iam-policy $secretId --project $ProjectId --format json)
    Assert-NoPublicMembers -Policy $secretPolicy -Resource "Secret Manager secret $secretId"
}

$unauthenticatedStatus = Invoke-ExpectedHttpError -Uri "$BaseUrl/health" -Headers @{} -ExpectedStatuses @(401, 403)

$invalidCredentialStatus = $null
if (-not $SkipIdentityToken) {
    $activeAccount = (& $gcloud config get-value account 2>$null).Trim()
    if ($activeAccount -match "gserviceaccount\.com$") {
        $token = (& $gcloud auth print-identity-token "--audiences=$BaseUrl").Trim()
    } else {
        $token = (& $gcloud auth print-identity-token).Trim()
    }

    if ($token) {
        $invalidCredentialStatus = Invoke-ExpectedHttpError -Uri "$BaseUrl/v1/accounts" -Headers @{
            "Authorization" = "Bearer $token"
            "x-kani-institution-id" = "KANI_ADMIN"
            "x-kani-api-key" = "invalid-sandbox-api-key"
        } -ExpectedStatuses @(401)
    }
}

[pscustomobject]@{
    profile = "phase2-security-hardening"
    base_url = $BaseUrl
    api_ingress = $apiIngress
    api_service_account = $apiServiceAccount
    api_public_invoker_absent = $true
    cost_guard_public_invoker_absent = $true
    validator_job_public_invoker_absent = $true
    secret_public_access_absent = $true
    secret_backed_api_env_verified = $true
    unauthenticated_health_denied_status = $unauthenticatedStatus
    invalid_sandbox_key_denied_status = $invalidCredentialStatus
    status = "ok"
}
