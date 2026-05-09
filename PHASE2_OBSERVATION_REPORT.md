# KANI Phase 2 Observation Report

Status: observation gate passed with watch items
Date: 2026-05-09
Scope: `phase2-lean-no-gke`

This report records the first post-wrap-up observation check for the Phase 2 lean sandbox. The system remains sandbox-only and must not be used for real money movement, customer funds, fiat redemption, custody, trading, or production payment services.

## Manual Console Check

The operator confirmed Google Cloud Alerting emails are arriving for `selva@kani.network`.

The Google Cloud Console was switched from the unrelated `diesel-equator-495603-q6` project to the correct KANI sandbox project:

```text
Project ID: kani-network-sandbox
Project display: kani-network
Organization: kani.network
```

The Alerting page showed:

```text
Alert policies: 5
Incidents firing: 1
Active incident: kani-sandbox Cloud SQL error logs
```

## Scheduler Observation

The validator scheduler is enabled and firing on the expected lean cadence:

```text
Job: kani-sandbox-validator-schedule
State: ENABLED
Schedule: */15 * * * *
Time zone: America/Toronto
Last attempt: 2026-05-09T19:45:03.717445Z
Next schedule time: 2026-05-09T20:00:03.001247Z
Status: {}
```

## Validator Observation

Recent scheduled Cloud Run validator executions are completing successfully. The latest scheduled execution observed was:

```text
Execution: kani-sandbox-validator-zsmmt
Created: 2026-05-09T19:45:03.804700Z
Completed: 2026-05-09T19:45:15.802550Z
Result: Execution completed successfully in 9.19s
Succeeded count: 1
Creator: kani-sandbox-scheduler@kani-network-sandbox.iam.gserviceaccount.com
Runtime: kani-node sweep
Validators: validator-a,validator-b,validator-c
Sandbox flags: ENV=SANDBOX, REAL_VALUE=FALSE, REDEEMABLE=FALSE
```

The recent execution list showed successful scheduled runs at 15-minute intervals.

## Cloud SQL Observation

The active Cloud SQL incident is open in Monitoring, but the current Cloud SQL instance state is healthy:

```text
Instance: kani-sandbox-ledger
State: RUNNABLE
Tier: db-g1-small
Edition: ENTERPRISE
Disk: 10 GB PD_HDD
Backups enabled: true
PITR enabled: true
Retained backups: 7
Transaction log retention: 7 days
Backup window: 07:00 UTC
```

Focused recent log checks returned no current matching Cloud SQL `severity>=ERROR` entries. A broad Cloud SQL log query showed normal `INFO` and `NOTICE` activity such as validator Cloud SQL connections, checkpoints, and Cloud SQL heartbeat vacuum/analyze messages.

Observation decision: keep the active Cloud SQL incident as a watch item for now. It appears stale or no longer reproducing, because the database is runnable, validator finality works, and the cloud smoke test passed.

## Cost Guard Observation

The cost guard is deployed and remains protected by Cloud Run IAM. Older logs show budget notification push noise during setup:

```text
2026-05-07: Several 500 responses from /v1/budget-events during early cost-guard setup
2026-05-07T23:47:03Z: 429 no available instance
2026-05-08T17:18:18Z: 429 no available instance
```

Observation decision: keep scale-to-zero for the lean cost profile and monitor. If these 429s recur on real budget notifications, the next mitigation is to either tune Pub/Sub retry/backoff or allow `kani-sandbox-cost-guard` a minimum instance of 1 during budget testing, accepting the small added cost.

## Smoke Test Evidence

Security smoke passed:

```text
profile = phase2-security-hardening
base_url = https://kani-sandbox-api-mlmnojda4a-nn.a.run.app
api_ingress = all
api_service_account = kani-sandbox-api@kani-network-sandbox.iam.gserviceaccount.com
api_public_invoker_absent = True
cost_guard_public_invoker_absent = True
validator_job_public_invoker_absent = True
secret_public_access_absent = True
secret_backed_api_env_verified = True
unauthenticated_health_denied_status = 403
invalid_sandbox_key_denied_status = 401
status = ok
```

Cloud smoke passed:

```text
profile = phase2-lean-no-gke
base_url = https://kani-sandbox-api-mlmnojda4a-nn.a.run.app
health = ok
asset = KCAD_TEST_20260509155011
mint_transaction = c50d5f3b-0382-4d85-b78b-bc900ab71c9e
transfer_transaction = 6cf93662-2fb0-4d6d-aca6-8126f1c056b4
iso_transaction = 4fa3ee15-424e-46eb-9c0b-4ed74dbd6348
iso_message_id = phase2-cloud-iso-KCAD_TEST_20260509155011
iso_status = ACSC
compliance_blocked_self_transfer = True
corp_a_balance = 875000
corp_b_balance = 125000
latest_block_height = 36
latest_block_validator = validator-c
latest_block_finalized_by = validator-c,validator-a
pending_count = 0
audit_reports_verified = True
settlement_report_transactions = 36
compliance_report_events = 14
validator_report_finalized_blocks = 36
status = ok
```

## Gate Result

Phase 2 lean is stable enough to continue.

Passed:

- Alert emails are arriving.
- Five Phase 2 alert policies exist in the correct project.
- Scheduler is enabled on the expected cadence.
- Validator executions are succeeding.
- Cloud SQL is runnable with backups and PITR enabled.
- Security smoke passed.
- End-to-end cloud smoke passed.

Watch items:

- Monitoring still shows one active Cloud SQL error-log incident, but current log checks and live smoke tests do not show an ongoing database failure.
- Cost guard had older setup-time 500 responses and later scale-to-zero 429 responses. Keep watching before changing the lean cost profile.

## Recommended Next Step

Move into Phase 3 planning while keeping the Phase 2 sandbox under observation. The first Phase 3 planning slice is tracked in `PHASE3_ENTERPRISE_PLAN.md` and should define the enterprise roadmap in code terms:

1. BFT consensus design boundary.
2. Institution onboarding model.
3. Compliance workflow expansion.
4. Production ingress and mTLS plan.
5. Key-management and HSM/KMS path.
6. Regulatory/legal readiness checklist.

GKE should remain deferred until validator-operations testing is worth the added cost.
