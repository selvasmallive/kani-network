# KANI Research Observation Report

Generated: 2026-05-10T08:29:17Z

Window: last 21 days

Status: sandbox research observation data pack

## Executive Signal

This report summarizes daily sandbox observations for presentation and research use. It does not claim production readiness, regulatory approval, or real-value settlement capability.

## Latest Observation

| Metric | Value |
|---|---:|
| Collection ID | 20260510T082648Z |
| Captured at UTC | 2026-05-10T08:26:48.3429893Z |
| API health | ok |
| Cloud SQL state | RUNNABLE |
| GKE cluster status | RUNNING |
| Validator pods running | 3 |
| Validator restarts total | 0 |
| Latest block height | 48 |
| Pending transaction count | 0 |
| Settlement report transactions | 45 |
| Compliance report events | 23 |
| Validator finality report blocks | 45 |
| Health latency ms | 186 |
| Admin latest-block latency ms | 82 |
| CORP_A balance latency ms | 139 |
| CORP_B balance latency ms | 133 |
| Smoke lifecycle duration ms | 28378 |
| Institution paths timed | KANI_ADMIN,CORP_A,CORP_B |
| Smoke test status | ok |

## Window Rollup

| Signal | Value |
|---|---:|
| Observation rows | 3 |
| Successful observation rows used for charts | 2 |
| First block height | 42 |
| Latest block height | 48 |
| Block growth | 6 |
| Max pending count | 0 |
| Max validator restarts | 0 |
| Minimum validator pods running | 3 |
| Max API errors in a 24h window | n/a |
| Max KANI system errors in a 24h window | n/a |
| Max warnings in a 24h window | n/a |
| Avg health latency ms | 186 |
| Avg admin latest-block latency ms | 82 |
| Avg CORP_A balance latency ms | 139 |
| Avg CORP_B balance latency ms | 133 |
| Avg smoke lifecycle duration ms | 28378 |
| Smoke tests passed | 2 |
| Failed collections | 1 |

## PowerPoint-Ready Data Files

~~~text
docs/research/observations/kani_research_daily_observations.csv
docs/research/observations/kani_research_presentation_series.csv
docs/research/observations/kani_research_observation_rollup.json
~~~

## Presentation Use

Recommended charts:

1. Latest block height over time.
2. Pending transactions over time.
3. Validator pods running and validator restarts over time.
4. API, KANI system, and Cloud SQL errors by daily collection.
5. Settlement, compliance, and validator-finality report growth.
6. Institution-path latency for KANI_ADMIN, CORP_A, and CORP_B.

## Boundary

The observation remains sandbox-only:

~~~text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
~~~
