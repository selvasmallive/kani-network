$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "docs/patent/README.md",
    "docs/patent/PROVISIONAL_SPECIFICATION_DRAFT.md",
    "docs/patent/FIGURES.md",
    "docs/patent/SANDBOX_MVP_EVIDENCE_APPENDIX.md",
    "docs/patent/USPTO_FILING_WORKSHEET.md"
)

foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
        throw "Missing patent package file: $path"
    }
}

$spec = Get-Content "docs/patent/PROVISIONAL_SPECIFICATION_DRAFT.md" -Raw
$figures = Get-Content "docs/patent/FIGURES.md" -Raw
$evidence = Get-Content "docs/patent/SANDBOX_MVP_EVIDENCE_APPENDIX.md" -Raw
$worksheet = Get-Content "docs/patent/USPTO_FILING_WORKSHEET.md" -Raw

$specExpectations = @(
    "Permissioned Tokenized-Fiat Settlement Network",
    "Field",
    "Background",
    "Summary",
    "Detailed Description",
    "Ledger Model",
    "Validator And Finality Runtime",
    "Crypto-Agile Profile Selection",
    "Compliance-Gated Settlement",
    "ISO 20022 Translation",
    "Cloud-Native Deployment",
    "Sandbox MVP Implementation Results",
    "Optional Claim-Style Concepts For Counsel",
    "Abstract Draft"
)

foreach ($expected in $specExpectations) {
    if ($spec -notmatch [regex]::Escape($expected)) {
        throw "Specification missing expected section or phrase: $expected"
    }
}

foreach ($figure in 1..8) {
    if ($figures -notmatch "Figure $figure") {
        throw "Figures file missing Figure $figure"
    }
}

$evidenceExpectations = @(
    "ENV = SANDBOX",
    "REAL_VALUE = FALSE",
    "REDEEMABLE = FALSE",
    "KCAD_TEST_20260510021545",
    "latest_block_height: 42",
    "pending_count: 0",
    "validator-a-5d9c6d7669-74mbn: 2/2 Running, 0 restarts",
    "terraform infra/terraform plan: no changes",
    "No real money"
)

foreach ($expected in $evidenceExpectations) {
    if ($evidence -notmatch [regex]::Escape($expected)) {
        throw "Evidence appendix missing expected result: $expected"
    }
}

$worksheetExpectations = @(
    "USPTO Provisional Filing Worksheet",
    "not an official USPTO form",
    "12-month",
    "Cover Sheet / ADS Information",
    "Public Disclosure Review",
    "Patent Center",
    "Entity status"
)

foreach ($expected in $worksheetExpectations) {
    if ($worksheet -notmatch [regex]::Escape($expected)) {
        throw "USPTO worksheet missing expected section or phrase: $expected"
    }
}

$forbidden = @(
    "DATABASE_URL",
    "password",
    "api key:",
    "secret value",
    "postgres://"
)

$combined = @($spec, $figures, $evidence, $worksheet) -join "`n"
foreach ($term in $forbidden) {
    if ($combined -match [regex]::Escape($term)) {
        throw "Patent package appears to contain forbidden sensitive term: $term"
    }
}

[pscustomobject]@{
    package = "kani-provisional-patent-documentation"
    status = "ok"
    file_count = $requiredFiles.Count
    figures = 8
    includes_specification = $true
    includes_figures = $true
    includes_sandbox_evidence = $true
    includes_uspto_worksheet = $true
    secrets_detected = $false
}
