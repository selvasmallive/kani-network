# KANI Phase 3 Enterprise Plan

Status: implementation started
Date: 2026-05-09
Scope: enterprise sandbox design after `phase2-lean-no-gke`

Phase 3 turns the working sandbox into an enterprise-grade design track. It does not enable real money movement. Every Phase 3 artifact must keep the network private, permissioned, compliance-first, and sandbox-gated until legal, regulatory, security, and operational readiness are separately approved.

## Runtime Boundary

Phase 3 starts from the same non-value-moving boundary:

```text
ENV = SANDBOX
REAL_VALUE = FALSE
REDEEMABLE = FALSE
```

No production deployment, customer onboarding, fiat deposit, redemption, custody, trading, or regulated payment service is authorized by this plan.

## Phase 3 Objectives

1. Define the BFT consensus boundary without breaking the Phase 2 PoA path.
2. Model institution onboarding as explicit data, credentials, roles, limits, and operational states.
3. Expand compliance from sandbox STP checks into a policy-versioned workflow with review cases.
4. Design production ingress with mTLS, WAF, private networking, and explicit trust anchors.
5. Define KMS/HSM-backed key management, rotation, signing, and audit ceremonies.
6. Create a regulatory readiness checklist that blocks real-value launch until reviewed by qualified legal and compliance advisors.

## Workstream 1: Consensus Evolution

Phase 2 uses one Cloud Run validator job to simulate the 3-validator PoA finality path. Phase 3 should introduce consensus interfaces before introducing a BFT implementation.

Planned design:

- Keep `PoA` as the default sandbox consensus engine.
- Add a `ConsensusEngine` abstraction in `kani-consensus`.
- Add shared consensus types in `kani-types`: proposal, vote, quorum certificate, round, epoch, validator set, and finality proof.
- Keep block validation deterministic and replayable from PostgreSQL state.
- Add a BFT prototype behind a feature flag or config flag.
- Require deterministic tests for equivocation, duplicate votes, stale rounds, wrong validator set, invalid quorum, and block replay.
- Defer GKE validator operations until the BFT message boundary is explicit and testable.

Exit criteria:

- PoA tests still pass.
- BFT data model is represented in code.
- Consensus engine selection is config-driven.
- No production BFT claim is made until multi-node validator operations are tested.

## Workstream 2: Institution Onboarding

Institution access must become explicit state rather than a fixed sandbox allowlist.

Planned model:

- `Institution`: legal name, institution code, jurisdiction, status, risk tier, allowed assets, limits, created/approved timestamps.
- `InstitutionCredential`: API credential metadata, mTLS certificate fingerprint, issuer, subject, expiry, rotation state, and revocation reason.
- `InstitutionAccount`: settlement accounts linked to institution, asset, account type, and operational limits.
- `InstitutionRole`: operator, approver, auditor, compliance reviewer, and technical admin.
- `OnboardingCase`: requested, due diligence, approved, rejected, suspended, offboarded.

Initial API surface:

```text
POST /v1/admin/institutions
GET  /v1/admin/institutions
GET  /v1/admin/institutions/{id}
POST /v1/admin/institutions/{id}/credentials
POST /v1/admin/institutions/{id}/suspend
POST /v1/admin/institutions/{id}/limits
```

Exit criteria:

- Sandbox institutions can be created from data, not hardcoded.
- Suspended institutions cannot submit payments.
- Credential rotation and revocation are audit logged.
- Existing `CORP_A`, `CORP_B`, and `KANI_TREASURY` sandbox identities remain available for tests.

## Workstream 3: Compliance Workflow

Phase 2 has `sandbox-stp-v1`. Phase 3 should turn compliance into a policy-versioned workflow with manual review states.

Planned capabilities:

- Policy version registry.
- Rule decisions: allow, review, reject, hold.
- Case lifecycle: opened, assigned, evidence requested, escalated, approved, rejected, closed.
- Payment status integration for held/rejected transactions.
- Sanctions/PEP/adverse-media adapter boundary without committing to a vendor.
- Velocity, amount, counterparty, geography, and asset controls.
- Full audit trail for rule inputs, outputs, reviewer actions, and policy versions.

Exit criteria:

- A payment can enter manual review without being finalized.
- Review approval can release a payment into the pending ledger queue.
- Review rejection records a terminal decision and prevents settlement.
- Compliance reports show policy version, rule, institution, reviewer, and decision counts.

## Workstream 4: Production Ingress And mTLS

Phase 2 uses direct Cloud Run ingress protected by IAM and app credentials. Phase 3 should define the production ingress boundary before enabling it.

Target design:

- External HTTPS load balancer or API gateway in front of Cloud Run.
- Cloud Armor policy for WAF/rate limits.
- Institution mTLS with certificate pinning or a private CA trust chain.
- Per-institution OAuth/OIDC for admin/operator users.
- Private egress from API to Cloud SQL and supporting services.
- Explicit separation between institution API, admin API, validator API, and internal health endpoints.
- No `allUsers` or `allAuthenticatedUsers` Cloud Run invoker grants.

Exit criteria:

- mTLS certificate metadata is tied to institution credentials.
- API requests can be authorized by institution identity, credential status, and role.
- Public unauthenticated requests remain denied.
- Production ingress can be tested in sandbox without real value.

## Workstream 5: Key Management And Crypto Agility

Phase 1 and Phase 2 already keep crypto profile-driven. Phase 3 should move signing and key operations toward managed custody patterns.

Planned capabilities:

- Cloud KMS/HSM key inventory for validator, treasury, API, and audit signing.
- Key profile registry: active, pending, retired, compromised.
- Dual-control key ceremony runbook.
- Signing service boundary so keys do not leave managed storage.
- Rotation and revocation workflows.
- Hybrid/PQC profile placeholders remain config-driven and non-hardcoded.
- Audit events for key creation, activation, signing, rotation, retirement, and emergency revoke.

Exit criteria:

- Key usage is traceable by key version and purpose.
- Sandbox key rotation can be tested without breaking ledger replay.
- The system can reject signatures from retired or unauthorized keys.

## Workstream 6: Regulatory And Legal Readiness

This is a readiness checklist, not legal advice. Current obligations must be verified with qualified legal and compliance advisors before any production or real-value activity.

Required gates before real-value launch:

- Legal classification review.
- Money-services/payment-services registration analysis.
- AML/KYC program design.
- Sanctions screening process.
- Privacy/data-retention review.
- Customer/institution agreements.
- Custody and safeguarding analysis.
- Incident response and suspicious-activity escalation procedures.
- Independent security review and penetration test.
- Board/operator approval for production go-live.

Exit criteria:

- Each gate has an owner, status, evidence link, and approval record.
- Production flags cannot be enabled without a signed readiness record.

## Workstream 7: Data, Audit, And Reporting

Phase 3 must make audit and reporting operator-grade.

Planned capabilities:

- Immutable audit event contract.
- Report export boundaries.
- Reconciliation reports by asset, institution, block height, and settlement day.
- Operational dashboards for pending, held, rejected, finalized, failed, and reversed payments.
- Retention policy matrix for audit, ledger, access, compliance, and security logs.

Exit criteria:

- Reports can be regenerated from ledger and audit state.
- Reconciliation discrepancies are explicit and audit logged.
- Compliance and operations can review the same canonical settlement data.

## Implementation Order

Recommended slices:

1. `phase3-spec-rc1`: planning docs, config, static validator.
2. `phase3-institution-model-rc1`: institution and credential types, migrations, admin APIs.
3. `phase3-compliance-cases-rc1`: compliance case state machine and held-payment flow.
4. `phase3-consensus-interface-rc1`: consensus abstraction and PoA adapter.
5. `phase3-bft-prototype-rc1`: sandbox-only BFT message model and tests.
6. `phase3-prod-edge-design-rc1`: Terraform design for mTLS/WAF/private ingress without apply by default.
7. `phase3-key-management-design-rc1`: KMS/HSM interfaces and runbooks.

## Acceptance Criteria

Phase 3 planning is accepted when:

- The roadmap is checked into the repo.
- A structured Phase 3 config exists.
- A static validator verifies the required planning artifacts.
- Phase 2 lean remains unchanged and passing.
- No GKE, production ingress, HSM, or real-value resources are created by this planning slice.

## Implementation Progress

`phase3-institution-model-rc1` is the first implementation slice. It adds institution, credential, onboarding, and limit types; in-memory and PostgreSQL persistence; sandbox admin institution APIs; and authorization checks that block suspended institutions from operating accounts. Details are recorded in `PHASE3_INSTITUTION_MODEL.md`.

`phase3-compliance-cases-rc1` adds held payments and manual-review compliance cases. `ComplianceDecision::Review` now opens a `ComplianceCase`, marks the payment `HELD`, keeps it out of validator settlement, and lets sandbox admins approve it into `PENDING` or reject it. Details are recorded in `PHASE3_COMPLIANCE_CASES.md`.

`phase3-consensus-interface-rc1` adds a `ConsensusEngine` abstraction, a config-built PoA adapter, and shared consensus proposal/vote/quorum/finality types for the later BFT prototype. Current validator behavior remains Phase 1 PoA. Details are recorded in `PHASE3_CONSENSUS_INTERFACE.md`.
