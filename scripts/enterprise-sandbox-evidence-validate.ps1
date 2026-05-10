$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "docs/research/KANI_ENTERPRISE_SANDBOX_READINESS_REPORT.md",
    "docs/research/data/enterprise_readiness_controls.csv",
    "docs/research/data/enterprise_readiness_metrics.csv",
    "docs/research/data/enterprise_evidence_index.csv",
    "docs/research/data/enterprise_readiness_summary.yaml",
    "docs/presentations/kani_enterprise_sandbox_proof_deck.pptx",
    "docs/presentations/kani_enterprise_sandbox_proof_deck_montage.png"
)

foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
        throw "Missing enterprise sandbox evidence file: $path"
    }
}

$report = Get-Content "docs/research/KANI_ENTERPRISE_SANDBOX_READINESS_REPORT.md" -Raw
$summary = Get-Content "docs/research/data/enterprise_readiness_summary.yaml" -Raw
$controls = Import-Csv "docs/research/data/enterprise_readiness_controls.csv"
$metrics = Import-Csv "docs/research/data/enterprise_readiness_metrics.csv"
$evidence = Import-Csv "docs/research/data/enterprise_evidence_index.csv"

$reportExpectations = @(
    "enterprise-sandbox-evidence-pack-rc1",
    "sandbox_enterprise_readiness_evidence_pack_ready",
    "Enterprise-ready sandbox evidence pack: ready for review",
    "Production-ready settlement network: not yet",
    "Real-value settlement: disabled",
    "latest_block_height: 42",
    "pending_count: 0",
    "KCAD_TEST_20260510021545"
)

foreach ($expected in $reportExpectations) {
    if ($report -notmatch [regex]::Escape($expected)) {
        throw "Enterprise readiness report missing expected phrase: $expected"
    }
}

$summaryExpectations = @(
    "sandbox_mvp: implemented_and_running",
    "enterprise_ready_sandbox_evidence_pack: ready_for_review",
    "production_ready_network: false",
    "real_value_settlement: false",
    "validator_pods_running: 3",
    "validator_restarts: 0",
    "legacy_scheduler_state: PAUSED",
    "budget_guardrail_cad: 200",
    "latest_block_height: 42",
    "pending_count: 0"
)

foreach ($expected in $summaryExpectations) {
    if ($summary -notmatch [regex]::Escape($expected)) {
        throw "Enterprise readiness summary missing expected phrase: $expected"
    }
}

if ($controls.Count -lt 18) {
    throw "Expected at least 18 enterprise control rows, found $($controls.Count)"
}

if ($metrics.Count -lt 20) {
    throw "Expected at least 20 enterprise metric rows, found $($metrics.Count)"
}

if ($evidence.Count -lt 10) {
    throw "Expected at least 10 evidence index rows, found $($evidence.Count)"
}

$previewCount = @(Get-ChildItem "docs/presentations/kani_enterprise_sandbox_proof_deck_previews/slide-*.png").Count
$layoutCount = @(Get-ChildItem "docs/presentations/kani_enterprise_sandbox_proof_deck_layouts/slide-*.layout.json").Count
$parityCount = @(Get-ChildItem "docs/presentations/kani_enterprise_sandbox_proof_deck_pptx_parity/slide-*.png").Count

if ($previewCount -ne 12) {
    throw "Expected 12 rendered deck preview PNGs, found $previewCount"
}

if ($layoutCount -ne 12) {
    throw "Expected 12 deck layout JSON files, found $layoutCount"
}

if ($parityCount -ne 12) {
    throw "Expected 12 saved-PPTX parity PNGs, found $parityCount"
}

$requiredControls = @(
    "Sandbox boundary",
    "Ledger integrity",
    "Validator finality",
    "GKE runtime",
    "Budget guardrail",
    "Real-value settlement"
)

foreach ($domain in $requiredControls) {
    if (-not ($controls | Where-Object { $_.domain -eq $domain })) {
        throw "Missing enterprise control domain: $domain"
    }
}

$blockedRealValue = $controls | Where-Object { $_.domain -eq "Real-value settlement" -and $_.status -eq "blocked" }
if (-not $blockedRealValue) {
    throw "Real-value settlement must remain blocked in enterprise sandbox evidence"
}

$metricMap = @{}
foreach ($metric in $metrics) {
    $metricMap[$metric.metric] = $metric.value
}

if ($metricMap["latest_block_height"] -ne "42") {
    throw "Expected latest_block_height metric to be 42"
}

if ($metricMap["pending_count"] -ne "0") {
    throw "Expected pending_count metric to be 0"
}

if ($metricMap["validator_restarts"] -ne "0") {
    throw "Expected validator_restarts metric to be 0"
}

foreach ($forbidden in @(
    "real_value: true",
    "redeemable: true",
    "production_authorization_enabled: true",
    "external_institution_onboarding_enabled: true",
    "fiat_deposit_redemption_enabled: true"
)) {
    if ($summary -match [regex]::Escape($forbidden)) {
        throw "Enterprise sandbox summary must not enable forbidden boundary: $forbidden"
    }
}

[pscustomobject]@{
    package = "kani-enterprise-sandbox-evidence-pack"
    release_candidate = "enterprise-sandbox-evidence-pack-rc1"
    status = "ok"
    controls = $controls.Count
    metrics = $metrics.Count
    evidence_items = $evidence.Count
    deck_preview_pngs = $previewCount
    deck_layout_json = $layoutCount
    deck_pptx_parity_pngs = $parityCount
    latest_block_height = $metricMap["latest_block_height"]
    pending_count = $metricMap["pending_count"]
    real_value_settlement = "blocked"
}
