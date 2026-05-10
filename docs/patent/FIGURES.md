# Figure Set For Provisional Patent Draft

These figures are engineering diagrams for counsel to redraw or file as informal provisional drawings if appropriate.

## Figure 1: Private Settlement Network Architecture

```mermaid
flowchart TB
    A["Institution A"] --> G["API Gateway / Cloud Run API"]
    B["Institution B"] --> G
    G --> I["ISO 20022 Parser"]
    G --> C["Compliance Engine"]
    I --> C
    C --> L["Settlement Ledger"]
    L --> D["Cloud SQL / Ledger State"]
    L --> V["Permissioned Validators"]
    V --> BLK["Hash-Linked Finalized Blocks"]
    V --> AUD["Audit Events and Reports"]
    S["Secret Manager"] --> G
    S --> V
    M["Monitoring / Alerts"] --> G
    M --> V
```

## Figure 2: Payment-To-Finality Flow

```mermaid
sequenceDiagram
    participant Inst as Institution
    participant API as KANI API
    participant ISO as ISO 20022 Adapter
    participant Comp as Compliance Engine
    participant Ledger as Ledger
    participant Val as Validator Set
    participant Audit as Audit/Reports

    Inst->>API: Submit payment or ISO message
    API->>ISO: Parse message when ISO input is used
    ISO-->>API: Ledger payment fields
    API->>Comp: Screen payment
    Comp-->>API: Allow / hold / block
    API->>Ledger: Queue pending transaction
    Val->>Ledger: Sweep pending transaction
    Val->>Ledger: Append finalized block
    Ledger->>Audit: Record journal and audit events
    API-->>Inst: Payment status and report access
```

## Figure 3: Ledger And Block Data Model

```mermaid
erDiagram
    ACCOUNT ||--o{ BALANCE : owns
    ACCOUNT ||--o{ JOURNAL_ENTRY : participates
    TRANSACTION ||--o{ JOURNAL_ENTRY : creates
    TRANSACTION }o--|| BLOCK : finalized_in
    BLOCK ||--o{ AUDIT_EVENT : emits
    VALIDATOR ||--o{ BLOCK : produces
    VALIDATOR ||--o{ FINALITY_VOTE : signs
    BLOCK ||--o{ FINALITY_VOTE : finalized_by

    ACCOUNT {
      string id
      string account_type
      string institution_id
    }
    BALANCE {
      string account_id
      string asset
      integer amount
    }
    TRANSACTION {
      string id
      string from
      string to
      string asset
      integer amount
      string kind
    }
    BLOCK {
      integer height
      string prev_hash
      string hash
      string validator
    }
```

## Figure 4: PoA Validator Finality

```mermaid
flowchart LR
    T["Pending Transactions"] --> R["Round-Robin Leader Selection"]
    R --> VA["validator-a"]
    R --> VB["validator-b"]
    R --> VC["validator-c"]
    VA --> B["Candidate Block"]
    VB --> B
    VC --> B
    B --> Q["2-of-3 Finality Metadata"]
    Q --> F["Finalized Block Append"]
```

## Figure 5: Crypto-Agile Profile Selection

```mermaid
flowchart TB
    CFG["crypto-profiles.yaml"] --> P["Active Crypto Profile"]
    P --> H["Hash: SHA2 / SHA3 / Other"]
    P --> TS["Transaction Signature Suite"]
    P --> VS["Validator Signature Suite"]
    TS --> TX["Transaction Verification"]
    VS --> BLK["Block Verification"]
    H --> BLK
```

## Figure 6: ISO 20022 And Compliance Gating

```mermaid
flowchart TB
    XML["pacs.008 XML"] --> PARSE["Parse and Validate"]
    PARSE --> MAP["Map Debtor/Creditor to Ledger Accounts"]
    MAP --> RULES["Compliance Profile"]
    RULES -->|allow| PAY["Queue Payment"]
    RULES -->|hold| CASE["Manual Review Case"]
    RULES -->|block| REJ["Reject and Audit"]
    PAY --> STATUS["pacs.002 Status"]
    PAY --> STMT["camt.053 Statement From Journal"]
```

## Figure 7: Cloud-Native Sandbox With GKE Validators

```mermaid
flowchart TB
    CR["Cloud Run API"] --> SQL["Cloud SQL PostgreSQL"]
    GKE["GKE Standard Zonal Cluster"] --> PODA["validator-a Pod"]
    GKE --> PODB["validator-b Pod"]
    GKE --> PODC["validator-c Pod"]
    PODA --> SQL
    PODB --> SQL
    PODC --> SQL
    SM["Secret Manager"] --> CR
    SM --> GKE
    AR["Artifact Registry"] --> GKE
    MON["Cloud Monitoring"] --> CR
    MON --> GKE
    SCHED["Legacy Cloud Scheduler Validator Job"] -. paused .-> SQL
```

## Figure 8: Budget Guardrail And Observation Evidence

```mermaid
flowchart TB
    BILL["Cloud Billing Budget"] --> ALERT["Email Alert Channels"]
    BILL --> PUB["Pub/Sub Budget Topic"]
    PUB --> GUARD["Cost Guard Service"]
    GUARD --> SCHED["Pause Legacy Validator Scheduler"]
    GKE["GKE Validators"] --> OBS["Observation Evidence"]
    API["Cloud Smoke Test"] --> OBS
    LOGS["Cloud Logs"] --> OBS
    OBS --> REP["Patent / Audit Evidence Appendix"]
```

