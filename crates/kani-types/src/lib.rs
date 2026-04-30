use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use uuid::Uuid;

pub const GENESIS_HASH: &str = "KANI_GENESIS_V1";
pub const SANDBOX_TREASURY_ACCOUNT: &str = "TREASURY_SANDBOX";
pub const SANDBOX_CORP_A_ACCOUNT: &str = "CORP_A";
pub const SANDBOX_CORP_B_ACCOUNT: &str = "CORP_B";
pub const SANDBOX_FEE_ACCOUNT: &str = "FEE_SANDBOX";

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
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl PaymentRecord {
    pub fn pending(transaction: Transaction) -> Self {
        let now = Utc::now();
        Self {
            transaction,
            status: TransactionStatus::Pending,
            block_height: None,
            block_hash: None,
            failure_reason: None,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn finalized(transaction: Transaction, block_height: i64, block_hash: String) -> Self {
        let now = Utc::now();
        Self {
            transaction,
            status: TransactionStatus::Finalized,
            block_height: Some(block_height),
            block_hash: Some(block_hash),
            failure_reason: None,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn rejected(transaction: Transaction, reason: impl Into<String>) -> Self {
        let now = Utc::now();
        Self {
            transaction,
            status: TransactionStatus::Rejected,
            block_height: None,
            block_hash: None,
            failure_reason: Some(reason.into()),
            created_at: now,
            updated_at: now,
        }
    }
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
            block_height,
            transaction_id,
            created_at: Utc::now(),
        }
    }
}
