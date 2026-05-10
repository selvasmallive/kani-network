# Provisional Patent Application Draft

## Title

Permissioned Tokenized-Fiat Settlement Network With Crypto-Agile Validation, Compliance-Gated Messaging, Double-Entry Ledger Finality, and Cloud-Native Validator Operations

## Applicant / Inventor Information

To be completed by counsel:

```text
Inventor(s): [FULL LEGAL NAME(S)]
Inventor residence(s): [CITY, STATE/PROVINCE, COUNTRY]
Applicant / assignee, if any: [ENTITY]
Correspondence address: [ADDRESS]
Attorney docket number, if any: [DOCKET]
U.S. government interest, if any: [NONE / DETAILS]
```

## Cross-Reference To Related Applications

None, unless counsel identifies a related prior application.

## Field

The disclosure relates to distributed financial settlement systems, private permissioned ledger systems, secure financial messaging, tokenized fiat accounting, validator-based finality, compliance screening, crypto-agile signing, and cloud-native operation of institutional settlement networks.

## Background

Existing cross-border and inter-institution settlement networks often separate payment messaging from settlement finality. Financial institutions may exchange standardized payment messages while actual settlement, reconciliation, and audit trails are handled by separate systems. Public blockchains provide shared ledgers but generally expose public participation, public assets, mining or open validator sets, and operational models unsuitable for regulated institutional settlement networks.

There is a need for an institutional settlement network that combines financial-message compatibility, controlled validator participation, tokenized fiat balances, immutable settlement evidence, compliance screening, and secure cloud operation without creating a public cryptocurrency or permitting unrestricted retail access.

## Summary

Embodiments described herein provide a private, permissioned settlement network for institutional participants. The network includes an API layer, an ISO 20022 translation layer, a compliance screening layer, a settlement ledger, and a validator runtime. The ledger maintains tokenized fiat balances such as test or production-denominated assets, records transaction journals, enforces no-negative-balance rules, restricts issuance and redemption operations to authorized treasury accounts, and appends finalized blocks containing settlement transactions.

In one embodiment, pending transactions are generated from direct API payment requests or from ISO 20022 messages, screened against a compliance profile, stored in a ledger database, and finalized by a validator set. A Proof-of-Authority validator configuration uses multiple validators, a deterministic leader schedule, and quorum finality metadata. In other embodiments, the same transaction and ledger interfaces support Byzantine Fault Tolerant consensus.

In one embodiment, cryptographic algorithms are selected by configuration profiles rather than hard-coded logic. A transaction or block may be signed or verified according to an active crypto profile, such as a classical signature algorithm, a post-quantum algorithm, or a hybrid profile. This permits transition between cryptographic suites without rewriting ledger or payment logic.

In one embodiment, cloud-native controls deploy an API service, validator processes, a ledger database, secret management, monitoring, budget guardrails, and audit evidence capture. Validators may run as scheduled jobs, continuously running Kubernetes workloads, or both during migration. A cost-guard service may receive billing-budget notifications and pause a legacy validator path while preserving a separately approved validator runtime.

The described system is not a public cryptocurrency. Validator membership is permissioned, mining is not used, retail wallets are not required, and settlement operation is constrained by compliance and legal gates.

## Brief Description Of The Drawings

The accompanying figure set is provided in `FIGURES.md`.

- Figure 1 illustrates the private settlement network architecture.
- Figure 2 illustrates the payment-to-finality flow.
- Figure 3 illustrates a ledger, journal, and block data model.
- Figure 4 illustrates validator finality and leader rotation.
- Figure 5 illustrates crypto-agile profile selection.
- Figure 6 illustrates ISO 20022 translation and compliance gating.
- Figure 7 illustrates a cloud-native sandbox and GKE validator deployment.
- Figure 8 illustrates budget guardrail and observation evidence flows.

## Detailed Description

### 1. System Overview

