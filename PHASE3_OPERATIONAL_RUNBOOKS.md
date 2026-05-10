# KANI Phase 3 Operational Runbooks

Status: operational slice ready
Release candidate: `phase3-operational-runbooks-rc1`
Date: 2026-05-09

This slice defines the minimum operator runbooks for the Phase 3 enterprise sandbox. It creates no Google Cloud resources, enables no production operations, and does not authorize real-value activity.

## Runtime Boundary

The operating boundary remains:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

No production deployment, customer onboarding, fiat deposit, redemption, custody, trading, or regulated payment service is authorized by this runbook set.

## Operator Roles

Minimum sandbox roles:

- `technical_operator`: deploys sandbox services, runs validators, reviews health, and executes rollback.
- `settlement_operator`: reviews pending, held, finalized, rejected, and failed payments.
- `compliance_reviewer`: owns manual-review cases and policy-decision evidence.
- `security_operator`: owns IAM, secrets, credential rotation, and incident response.
- `audit_reviewer`: exports audit and reconciliation evidence under admin authorization.
- `release_approver`: confirms release, rollback, and post-release evidence.

No single role should approve and execute production-sensitive changes once real-value readiness is ever considered.

## Daily Operating Runbook

Daily sandbox checks:

1. Confirm the active project and environment are sandbox-only.
2. Confirm `REAL_VALUE = FALSE` and `REDEEMABLE = FALSE`.
3. Review Cloud Run API health and error alerts.
4. Review Cloud Scheduler validator job status.
5. Review pending transactions, held payments, rejected payments, and latest finalized block height.
6. Review Cloud SQL error alerts and backup/PITR status.
7. Review budget and cost-guard notifications.
8. Export a daily evidence note with time, operator, commands, results, and follow-up actions.

Required evidence:

- Active project id and region.
- API health result.
- Latest block height and finality voters.
- Pending and held payment counts.
- Compliance case summary.
- Cloud SQL backup/PITR status.
- Open incidents and acknowledged alerts.

## Validator Operations

The current Phase 2 lean topology uses a Cloud Run Job plus Cloud Scheduler to run the logical `validator-a`, `validator-b`, and `validator-c` sweep path. GKE validator operations remain deferred.

Validator runbook:

1. Verify the Scheduler job is enabled only in the sandbox project.
2. Confirm the validator job uses the expected image digest.
3. Run the validator job manually only when the API and database are healthy.
4. Confirm finalized block height advances after pending transactions exist.
5. Confirm finality includes at least two validators from the configured set.
6. Record validator execution id, block height, and finality proof evidence.

Pause conditions:

- Unexpected production flag value.
- Cloud SQL connectivity errors.
- Repeated validator job failures.
- Ledger/reconciliation discrepancy.
- Budget guardrail trigger.
- Security incident or suspected credential compromise.

## Incident Response

Incident severity:

- `SEV1`: suspected real-value exposure, unauthorized public access, key compromise, or ledger corruption.
- `SEV2`: failed settlement finality, Cloud SQL restore risk, repeated API errors, or compliance workflow outage.
- `SEV3`: isolated failed request, delayed validator sweep, documentation mismatch, or non-critical alert.

SEV1 actions:

1. Freeze validator Scheduler execution.
2. Disable external or institution-facing ingress paths if any are active.
3. Rotate affected sandbox credentials.
4. Preserve logs, audit events, image digests, Terraform outputs, and operator timeline.
5. Notify security, compliance, and release approvers.
6. Do not resume until a written incident record and recovery approval exist.

Every incident must have an owner, severity, timeline, affected components, containment action, evidence link, root-cause note, and closure approval.

## Release And Rollback Runbook

Release preflight:

- `cargo fmt --check`
- `cargo clippy --workspace -- -D warnings`
- `cargo test --workspace`
- `scripts/phase2-validate.ps1`
- `scripts/phase3-validate.ps1`
- Terraform `fmt`, `validate`, and `plan` for the intended environment when infrastructure is in scope.

Release evidence:

- Git commit and tag.
- Container image digest.
- Terraform plan file or explicit no-infrastructure-change statement.
- API smoke-test result.
- Security smoke-test result.
- Operator approval.

Rollback options:

- Restore the previous Cloud Run revision for `kani-api`.
- Restore the previous validator job image digest.
- Disable Cloud Scheduler while investigating validator failures.
- Reapply the last known-good Terraform state only after plan review.
- Use Cloud SQL PITR restore into a separate instance for investigation before any destructive recovery.

Production rollback is not approved by this sandbox runbook. It requires a separate production-ready runbook, legal and compliance approval, and tested recovery evidence.

## Backup And Restore Runbook

Backup checks:

- Cloud SQL automated backups enabled.
- PITR enabled for the sandbox ledger database.
- Restore commands documented and tested against a separate restore target.
- Restored database reconciles finalized blocks, transactions, journal entries, balances, issued supply, compliance decisions, and audit events.

Restore guardrails:

- Never overwrite the active ledger database during a drill.
- Restore into a separate instance or database.
- Run reconciliation before promoting any recovered state.
- Attach evidence to the operational record.

## Credential And Secret Rotation Runbook

Rotation triggers:

- Scheduled rotation.
- Operator departure or role change.
- Suspected exposure.
- Failed access review.
- Release of a new credential profile.

Rotation steps:

1. Create the replacement secret or credential metadata.
2. Deploy the dependent service with the new version.
3. Run API, validator, security, and smoke checks.
4. Revoke or retire the old credential.
5. Confirm no API keys, secrets, private keys, or bearer tokens are present in logs or audit exports.
6. Record rotation evidence and approver.

## Audit Evidence Pack

Each release, incident, restore drill, or credential rotation must produce an evidence pack:

- Git commit and tag.
- Operator identity and approval record.
- Runtime boundary proof.
- Commands executed and outputs summarized.
- Cloud resource identifiers touched.
- Ledger block height before and after.
- Compliance case impact.
- Audit export reference.
- Known deferrals and follow-up owner.

## Deferred Production Operations

Deferred until later phases:

- GKE multi-node validator runbooks.
- HSM-backed production signing ceremonies.
- Production mTLS certificate issuance.
- External institution onboarding operations.
- Real-value incident response.
- Legal-approved data retention periods.
- Disaster recovery with production RTO/RPO commitments.

## Acceptance Criteria

This slice is accepted when:

- Operational runbooks are checked in.
- A structured runbook config exists.
- Static validation confirms sandbox-only boundaries.
- Phase 3 validation includes the runbook checkpoint.
- No Google Cloud resources are created.
- No production or real-value operations are enabled.
- Current validator behavior remains Phase 1 PoA.
