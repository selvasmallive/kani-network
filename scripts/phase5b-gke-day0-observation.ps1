$ErrorActionPreference = "Stop"

$docPath = "PHASE5B_GKE_DAY0_OBSERVATION.md"
$configPath = "config/phase5b-gke-day0-observation.yaml"

foreach ($path in @($docPath, $configPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing Phase 5B GKE day-zero observation artifact: $path"
    }
}

$doc = Get-Content $docPath -Raw
$config = Get-Content $configPath -Raw

$expectedDoc = @(
    "phase5b-gke-day0-observation-rc1",
    "day_zero_observation_recorded",
    "2026-05-10",
    "2026-06-10",
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "kani-sandbox-monthly-budget",
    "CAD",
    "amount: 200",
    "validator-a-5d9c6d7669-74mbn: 2/2 Running, 0 restarts",
    "validator-b-5ffbf579d5-lf9ch: 2/2 Running, 0 restarts",
    "validator-c-845b96c77c-xzsbm: 2/2 Running, 0 restarts",
    "KCAD_TEST_20260510021545",
    "latest_block_height: 42",
    "pending_count: 0",
    "result: no rows",
    "watch item rather than a release blocker"
)

foreach ($expected in $expectedDoc) {
    if ($doc -notmatch [regex]::Escape($expected)) {
        throw "Expected day-zero observation report to include: $expected"
    }
}

$expectedConfig = @(
    "release_candidate: phase5b-gke-day0-observation-rc1",
    "status: day_zero_observation_recorded",
    "start: 2026-05-10",
    "end: 2026-06-10",
    "env: SANDBOX",
    "real_value: false",
    "redeemable: false",
    "production_value_movement_allowed: false",
    "amount_units: 200",
    "hard_cap: false",
    "alerting_guardrail_only: true",
    "node_machine_type: e2-medium",
    "job_name: kani-sandbox-validator-schedule",
    "state: PAUSED",
    "profile: phase5b-gke-continuous-validators",
    "latest_block_height: 42",
    "pending_count: 0",
    "result: no_rows",
    "classification: watch_item_not_release_blocker",
    "default_teardown_after_window: true"
)

foreach ($expected in $expectedConfig) {
    if ($config -notmatch [regex]::Escape($expected)) {
        throw "Expected day-zero observation config to include: $expected"
    }
}

foreach ($forbidden in @(
    "real_value: true",
    "redeemable: true",
    "production_value_movement_allowed: true",
    "external_institution_onboarding_enabled: true",
    "fiat_deposit_redemption_enabled: true",
    "hard_cap: true"
)) {
    if ($config -match [regex]::Escape($forbidden)) {
        throw "Day-zero observation config must not enable forbidden boundary: $forbidden"
    }
}

[pscustomobject]@{
    phase = "phase-5b-gke-day0-observation"
    release_candidate = "phase5b-gke-day0-observation-rc1"
    status = "ok"
    observation_window = "2026-05-10 through 2026-06-10"
    budget_guardrail_cad = 200
    validators_ready = 3
    smoke_latest_block_height = 42
    pending_count = 0
    kani_system_errors = 0
    gke_system_watch_item_recorded = $true
    environment = "SANDBOX"
    real_value = $false
    redeemable = $false
}
