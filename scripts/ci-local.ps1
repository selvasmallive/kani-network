param(
  [string]$DatabaseUrl = "postgres://kani:kani@localhost:5432/kani",
  [string]$DockerTag = "kani-api:ci",
  [switch]$Clean,
  [switch]$SkipPostgresIntegration,
  [switch]$SkipDockerBuild,
  [switch]$RunSmoke
)

$ErrorActionPreference = "Stop"

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoRoot = Split-Path -Parent $scriptRoot

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

Push-Location $repoRoot
try {
  if ($Clean) {
    Invoke-KaniNative cargo @("clean")
  }

  Invoke-KaniNative cargo @("fmt", "--check")
  Invoke-KaniNative cargo @("test", "--workspace")

  if (-not $SkipPostgresIntegration) {
    Invoke-KaniNative docker @("compose", "up", "-d", "postgres")
    $env:KANI_TEST_DATABASE_URL = $DatabaseUrl
    Invoke-KaniNative cargo @("test", "-p", "kani-api", "--test", "postgres_api", "--", "--nocapture")
  }

  Invoke-KaniNative cargo @("clippy", "--workspace", "--", "-D", "warnings")

  if (-not $SkipDockerBuild) {
    Invoke-KaniNative docker @("build", "--file", "docker/Dockerfile.api", "--tag", $DockerTag, ".")
  }

  if ($RunSmoke) {
    & (Join-Path $scriptRoot "smoke-test.ps1")
  }
} finally {
  Pop-Location
}
