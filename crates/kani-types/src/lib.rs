use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use uuid::Uuid;

pub const GENESIS_HASH: &str = "KANI_GENESIS_V1";
pub const SANDBOX_TREASURY_ACCOUNT: &str = "TREASURY_SANDBOX";
pub const SANDBOX_CORP_A_ACCOUNT: &str = "CORP_A";
pub const SANDBOX_CORP_B_ACCOUNT: &str = "CORP_B";
pub const SANDBOX_FEE_ACCOUNT: &str = "FEE_SANDBOX";
pub const SANDBOX_TREASURY_INSTITUTION: &str = "KANI_TREASURY";
pub const SANDBOX_CORP_A_INSTITUTION: &str = "CORP_A";
pub const SANDBOX_CORP_B_INSTITUTION: &str = "CORP_B";
pub const SANDBOX_NETWORK_INSTITUTION: &str = "KANI";

pub const KCAD_TEST: &str = "KCAD_TEST";
pub const KUSD_TEST: &str = "KUSD_TEST";

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AccountType {
    Treasury,
    Institution,
    Settlement,
    Fee,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Account {
    pub id: String,
    pub account_type: AccountType,
    pub institution_id: Option<String>,
    pub created_at: DateTime<Utc>,
}

impl Account {
    pub fn new(
        id: impl Into<String>,
        account_type: AccountType,
        institution_id: Option<String>,
    ) -> Self {
        Self {
            id: id.into(),
            account_type,
            institution_id,
            created_at: Utc::now(),
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum InstitutionStatus {
    Requested,
    DueDiligence,
    Approved,
    Rejected,
    Suspended,
    Offboarded,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum InstitutionRiskTier {
    Low,
    Medium,
    High,
    Restricted,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum InstitutionRole {
    Operator,
    Approver,
    Auditor,
    ComplianceReviewer,
    TechnicalAdmin,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct InstitutionDefinition {
    pub id: String,
    pub legal_name: String,
    pub institution_code: String,
    pub jurisdiction: String,
    pub status: InstitutionStatus,
    pub risk_tier: InstitutionRiskTier,
    pub allowed_assets: Vec<String>,
    pub roles: Vec<InstitutionRole>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Institution {
    pub id: String,
    pub legal_name: String,
    pub institution_code: String,
    pub jurisdiction: String,
    pub status: InstitutionStatus,
    pub risk_tier: InstitutionRiskTier,
    pub allowed_assets: Vec<String>,
    pub roles: Vec<InstitutionRole>,
    pub created_at: DateTime<Utc>,
    pub approved_at: Option<DateTime<Utc>>,
    pub suspended_at: Option<DateTime<Utc>>,
    pub updated_at: DateTime<Utc>,
}

impl Institution {
    pub fn new(definition: InstitutionDefinition) -> Self {
        let now = Utc::now();
        let status = definition.status;
        Self {
            id: definition.id,
            legal_name: definition.legal_name,
            institution_code: definition.institution_code,
            jurisdiction: definition.jurisdiction,
            status,
            risk_tier: definition.risk_tier,
            allowed_assets: definition.allowed_assets,
            roles: definition.roles,
            created_at: now,
            approved_at: (status == InstitutionStatus::Approved).then_some(now),
            suspended_at: (status == InstitutionStatus::Suspended).then_some(now),
            updated_at: now,
        }
    }

    pub fn sandbox_approved(
        id: impl Into<String>,
        legal_name: impl Into<String>,
        institution_code: impl Into<String>,
    ) -> Self {
        Self::new(InstitutionDefinition {
            id: id.into(),
            legal_name: legal_name.into(),
            institution_code: institution_code.into(),
            jurisdiction: "CA".to_string(),
            status: InstitutionStatus::Approved,
            risk_tier: InstitutionRiskTier::Low,
            allowed_assets: vec![KCAD_TEST.to_string(), KUSD_TEST.to_string()],
            roles: vec![
                InstitutionRole::Operator,
                InstitutionRole::Auditor,
                InstitutionRole::TechnicalAdmin,
            ],
        })
    }

    pub fn suspended(mut self) -> Self {
        let now = Utc::now();
        self.status = InstitutionStatus::Suspended;
        self.suspended_at = Some(now);
        self.updated_at = now;
        self
    }

    pub fn with_limits_update(mut self) -> Self {
        self.updated_at = Utc::now();
        self
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum InstitutionCredentialType {
    SandboxApiKey,
    MtlsCertificate,
    OidcClient,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum InstitutionCredentialStatus {
    Pending,
    Active,
    Retired,
    Revoked,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct InstitutionCredential {
    pub id: String,
    pub institution_id: String,
    pub credential_type: InstitutionCredentialType,
    pub label: String,
    pub fingerprint: String,
    pub issuer: Option<String>,
    pub subject: Option<String>,
    pub expires_at: Option<DateTime<Utc>>,
    pub status: InstitutionCredentialStatus,
    pub created_at: DateTime<Utc>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub revocation_reason: Option<String>,
}

impl InstitutionCredential {
    pub fn new(
        institution_id: impl Into<String>,
        credential_type: InstitutionCredentialType,
        label: impl Into<String>,
        fingerprint: impl Into<String>,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            institution_id: institution_id.into(),
            credential_type,
            label: label.into(),
            fingerprint: fingerprint.into(),
            issuer: None,
            subject: None,
            expires_at: None,
            status: InstitutionCredentialStatus::Active,
            created_at: Utc::now(),
            revoked_at: None,
            revocation_reason: None,
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct InstitutionLimit {
    pub institution_id: String,
    pub asset: String,
    pub daily_limit: i128,
    pub per_transaction_limit: i128,
    pub updated_at: DateTime<Utc>,
}

impl InstitutionLimit {
    pub fn new(
        institution_id: impl Into<String>,
        asset: impl Into<String>,
        daily_limit: i128,
        per_transaction_limit: i128,
    ) -> Self {
        Self {
            institution_id: institution_id.into(),
            asset: asset.into(),
            daily_limit,
            per_transaction_limit,
            updated_at: Utc::now(),
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum OnboardingCaseStatus {
    Requested,
    DueDiligence,
    Approved,
    Rejected,
    Suspended,
    Offboarded,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct OnboardingCase {
    pub id: String,
    pub institution_id: String,
    pub status: OnboardingCaseStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl OnboardingCase {
    pub fn new(institution_id: impl Into<String>, status: OnboardingCaseStatus) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            institution_id: institution_id.into(),
            status,
            created_at: now,
            updated_at: now,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ComplianceCaseStatus {
    Opened,
    Assigned,
    EvidenceRequested,
    Escalated,
    Approved,
    Rejected,
    Closed,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ComplianceCase {
    pub id: String,
    pub payment_id: String,
    pub status: ComplianceCaseStatus,
    pub policy_version: String,
    pub rule_id: String,
    pub reason: String,
    pub opened_by_institution: String,
    pub assigned_to: Option<String>,
    pub reviewer: Option<String>,
    pub resolution_reason: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ComplianceCaseOpen {
    pub payment_id: String,
    pub policy_version: String,
    pub rule_id: String,
    pub reason: String,
    pub opened_by_institution: String,
}

impl ComplianceCase {
    pub fn opened(request: ComplianceCaseOpen) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            payment_id: request.payment_id,
            status: ComplianceCaseStatus::Opened,
            policy_version: request.policy_version,
            rule_id: request.rule_id,
            reason: request.reason,
            opened_by_institution: request.opened_by_institution,
            assigned_to: None,
            reviewer: None,
            resolution_reason: None,
            created_at: now,
            updated_at: now,
            resolved_at: None,
        }
    }

    pub fn approved(mut self, reviewer: Option<String>, reason: Option<String>) -> Self {
        let now = Utc::now();
        self.status = ComplianceCaseStatus::Approved;
        self.reviewer = reviewer;
        self.resolution_reason = reason;
        self.updated_at = now;
        self.resolved_at = Some(now);
        self
    }

    pub fn rejected(mut self, reviewer: Option<String>, reason: Option<String>) -> Self {
        let now = Utc::now();
        self.status = ComplianceCaseStatus::Rejected;
        self.reviewer = reviewer;
        self.resolution_reason = reason;
        self.updated_at = now;
        self.resolved_at = Some(now);
        self
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TransactionKind {
    Mint,
    Burn,
    Transfer,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Transaction {
    pub id: String,
    pub from: String,
    pub to: String,
    pub asset: String,
    pub amount: i128,
    pub nonce: i64,
    pub signatures: Vec<Vec<u8>>,
    pub kind: TransactionKind,
    pub metadata: BTreeMap<String, String>,
    pub created_at: DateTime<Utc>,
}

impl Transaction {
    pub fn new_transfer(
        from: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
        nonce: i64,
    ) -> Self {
        Self::new(TransactionKind::Transfer, from, to, asset, amount, nonce)
    }

    pub fn new_mint(
        treasury: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
        nonce: i64,
    ) -> Self {
        Self::new(TransactionKind::Mint, treasury, to, asset, amount, nonce)
    }

    pub fn new_burn(
        from: impl Into<String>,
        treasury: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
        nonce: i64,
    ) -> Self {
        Self::new(TransactionKind::Burn, from, treasury, asset, amount, nonce)
    }

    fn new(
        kind: TransactionKind,
        from: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
        nonce: i64,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            from: from.into(),
            to: to.into(),
            asset: asset.into(),
            amount,
            nonce,
            signatures: Vec::new(),
            kind,
            metadata: BTreeMap::new(),
            created_at: Utc::now(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TransactionStatus {
    Pending,
    Held,
    Finalized,
    Rejected,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct PaymentRecord {
    pub transaction: Transaction,
    pub status: TransactionStatus,
    pub block_height: Option<i64>,
    pub block_hash: Option<String>,
    pub failure_reason: Option<String>,
    pub client_reference_id: Option<String>,
    pub request_fingerprint: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl PaymentRecord {
    pub fn pending(transaction: Transaction) -> Self {
        let now = Utc::now();
        let client_reference_id = client_reference_id_from(&transaction);
        let request_fingerprint = request_fingerprint_from(&transaction);
        Self {
            transaction,
            status: TransactionStatus::Pending,
            block_height: None,
            block_hash: None,
            failure_reason: None,
            client_reference_id,
            request_fingerprint,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn finalized(transaction: Transaction, block_height: i64, block_hash: String) -> Self {
        let now = Utc::now();
        let client_reference_id = client_reference_id_from(&transaction);
        let request_fingerprint = request_fingerprint_from(&transaction);
        Self {
            transaction,
            status: TransactionStatus::Finalized,
            block_height: Some(block_height),
            block_hash: Some(block_hash),
            failure_reason: None,
            client_reference_id,
            request_fingerprint,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn held(transaction: Transaction, reason: impl Into<String>) -> Self {
        let now = Utc::now();
        let client_reference_id = client_reference_id_from(&transaction);
        let request_fingerprint = request_fingerprint_from(&transaction);
        Self {
            transaction,
            status: TransactionStatus::Held,
            block_height: None,
            block_hash: None,
            failure_reason: Some(reason.into()),
            client_reference_id,
            request_fingerprint,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn rejected(transaction: Transaction, reason: impl Into<String>) -> Self {
        let now = Utc::now();
        let client_reference_id = client_reference_id_from(&transaction);
        let request_fingerprint = request_fingerprint_from(&transaction);
        Self {
            transaction,
            status: TransactionStatus::Rejected,
            block_height: None,
            block_hash: None,
            failure_reason: Some(reason.into()),
            client_reference_id,
            request_fingerprint,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn with_client_reference_id(mut self, client_reference_id: Option<String>) -> Self {
        self.client_reference_id = client_reference_id;
        self
    }

    pub fn with_request_fingerprint(mut self, request_fingerprint: Option<String>) -> Self {
        self.request_fingerprint = request_fingerprint;
        self
    }

    pub fn mark_pending(mut self) -> Self {
        self.status = TransactionStatus::Pending;
        self.failure_reason = None;
        self.updated_at = Utc::now();
        self
    }

    pub fn mark_rejected(mut self, reason: impl Into<String>) -> Self {
        self.status = TransactionStatus::Rejected;
        self.failure_reason = Some(reason.into());
        self.updated_at = Utc::now();
        self
    }
}

fn client_reference_id_from(transaction: &Transaction) -> Option<String> {
    transaction.metadata.get("client_reference_id").cloned()
}

fn request_fingerprint_from(transaction: &Transaction) -> Option<String> {
    transaction.metadata.get("request_fingerprint").cloned()
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum JournalDirection {
    Debit,
    Credit,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct JournalEntry {
    pub id: String,
    pub transaction_id: String,
    pub account_id: String,
    pub asset: String,
    pub amount: i128,
    pub direction: JournalDirection,
    pub block_height: i64,
    pub created_at: DateTime<Utc>,
}

impl JournalEntry {
    pub fn new(
        transaction_id: impl Into<String>,
        account_id: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
        direction: JournalDirection,
        block_height: i64,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            transaction_id: transaction_id.into(),
            account_id: account_id.into(),
            asset: asset.into(),
            amount,
            direction,
            block_height,
            created_at: Utc::now(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Block {
    pub height: i64,
    pub prev_hash: String,
    pub txs: Vec<Transaction>,
    pub validator: String,
    pub signature: Vec<u8>,
    pub hash: String,
    pub finalized_by: Vec<String>,
    pub created_at: DateTime<Utc>,
}

impl Block {
    pub fn new_unsealed(
        height: i64,
        prev_hash: impl Into<String>,
        txs: Vec<Transaction>,
        validator: impl Into<String>,
    ) -> Self {
        Self {
            height,
            prev_hash: prev_hash.into(),
            txs,
            validator: validator.into(),
            signature: Vec::new(),
            hash: String::new(),
            finalized_by: Vec::new(),
            created_at: Utc::now(),
        }
    }

    pub fn seal(
        mut self,
        hash: impl Into<String>,
        signature: Vec<u8>,
        finalized_by: Vec<String>,
    ) -> Self {
        self.hash = hash.into();
        self.signature = signature;
        self.finalized_by = finalized_by;
        self
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct AuditEvent {
    pub id: String,
    pub event_type: String,
    pub message: String,
    pub metadata: BTreeMap<String, String>,
    pub block_height: Option<i64>,
    pub transaction_id: Option<String>,
    pub created_at: DateTime<Utc>,
}

impl AuditEvent {
    pub fn new(
        event_type: impl Into<String>,
        message: impl Into<String>,
        block_height: Option<i64>,
        transaction_id: Option<String>,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            event_type: event_type.into(),
            message: message.into(),
            metadata: BTreeMap::new(),
            block_height,
            transaction_id,
            created_at: Utc::now(),
        }
    }

    pub fn with_metadata(mut self, metadata: BTreeMap<String, String>) -> Self {
        self.metadata = metadata;
        self
    }
}