A private settlement network includes institutional clients, an API gateway or service endpoint, an API service, an optional financial-message parser, a compliance decision engine, a ledger service, validator nodes or validator jobs, a durable ledger database, a block/audit archive, secret management, monitoring, and deployment infrastructure.

The system supports institutional payment workflows while enforcing a sandbox or production boundary. In a sandbox boundary, only test assets are permitted, and real value, fiat redemption, customer custody, external user access, and trading are disabled. In a production boundary, additional legal, compliance, security, and operational gates must be satisfied before value movement is enabled.

### 2. Ledger Model

The ledger maintains accounts, assets, balances, journal entries, audit events, pending transactions, and finalized blocks.

Representative account types include:

```text
TREASURY
INSTITUTION
SETTLEMENT
FEE
```

Representative assets include:

```text
KCAD_TEST
KUSD_TEST
KCAD
KUSD
KEUR
KINR
```

The sandbox implementation restricts settlement to test assets such as `KCAD_TEST` and `KUSD_TEST`. Production assets are not enabled until legal and compliance approvals are complete.

The ledger enforces:

- Double-entry accounting semantics by recording balanced journal movements.
- No negative balances.
- Idempotent transaction lookup and payment status.
- Immutable finalized block append.
- Restricted mint and burn operations.
- Audit events for authorization failures, compliance decisions, and settlement actions.

### 3. Transaction Model

A transaction may include:

```text
transaction_id
from_account
to_account
asset
amount
nonce
transaction_kind
metadata
signatures
created_at
```

Transaction kinds may include mint, burn, transfer, and ISO-originated payment transactions. Amounts are represented in minor units to avoid floating-point settlement errors.

### 4. Block Model

A finalized block may include:

```text
height
prev_hash
transactions
validator
signature
hash
finalized_by
created_at
```

The block hash commits to block contents and links to the previous block hash. The `finalized_by` field records quorum participation. The validator field records the block producer identity.

### 5. Validator And Finality Runtime

In a Proof-of-Authority embodiment, validators are permissioned and identified in configuration. A leader schedule may use round-robin ordering across validators. For a three-validator sandbox, finality is recorded when at least two validators participate or attest to the block.

The validator runtime may operate in at least two modes:

- Scheduled sweep mode: a cloud job or local process periodically sweeps pending transactions and finalizes blocks.
- Continuous validator mode: multiple validator pods run continuously in a Kubernetes cluster and coordinate against the ledger database.

The same ledger and transaction model supports future migration to a BFT consensus engine. The sandbox includes an abstract consensus interface and a prototype BFT path while the live runtime remains PoA.

### 6. Crypto-Agile Profile Selection

Cryptographic behavior is profile-driven. A configuration may specify the active profile, transaction-signature algorithms, validator-signature algorithms, and hash algorithm.

An example profile is:

```yaml
crypto:
  active_profile: hybrid-pqc-v1

profiles:
  hybrid-pqc-v1:
    transaction_signature:
      - ED25519
      - ML_DSA_65
    validator_signature:
      - ML_DSA_65
    hash: SHA3_256
```

The ledger and validator code consume crypto-profile choices through shared interfaces. This allows replacement or augmentation of algorithms without changing payment semantics, account semantics, or finality semantics.

### 7. Compliance-Gated Settlement

Before a payment becomes eligible for settlement, a compliance engine screens the payment against an active profile. In a sandbox embodiment, straight-through processing is allowed only for approved test institutions, approved test assets, non-self-transfers, and amounts below manual-review thresholds. Compliance decisions are recorded as audit events.

Payments may be:

- Accepted for settlement.
- Blocked.
- Held for manual review.
- Approved or rejected after review.

This gating prevents the ledger from treating every authenticated request as automatically settleable.

### 8. ISO 20022 Translation

The system accepts direct API payment requests and ISO 20022-inspired payment messages. In one embodiment, a `pacs.008` customer credit transfer message is parsed, debtor and creditor identifiers are mapped to sandbox ledger accounts, the payment is screened, and a ledger transaction is queued. Status can be returned through a `pacs.002`-style response. Account statement data can be returned through a `camt.053`-style response derived from finalized journal entries.

