param(
  [string]$DatabaseUrl = "postgres://kani:kani@localhost:5432/kani",
  [string]$DockerTag = "kani-api:ci",
  [switch]$SkipPostgresIntegration,
  [switch]$SkipDockerBuild,
  [switch]$RunSmoke
)

$ErrorActionPreference = "Stop"

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoRoot = Split-Path -Parent $scriptRoot

Push-Location $repoRoot
try {
  cargo fmt --check
  cargo test --workspace

  if (-not $SkipPostgresIntegration) {
    docker compose up -d postgres
    $env:KANI_TEST_DATABASE_URL = $DatabaseUrl
    cargo test -p kani-api --test postgres_api -- --nocapture
  }

  cargo clippy --workspace -- -D warnings

  if (-not $SkipDockerBuild) {
    docker build --file docker/Dockerfile.api --tag $DockerTag .
  }

  if ($RunSmoke) {
    & (Join-Path $scriptRoot "smoke-test.ps1")
  }
} finally {
  Pop-Location
}
