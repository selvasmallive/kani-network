# KANI Phase 4 Disaster Recovery Readiness

Status: DR readiness ready
Release candidate: `phase4-dr-readiness-rc1`
Date: 2026-05-10

This checkpoint defines backup, restore, RTO/RPO, and disaster recovery evidence expectations for the no-GKE Phase 4 track. It does not execute a restore drill, create restore instances, change Cloud SQL backup settings, create Google Cloud resources, or authorize production recovery operations.

## Runtime Boundary

The active boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

The active runtime baseline remains `phase2-lean-no-gke`.

## Readiness Objective

The goal is to define repeatable recovery evidence before any production-readiness decision. DR readiness must prove that ledger state, validator scheduling, API runtime, secrets, audit history, and operator runbooks can be restored without corrupting balances or finality history.

This plan is not an approval to execute production recovery, create paid DR resources, or move real value.

## Recovery Domains

DR readiness covers these domains:

- `ledger_database`: Cloud SQL PostgreSQL ledger state, automated backups, PITR settings, restore target, migrations, and reconciliation.
- `ledger_integrity`: blocks, transactions, balances, journal entries, audit events, compliance cases, issued supply, and finality metadata.
- `api_runtime`: Cloud Run service image, environment boundary flags, API key source, database URL, and rollback image.
- `validator_runtime`: Cloud Run Job, Cloud Scheduler trigger, validator identities, sweep mode, and finality evidence.
- `secrets_and_credentials`: Secret Manager versions, sandbox API keys, database password, and future KMS/HSM dependencies.
- `artifact_and_config`: Artifact Registry image, Terraform variables, committed config, migration files, and release tag.
- `audit_and_reporting`: audit-event retention, settlement reports, compliance reports, and validator-finality reports.
- `operator_runbooks`: incident declaration, write freeze, restore decision, validation checklist, and post-drill evidence.

## Target RTO/RPO

These targets are planning targets, not production service guarantees:

- `sandbox_no_gke`: target RTO `4h`, target RPO `15m`, restore source `cloud_sql_backup_or_pitr`.
- `preprod_no_gke_candidate`: target RTO `2h`, target RPO `15m`, restore source `cloud_sql_backup_or_pitr`.
- `production_candidate`: target RTO and RPO remain blocked until legal, compliance, security, operations, finance, and executive readiness gates approve a production service model.

Actual measured restore times must be recorded during every approved drill.

## Evidence Drills

Required future evidence drills:

1. `backup_configuration_inventory`: capture Cloud SQL backup, PITR, retained-backup, and transaction-log-retention settings.
2. `backup_list_capture`: list available automated backups and record backup age.
3. `pitr_restore_to_separate_instance`: restore to a separate instance or approved temporary target; never overwrite the active ledger during a drill.
4. `migration_and_startup_check`: apply migrations and start a sandbox API against the restored database.
5. `ledger_reconciliation_check`: compare account balances, issued supply, journal totals, block height, block hashes, transaction counts, and audit-event counts.
6. `validator_recovery_check`: confirm validator scheduler pause/resume behavior and latest finalized block continuity.
7. `secret_recovery_check`: confirm restored runtime uses current Secret Manager values and does not log secrets.
8. `reporting_recovery_check`: confirm settlement, compliance, validator-finality, block, and audit reports read from restored state.
9. `abandon_or_cutover_decision`: record whether the restore is abandoned, repeated, or proposed for cutover.
10. `post_drill_report`: record measured RTO/RPO, defects, owners, remediation, and approval status.

## Restore Runbook

Future restore drills must follow this shape:

1. Declare incident or drill window.
2. Confirm `ENV=SANDBOX`, `REAL_VALUE=FALSE`, and `REDEEMABLE=FALSE`.
3. Pause validator Scheduler if the drill touches active sandbox state.
4. Freeze write traffic or use a separate restored target.
5. Capture current ledger proof: latest block height, latest block hash, issued supply, balances, pending transaction count, and audit event count.
6. Restore Cloud SQL backup or PITR to a separate target.
7. Apply migrations and start a sandbox-only API against the restored target.
8. Run smoke, security, reconciliation, and reporting checks.
9. Record measured RTO/RPO and defects.
10. Resume scheduler or abandon the restored target after approvals.

## Required Gates Before Drill Execution

Before any paid-resource restore drill:

- Cost estimate reviewed and approved.
- Drill owner and reviewer assigned.
- Maintenance window or sandbox isolation approved.
- Terraform plan reviewed if temporary resources are needed.
- Cloud SQL restore target named and approved.
- Secret access and rotation plan reviewed.
- Reconciliation checklist approved.
- Incident response and communication plan approved.
- Data retention and privacy review completed.
- Regulatory readiness remains non-overridden.

No gate can authorize real-value movement by itself.

## Terraform Boundary

`infra/terraform/phase4_dr_readiness.tf` is design-only.

It must:

- Keep `phase4_dr_readiness_enabled = false`.
- Declare no `resource "google_*"` blocks.
- Produce only planning outputs.
- Keep restore drill execution deferred.
- Keep temporary restore instances, cross-region replicas, archive buckets, scheduler changes, and production recovery disabled.

## Non-Enablement

This checkpoint keeps the following disabled:

- Restore drill execution.
- Restore instance creation.
- Cloud SQL backup configuration changes.
- Cross-region replica creation.
- Archive bucket creation.
- Validator Scheduler changes.
- Restored database promotion.
- Production recovery execution.
- Terraform apply.
- Google Cloud resource creation.
- Real-value settlement.
- Production go-live.

## Acceptance Criteria

This checkpoint is accepted when:

- DR readiness plan is checked in.
- Structured DR readiness config exists.
- Design-only Terraform guard file exists.
- Static DR readiness validator passes.
- Phase 4 validator includes the DR readiness checkpoint.
- Phase 3 and Phase 2 validators still pass.
- Terraform validation passes.
- No Google Cloud resources are created or changed.
- No restore drill, restore instance, backup change, cross-region replica, archive bucket, scheduler change, production recovery, GKE, production ingress, HSM/KMS production signing, or real-value capability is enabled.