This permits standards-compatible messaging while preserving ledger-native settlement controls.

### 9. API And Reporting

The API layer exposes payment submission, payment lookup, balances, blocks, validators, audit events, and reports. Administrative endpoints may expose settlement summaries, compliance decisions, and validator finality reports. In the sandbox deployment, access is controlled by configured sandbox API keys stored in secret management.

### 10. Cloud-Native Deployment

One embodiment deploys:

- API service on Cloud Run.
- Ledger database on Cloud SQL PostgreSQL.
- Validator jobs on Cloud Run Jobs and Cloud Scheduler.
- Continuous validators on GKE.
- Container images in Artifact Registry.
- Secrets in Secret Manager.
- Monitoring and alerting in Cloud Monitoring.
- Budget events through Cloud Billing budgets, Pub/Sub, and a cost-guard service.

The GKE sandbox pilot uses one zonal Standard cluster, one `e2-medium` node, three validator deployments, Workload Identity, and Cloud SQL proxy sidecars.

### 11. Budget Guardrail And Operational Brake

A billing budget guardrail may be configured with thresholds and notification channels. A cost-guard service may receive budget notifications and pause a legacy validator scheduler if a threshold is crossed. This guardrail is not a hard spending cap and, in the sandbox pilot, does not stop the GKE validator cluster.

### 12. Sandbox MVP Implementation Results

The implemented sandbox MVP demonstrates the following:

- Cloud Run API is reachable and healthy.
- Cloud SQL ledger is running with backups and point-in-time recovery enabled.
- GKE cluster is running in `northamerica-northeast1-a`.
- Three validator pods are running with zero restarts at capture.
- A payment smoke test minted test value, transferred value, processed an ISO-originated transaction, recorded compliance events, finalized blocks, and produced reports.
- Latest observed block height at day-zero capture was `42`.
- Pending transaction count was `0`.
- Finality for the latest smoke-test block was recorded by `validator-c` and `validator-a`.

Further details are provided in `SANDBOX_MVP_EVIDENCE_APPENDIX.md`.

## Example Embodiments

### Embodiment 1: Payment API To Ledger Finality

An institution submits a payment instruction to an API. The API authenticates the request, validates the asset and amount, invokes compliance screening, records a pending transaction, and returns a payment identifier. A validator runtime selects the pending transaction, creates a block, signs the block, records finality participants, appends the block, and updates balances and journals.

### Embodiment 2: ISO 20022 To Ledger Settlement

An institution submits an ISO 20022 `pacs.008`-style XML payment. The parser extracts debtor, creditor, asset, amount, and message identifiers. The payment is mapped to ledger accounts and processed through the same compliance and ledger path as an API-native payment. A status response is generated in `pacs.002` style.

### Embodiment 3: Crypto-Agile Validator Profile

A validator reads an active crypto profile that specifies a hash algorithm and one or more signature algorithms. The validator signs block material according to the active profile and records enough metadata for later verification. A new profile may be activated to migrate to a new signature suite.

### Embodiment 4: GKE Continuous Validators With Legacy Scheduler Pause

A sandbox operator deploys continuous validators to GKE while pausing a legacy scheduled validator job. Each validator pod runs a validator container and a Cloud SQL proxy sidecar. The validator service account uses Workload Identity to access database and secret resources. The ledger finalizes payments without requiring the legacy scheduler to run.

### Embodiment 5: Budget-Triggered Operational Control

A budget notification is sent to a Pub/Sub topic and pushed to a cost-guard service. If the cost-to-budget ratio exceeds a threshold, the cost-guard service pauses a configured legacy scheduler job and records an audit response. The configuration records whether the action is dry-run or active.

## Optional Claim-Style Concepts For Counsel

