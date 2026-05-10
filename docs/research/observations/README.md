# KANI Research Observations

This folder stores daily sandbox observation data for research and PowerPoint evidence.

The scheduled collector is local to the Windows workstation and uses the existing Google Cloud CLI and Kubernetes credentials. It does not enable production settlement, real-value transfer, fiat redemption, or external customer access.

## Collection Plan

```text
Cadence: daily
Duration: 21 days total
Checkpoint 1: 7-day summary
Checkpoint 2: 14-day summary
Checkpoint 3: 21-day summary
Boundary: SANDBOX / REAL_VALUE=false / REDEEMABLE=false
```

Each daily collection captures:

- Cloud Run API and cost-guard service status.
- Cloud SQL state, database version, tier, backup, and PITR flags.
- GKE cluster status, pods, deployments, nodes, events, resource snapshots, and recent validator logs.
- Cloud Logging error and warning windows.
- KANI API health, latest block, pending transactions, validators, accounts, settlement report, compliance report, and validator-finality report.
- Optional daily sandbox smoke test with a fresh test asset.
- Timed API paths for `KANI_ADMIN`, `CORP_A`, and `CORP_B` from the workstation running the collector.

The scripts generate PowerPoint-ready CSV and JSON files:

```text
docs/research/observations/kani_research_daily_observations.csv
docs/research/observations/kani_research_presentation_series.csv
docs/research/observations/kani_research_observation_rollup.json
docs/research/observations/KANI_RESEARCH_OBSERVATION_REPORT.md
```

Raw per-run cloud snapshots are kept under each timestamped observation folder on the workstation. They are intentionally ignored by Git because they can include infrastructure metadata, secret references, and Kubernetes service account mount details. Review and redact raw folders before sharing them externally.

## Manual Commands

Run one collection now:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\research-daily-collection.ps1 -RunSmoke -GenerateSummary
```

Register the 21-day schedule:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-research-collection-schedule.ps1 -RunNow -Force
```

Generate a summary manually:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\research-summarize-observations.ps1 -WindowDays 7 -OutputName KANI_RESEARCH_7_DAY_REPORT.md
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\research-summarize-observations.ps1 -WindowDays 14 -OutputName KANI_RESEARCH_14_DAY_REPORT.md
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\research-summarize-observations.ps1 -WindowDays 21 -OutputName KANI_RESEARCH_21_DAY_REPORT.md
```

## Presentation Angles

Useful charts after several days:

1. Latest finalized block height over time.
2. Pending transaction count over time.
3. Validator pods running and restart count over time.
4. API, KANI system, Cloud SQL, and warning counts by collection.
5. Settlement, compliance, and validator-finality report growth.
6. Institution-path latency for admin, Corp A, and Corp B API calls.

## Latency Boundary

The current live sandbox is not globally distributed. It runs in Google Cloud `northamerica-northeast1`, with the GKE validator cluster in `northamerica-northeast1-a`. The daily collector records institution-path API latency from the local workstation to the current sandbox endpoint.

True global latency evidence requires additional regional probes or a later multi-region GKE design.