Formal claims are not required for a U.S. provisional application. The following are non-limiting claim-style concepts for counsel to evaluate:

1. A computer-implemented method for permissioned settlement comprising receiving a payment instruction, screening the instruction under a compliance profile, recording a pending ledger transaction, selecting the transaction by a permissioned validator, appending a hash-linked block, and updating double-entry balances.
2. The method of concept 1 wherein the payment instruction is derived from an ISO 20022 message.
3. The method of concept 1 wherein validator finality is recorded as identities of a quorum of validators.
4. The method of concept 1 wherein the validator leader is selected by a deterministic round-robin schedule.
5. The method of concept 1 wherein the transaction is rejected before settlement if it violates a sandbox or production compliance profile.
6. The method of concept 1 wherein mint and burn operations are restricted to treasury accounts.
7. The method of concept 1 wherein no account balance is permitted to become negative.
8. A system comprising an API service, a compliance engine, a ledger database, and permissioned validator runtimes configured to finalize tokenized fiat settlement transactions.
9. The system of concept 8 wherein the validator runtimes execute as Kubernetes workloads.
10. The system of concept 8 wherein the validator runtimes execute as scheduled cloud jobs.
11. The system of concept 8 wherein the ledger database stores accounts, balances, journal entries, audit events, pending transactions, and finalized blocks.
12. The system of concept 8 wherein cryptographic signing is selected by an active crypto profile.
13. The system of concept 12 wherein the active crypto profile includes a post-quantum or hybrid signature option.
14. The system of concept 8 wherein a budget event service receives cloud budget notifications and pauses a validator scheduler.
15. The system of concept 8 wherein a sandbox boundary disables real-value settlement, redemption, external onboarding, and production authorization.
16. A non-transitory computer-readable medium storing instructions that cause processors to perform compliance-gated tokenized-fiat settlement with validator finality.
17. The medium of concept 16 wherein the instructions generate ISO 20022 status messages based on ledger payment status.
18. The medium of concept 16 wherein the instructions generate account statements from finalized journal entries.
19. The medium of concept 16 wherein the instructions expose validator finality reports.
20. The medium of concept 16 wherein the instructions enforce profile-driven cryptographic algorithm selection.

## Advantages

Embodiments may provide:

- Shared settlement evidence without public mining.
- Institutional-only participation.
- Direct linkage between financial messaging and ledger finality.
- Compliance screening before ledger finalization.
- Configurable crypto agility.
- Testable sandbox mode that cannot move real value.
- Cloud-native validator operation with operational guardrails.
- Audit-ready reports for settlement, compliance, and validator finality.

## Alternatives And Variations

The system may be implemented on cloud providers other than Google Cloud. The ledger database may be PostgreSQL, another relational database, or a replicated state store. Validators may be virtual machines, containers, Kubernetes workloads, serverless jobs, or HSM-backed signing services. Consensus may be PoA, BFT, HotStuff-style, Tendermint-style, or another permissioned finality protocol. ISO 20022 support may include additional message families. Crypto profiles may include different classical or post-quantum algorithms. Budget guardrails may trigger different operational brakes or notifications.

## Abstract Draft

A private permissioned settlement network receives institutional payment instructions, screens the instructions under compliance policies, records tokenized-fiat ledger transactions, and finalizes the transactions using permissioned validators. The ledger enforces no-negative-balance and double-entry accounting controls and appends hash-linked blocks with validator finality metadata. Financial messages such as ISO 20022 payment messages may be translated into ledger transactions and status responses may be generated from ledger state. Cryptographic algorithms for transaction and validator signing are selected by configurable crypto profiles to support crypto agility. Cloud-native deployments may run API services, ledger databases, validator jobs or Kubernetes validator pods, secret management, monitoring, and budget-triggered operational controls. Sandbox mode disables real-value settlement, fiat redemption, external onboarding, and production authorization while permitting end-to-end validation of mint, transfer, compliance, finality, audit, and reporting flows.

