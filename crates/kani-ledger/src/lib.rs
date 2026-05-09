use chrono::{DateTime, Utc};
use kani_types::{
    Account, AccountType, AuditEvent, Block, ComplianceCase, ComplianceCaseOpen,
    ComplianceCaseStatus, Institution, InstitutionCredential, InstitutionCredentialStatus,
    InstitutionCredentialType, InstitutionLimit, InstitutionRiskTier, InstitutionRole,
    InstitutionStatus, JournalDirection, JournalEntry, PaymentRecord, Transaction, TransactionKind,
    TransactionStatus, GENESIS_HASH, KCAD_TEST, KUSD_TEST, SANDBOX_CORP_A_ACCOUNT,
    SANDBOX_CORP_A_INSTITUTION, SANDBOX_CORP_B_ACCOUNT, SANDBOX_CORP_B_INSTITUTION,
    SANDBOX_FEE_ACCOUNT, SANDBOX_NETWORK_INSTITUTION, SANDBOX_TREASURY_ACCOUNT,
    SANDBOX_TREASURY_INSTITUTION,
};
use serde_json::Value;
use sqlx::{pool::PoolConnection, postgres::PgPoolOptions, PgPool, Postgres, QueryBuilder, Row};
use std::{collections::HashMap, path::Path};
use thiserror::Error;

const BLOCK_PRODUCTION_LOCK_ID: i64 = 0x4B414E49504F4131_i64;

#[derive(Debug, Error)]
pub enum LedgerError {
    #[error("account {0} does not exist")]
    UnknownAccount(String),
    #[error("institution {0} does not exist")]
    UnknownInstitution(String),
    #[error("payment {0} does not exist")]
    UnknownPayment(String),
    #[error("compliance case {0} does not exist")]
    UnknownComplianceCase(String),
    #[error("compliance case {case_id} is already terminal with status {status}")]
    TerminalComplianceCase { case_id: String, status: String },
    #[error("asset code is required")]
    MissingAsset,
    #[error("amount must be positive")]
    InvalidAmount,
    #[error("transaction nonce must be greater than the last finalized nonce")]
    InvalidNonce,
    #[error(
        "account {account_id} has insufficient {asset}: available {available}, required {required}"
    )]
    InsufficientFunds {
        account_id: String,
        asset: String,
        available: i128,
        required: i128,
    },
    #[error("mint transactions must originate from a treasury account")]
    MintRequiresTreasury,
    #[error("burn transactions must settle to a treasury account")]
    BurnRequiresTreasury,
    #[error("block height mismatch: expected {expected}, got {actual}")]
    InvalidBlockHeight { expected: i64, actual: i64 },
    #[error("block prev_hash mismatch: expected {expected}, got {actual}")]
    InvalidPrevHash { expected: String, actual: String },
    #[error("block hash is required before finalization")]
    MissingBlockHash,
}

#[derive(Debug, Error)]
pub enum LedgerStorageError {
    #[error(transparent)]
    Sqlx(#[from] sqlx::Error),
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
    #[error("failed to parse persisted amount {value}: {source}")]
    ParseAmount {
        value: String,
        source: std::num::ParseIntError,
    },
    #[error("unknown account type {0}")]
    UnknownAccountType(String),
    #[error("unknown institution status {0}")]
    UnknownInstitutionStatus(String),
    #[error("unknown institution risk tier {0}")]
    UnknownInstitutionRiskTier(String),
    #[error("unknown institution role {0}")]
    UnknownInstitutionRole(String),
    #[error("unknown institution credential type {0}")]
    UnknownInstitutionCredentialType(String),
    #[error("unknown institution credential status {0}")]
    UnknownInstitutionCredentialStatus(String),
    #[error("unknown transaction kind {0}")]
    UnknownTransactionKind(String),
    #[error("unknown transaction status {0}")]
    UnknownTransactionStatus(String),
    #[error("unknown compliance case status {0}")]
    UnknownComplianceCaseStatus(String),
    #[error("payment {0} does not exist")]
    UnknownPayment(String),
    #[error("compliance case {0} does not exist")]
    UnknownComplianceCase(String),
    #[error("compliance case {case_id} is already terminal with status {status}")]
    TerminalComplianceCase { case_id: String, status: String },
    #[error("unknown journal direction {0}")]
    UnknownJournalDirection(String),
    #[error("migration failed: {0}")]
    Migration(String),
    #[error("failed to release block production advisory lock")]
    AdvisoryLockReleaseFailed,
    #[error("idempotency key {client_reference_id} was already used for payment {payment_id}")]
    IdempotencyConflict {
        client_reference_id: String,
        payment_id: String,
    },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Balance {
    pub account_id: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ValidatorStatus {
    pub validator_id: String,
    pub last_seen_at: DateTime<Utc>,
    pub last_finalized_height: Option<i64>,
    pub last_finalized_hash: Option<String>,
    pub last_finalized_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BlockSearch {
    pub limit: i64,
    pub offset: i64,
}

impl BlockSearch {
    pub fn apply(&self, blocks: Vec<Block>) -> Vec<Block> {
        let limit = usize::try_from(self.limit.max(0)).unwrap_or(usize::MAX);
        let offset = usize::try_from(self.offset.max(0)).unwrap_or(usize::MAX);

        blocks.into_iter().skip(offset).take(limit).collect()
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct JournalEntrySearch {
    pub account_id: String,
    pub asset: Option<String>,
    pub limit: i64,
    pub offset: i64,
}

impl JournalEntrySearch {
    pub fn apply(&self, entries: Vec<JournalEntry>) -> Vec<JournalEntry> {
        let limit = usize::try_from(self.limit.max(0)).unwrap_or(usize::MAX);
        let offset = usize::try_from(self.offset.max(0)).unwrap_or(usize::MAX);

        entries
            .into_iter()
            .filter(|entry| self.matches(entry))
            .skip(offset)
            .take(limit)
            .collect()
    }

    fn matches(&self, entry: &JournalEntry) -> bool {
        if entry.account_id != self.account_id {
            return false;
        }

        if let Some(asset) = &self.asset {
            if entry.asset != *asset {
                return false;
            }
        }

        true
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AuditEventSearch {
    pub event_type: Option<String>,
    pub decision: Option<String>,
    pub institution_id: Option<String>,
    pub created_from: Option<DateTime<Utc>>,
    pub created_to: Option<DateTime<Utc>>,
    pub limit: i64,
    pub offset: i64,
}

impl AuditEventSearch {
    pub fn apply(&self, events: Vec<AuditEvent>) -> Vec<AuditEvent> {
        let limit = usize::try_from(self.limit.max(0)).unwrap_or(usize::MAX);
        let offset = usize::try_from(self.offset.max(0)).unwrap_or(usize::MAX);

        events
            .into_iter()
            .filter(|event| self.matches(event))
            .skip(offset)
            .take(limit)
            .collect()
    }

    fn matches(&self, event: &AuditEvent) -> bool {
        if let Some(event_type) = &self.event_type {
            if !event.event_type.eq_ignore_ascii_case(event_type) {
                return false;
            }
        }

        if let Some(decision) = &self.decision {
            if !metadata_matches_ignore_case(event, "decision", decision) {
                return false;
            }
        }

        if let Some(institution_id) = &self.institution_id {
            if !metadata_matches(event, "institution_id", institution_id) {
                return false;
            }
        }

        if let Some(created_from) = self.created_from {
            if event.created_at < created_from {
                return false;
            }
        }

        if let Some(created_to) = self.created_to {
            if event.created_at > created_to {
                return false;
            }
        }

        true
    }
}

#[derive(Clone, Debug, Default)]
pub struct LedgerSnapshot {
    pub accounts: Vec<Account>,
    pub institutions: Vec<Institution>,
    pub institution_credentials: Vec<InstitutionCredential>,
    pub institution_limits: Vec<InstitutionLimit>,
    pub balances: Vec<Balance>,
    pub payments: Vec<PaymentRecord>,
    pub compliance_cases: Vec<ComplianceCase>,
    pub blocks: Vec<Block>,
    pub audit_events: Vec<AuditEvent>,
    pub journal_entries: Vec<JournalEntry>,
    pub nonces: HashMap<String, i64>,
    pub issued: HashMap<String, i128>,
}

#[derive(Clone, Debug)]
pub struct InMemoryLedger {
    accounts: HashMap<String, Account>,
    institutions: HashMap<String, Institution>,
    institution_credentials: HashMap<String, InstitutionCredential>,
    institution_limits: HashMap<(String, String), InstitutionLimit>,
    balances: HashMap<(String, String), i128>,
    payments: HashMap<String, PaymentRecord>,
    compliance_cases: HashMap<String, ComplianceCase>,
    blocks: Vec<Block>,
    audit_events: Vec<AuditEvent>,
    journal_entries: Vec<JournalEntry>,
    nonces: HashMap<String, i64>,
    issued: HashMap<String, i128>,
}

impl InMemoryLedger {
    pub fn empty() -> Self {
        Self {
            accounts: HashMap::new(),
            institutions: HashMap::new(),
            institution_credentials: HashMap::new(),
            institution_limits: HashMap::new(),
            balances: HashMap::new(),
            payments: HashMap::new(),
            compliance_cases: HashMap::new(),
            blocks: Vec::new(),
            audit_events: Vec::new(),
            journal_entries: Vec::new(),
            nonces: HashMap::new(),
            issued: HashMap::new(),
        }
    }

    pub fn from_snapshot(snapshot: LedgerSnapshot) -> Self {
        Self {
            accounts: snapshot
                .accounts
                .into_iter()
                .map(|account| (account.id.clone(), account))
                .collect(),
            institutions: snapshot
                .institutions
                .into_iter()
                .map(|institution| (institution.id.clone(), institution))
                .collect(),
            institution_credentials: snapshot
                .institution_credentials
                .into_iter()
                .map(|credential| (credential.id.clone(), credential))
                .collect(),
            institution_limits: snapshot
                .institution_limits
                .into_iter()
                .map(|limit| ((limit.institution_id.clone(), limit.asset.clone()), limit))
                .collect(),
            balances: snapshot
                .balances
                .into_iter()
                .map(|balance| ((balance.account_id, balance.asset), balance.amount))
                .collect(),
            payments: snapshot
                .payments
                .into_iter()
                .map(|payment| (payment.transaction.id.clone(), payment))
                .collect(),
            compliance_cases: snapshot
                .compliance_cases
                .into_iter()
                .map(|compliance_case| (compliance_case.id.clone(), compliance_case))
                .collect(),
            blocks: snapshot.blocks,
            audit_events: snapshot.audit_events,
            journal_entries: snapshot.journal_entries,
            nonces: snapshot.nonces,
            issued: snapshot.issued,
        }
    }

    pub fn snapshot(&self) -> LedgerSnapshot {
        LedgerSnapshot {
            accounts: self.accounts(),
            institutions: self.institutions(),
            institution_credentials: self.institution_credentials(None),
            institution_limits: self.institution_limits.values().cloned().collect(),
            balances: self
                .balances
                .iter()
                .map(|((account_id, asset), amount)| Balance {
                    account_id: account_id.clone(),
                    asset: asset.clone(),
                    amount: *amount,
                })
                .collect(),
            payments: self.payments.values().cloned().collect(),
            compliance_cases: self.compliance_cases.values().cloned().collect(),
            blocks: self.blocks.clone(),
            audit_events: self.audit_events.clone(),
            journal_entries: self.journal_entries.clone(),
            nonces: self.nonces.clone(),
            issued: self.issued.clone(),
        }
    }

    pub fn is_pristine(&self) -> bool {
        self.blocks.is_empty()
            && self.payments.is_empty()
            && self.audit_events.is_empty()
            && self.journal_entries.is_empty()
    }

    pub fn sandbox() -> Self {
        let mut ledger = Self::empty();
        ledger.upsert_institution(Institution::sandbox_approved(
            SANDBOX_TREASURY_INSTITUTION,
            "KANI Sandbox Treasury",
            SANDBOX_TREASURY_INSTITUTION,
        ));
        ledger.upsert_institution(Institution::sandbox_approved(
            SANDBOX_CORP_A_INSTITUTION,
            "Sandbox Corporation A",
            SANDBOX_CORP_A_INSTITUTION,
        ));
        ledger.upsert_institution(Institution::sandbox_approved(
            SANDBOX_CORP_B_INSTITUTION,
            "Sandbox Corporation B",
            SANDBOX_CORP_B_INSTITUTION,
        ));
        ledger.upsert_institution(Institution::sandbox_approved(
            SANDBOX_NETWORK_INSTITUTION,
            "KANI Network Sandbox Operator",
            SANDBOX_NETWORK_INSTITUTION,
        ));
        ledger.upsert_account(Account::new(
            SANDBOX_TREASURY_ACCOUNT,
            AccountType::Treasury,
            Some(SANDBOX_TREASURY_INSTITUTION.to_string()),
        ));
        ledger.upsert_account(Account::new(
            SANDBOX_CORP_A_ACCOUNT,
            AccountType::Institution,
            Some(SANDBOX_CORP_A_INSTITUTION.to_string()),
        ));
        ledger.upsert_account(Account::new(
            SANDBOX_CORP_B_ACCOUNT,
            AccountType::Institution,
            Some(SANDBOX_CORP_B_INSTITUTION.to_string()),
        ));
        ledger.upsert_account(Account::new(
            SANDBOX_FEE_ACCOUNT,
            AccountType::Fee,
            Some(SANDBOX_NETWORK_INSTITUTION.to_string()),
        ));
        ledger.ensure_balance_row(SANDBOX_TREASURY_ACCOUNT, KCAD_TEST);
        ledger.ensure_balance_row(SANDBOX_CORP_A_ACCOUNT, KCAD_TEST);
        ledger.ensure_balance_row(SANDBOX_CORP_B_ACCOUNT, KCAD_TEST);
        ledger.ensure_balance_row(SANDBOX_TREASURY_ACCOUNT, KUSD_TEST);
        ledger.ensure_balance_row(SANDBOX_CORP_A_ACCOUNT, KUSD_TEST);
        ledger.ensure_balance_row(SANDBOX_CORP_B_ACCOUNT, KUSD_TEST);
        ledger
    }

    pub fn upsert_account(&mut self, account: Account) {
        self.accounts.insert(account.id.clone(), account);
    }

    pub fn accounts(&self) -> Vec<Account> {
        self.accounts.values().cloned().collect()
    }

    pub fn upsert_institution(&mut self, institution: Institution) {
        self.institutions
            .insert(institution.id.clone(), institution);
    }

    pub fn institutions(&self) -> Vec<Institution> {
        let mut institutions: Vec<_> = self.institutions.values().cloned().collect();
        institutions.sort_by(|left, right| left.id.cmp(&right.id));
        institutions
    }

    pub fn get_institution(&self, institution_id: &str) -> Result<Institution, LedgerError> {
        self.institutions
            .get(institution_id)
            .cloned()
            .ok_or_else(|| LedgerError::UnknownInstitution(institution_id.to_string()))
    }

    pub fn suspend_institution(
        &mut self,
        institution_id: &str,
    ) -> Result<Institution, LedgerError> {
        let institution = self.get_institution(institution_id)?.suspended();
        self.upsert_institution(institution.clone());
        Ok(institution)
    }

    pub fn upsert_institution_limit(
        &mut self,
        limit: InstitutionLimit,
    ) -> Result<InstitutionLimit, LedgerError> {
        self.get_institution(&limit.institution_id)?;
        self.institution_limits.insert(
            (limit.institution_id.clone(), limit.asset.clone()),
            limit.clone(),
        );
        Ok(limit)
    }

    pub fn institution_limits(
        &self,
        institution_id: &str,
    ) -> Result<Vec<InstitutionLimit>, LedgerError> {
        self.get_institution(institution_id)?;
        let mut limits: Vec<_> = self
            .institution_limits
            .values()
            .filter(|limit| limit.institution_id == institution_id)
            .cloned()
            .collect();
        limits.sort_by(|left, right| left.asset.cmp(&right.asset));
        Ok(limits)
    }

    pub fn add_institution_credential(
        &mut self,
        credential: InstitutionCredential,
    ) -> Result<InstitutionCredential, LedgerError> {
        self.get_institution(&credential.institution_id)?;
        self.institution_credentials
            .insert(credential.id.clone(), credential.clone());
        Ok(credential)
    }

    pub fn institution_credentials(
        &self,
        institution_id: Option<&str>,
    ) -> Vec<InstitutionCredential> {
        let mut credentials: Vec<_> = self
            .institution_credentials
            .values()
            .filter(|credential| {
                institution_id
                    .map(|institution_id| credential.institution_id == institution_id)
                    .unwrap_or(true)
            })
            .cloned()
            .collect();
        credentials.sort_by(|left, right| left.id.cmp(&right.id));
        credentials
    }

    pub fn latest_block(&self) -> Option<Block> {
        self.blocks.last().cloned()
    }

    pub fn blocks(&self) -> &[Block] {
        &self.blocks
    }

    pub fn audit_events(&self) -> &[AuditEvent] {
        &self.audit_events
    }

    pub fn record_audit_event(&mut self, event: AuditEvent) {
        self.audit_events.push(event);
    }

    pub fn journal_entries(&self) -> &[JournalEntry] {
        &self.journal_entries
    }

    pub fn next_height(&self) -> i64 {
        self.blocks.len() as i64 + 1
    }

    pub fn last_hash(&self) -> String {
        self.blocks
            .last()
            .map(|block| block.hash.clone())
            .unwrap_or_else(|| GENESIS_HASH.to_string())
    }

    pub fn next_nonce(&self, account_id: &str) -> i64 {
        self.nonces.get(account_id).copied().unwrap_or_default() + 1
    }

    pub fn balance(&self, account_id: &str, asset: &str) -> i128 {
        balance_from(&self.balances, account_id, asset)
    }

    pub fn issued(&self, asset: &str) -> i128 {
        self.issued.get(asset).copied().unwrap_or_default()
    }

    pub fn get_payment(&self, payment_id: &str) -> Result<PaymentRecord, LedgerError> {
        self.payments
            .get(payment_id)
            .cloned()
            .ok_or_else(|| LedgerError::UnknownPayment(payment_id.to_string()))
    }

    pub fn get_payment_by_client_reference_id(
        &self,
        client_reference_id: &str,
    ) -> Option<PaymentRecord> {
        self.payments
            .values()
            .find(|payment| payment.client_reference_id.as_deref() == Some(client_reference_id))
            .cloned()
    }

    pub fn hold_payment_for_review(
        &mut self,
        payment: PaymentRecord,
        case_open: ComplianceCaseOpen,
    ) -> Result<(PaymentRecord, ComplianceCase), LedgerError> {
        let compliance_case = ComplianceCase::opened(case_open);
        self.payments
            .insert(payment.transaction.id.clone(), payment.clone());
        self.compliance_cases
            .insert(compliance_case.id.clone(), compliance_case.clone());
        Ok((payment, compliance_case))
    }

    pub fn compliance_cases(&self) -> Vec<ComplianceCase> {
        let mut cases: Vec<_> = self.compliance_cases.values().cloned().collect();
        cases.sort_by_key(|compliance_case| compliance_case.created_at);
        cases
    }

    pub fn get_compliance_case(&self, case_id: &str) -> Result<ComplianceCase, LedgerError> {
        self.compliance_cases
            .get(case_id)
            .cloned()
            .ok_or_else(|| LedgerError::UnknownComplianceCase(case_id.to_string()))
    }

    pub fn pending_transactions(&self, limit: i64, offset: i64) -> Vec<Transaction> {
        let limit = usize::try_from(limit.max(0)).unwrap_or(usize::MAX);
        let offset = usize::try_from(offset.max(0)).unwrap_or(usize::MAX);

        let mut payments: Vec<_> = self
            .payments
            .values()
            .filter(|payment| payment.status == TransactionStatus::Pending)
            .cloned()
            .collect();
        payments.sort_by_key(|payment| payment.created_at);

        payments
            .into_iter()
            .skip(offset)
            .take(limit)
            .map(|payment| payment.transaction)
            .collect()
    }

    pub fn approve_compliance_case(
        &mut self,
        case_id: &str,
        reviewer: Option<String>,
        reason: Option<String>,
    ) -> Result<(ComplianceCase, PaymentRecord), LedgerError> {
        let compliance_case = self.get_compliance_case(case_id)?;
        ensure_case_not_terminal(&compliance_case)?;

        let payment = self
            .get_payment(&compliance_case.payment_id)?
            .mark_pending();
        let compliance_case = compliance_case.approved(reviewer, reason);

        self.payments
            .insert(payment.transaction.id.clone(), payment.clone());
        self.compliance_cases
            .insert(compliance_case.id.clone(), compliance_case.clone());

        Ok((compliance_case, payment))
    }

    pub fn reject_compliance_case(
        &mut self,
        case_id: &str,
        reviewer: Option<String>,
        reason: Option<String>,
    ) -> Result<(ComplianceCase, PaymentRecord), LedgerError> {
        let compliance_case = self.get_compliance_case(case_id)?;
        ensure_case_not_terminal(&compliance_case)?;
        let rejection_reason = reason
            .clone()
            .unwrap_or_else(|| "compliance case rejected".to_string());
        let payment = self
            .get_payment(&compliance_case.payment_id)?
            .mark_rejected(rejection_reason);
        let compliance_case = compliance_case.rejected(reviewer, reason);

        self.payments
            .insert(payment.transaction.id.clone(), payment.clone());
        self.compliance_cases
            .insert(compliance_case.id.clone(), compliance_case.clone());

        Ok((compliance_case, payment))
    }

    pub fn apply_block(&mut self, block: Block) -> Result<Vec<PaymentRecord>, LedgerError> {
        if block.hash.is_empty() {
            return Err(LedgerError::MissingBlockHash);
        }

        let expected_height = self.next_height();
        if block.height != expected_height {
            return Err(LedgerError::InvalidBlockHeight {
                expected: expected_height,
                actual: block.height,
            });
        }

        let expected_prev_hash = self.last_hash();
        if block.prev_hash != expected_prev_hash {
            return Err(LedgerError::InvalidPrevHash {
                expected: expected_prev_hash,
                actual: block.prev_hash.clone(),
            });
        }

        let mut working_balances = self.balances.clone();
        let mut working_nonces = self.nonces.clone();
        let mut working_issued = self.issued.clone();
        let mut working_journal = self.journal_entries.clone();
        let mut records = Vec::with_capacity(block.txs.len());

        for tx in &block.txs {
            self.validate_transaction(tx, &working_balances, &working_nonces, &working_issued)?;
            apply_transaction(
                tx,
                block.height,
                &mut working_balances,
                &mut working_nonces,
                &mut working_issued,
                &mut working_journal,
            )?;

            records.push(PaymentRecord::finalized(
                tx.clone(),
                block.height,
                block.hash.clone(),
            ));
        }

        self.balances = working_balances;
        self.nonces = working_nonces;
        self.issued = working_issued;
        self.journal_entries = working_journal;

        for record in &records {
            self.payments
                .insert(record.transaction.id.clone(), record.clone());
            self.audit_events.push(AuditEvent::new(
                "TRANSACTION_FINALIZED",
                format!(
                    "{} {} finalized in block {}",
                    record.transaction.amount, record.transaction.asset, block.height
                ),
                Some(block.height),
                Some(record.transaction.id.clone()),
            ));
        }

        self.audit_events.push(AuditEvent::new(
            "BLOCK_FINALIZED",
            format!(
                "block {} finalized by {} validator votes",
                block.height,
                block.finalized_by.len()
            ),
            Some(block.height),
            None,
        ));
        self.blocks.push(block);

        Ok(records)
    }

    pub fn validate_transactions_for_next_block(
        &self,
        txs: &[Transaction],
    ) -> Result<(), LedgerError> {
        let mut working_balances = self.balances.clone();
        let mut working_nonces = self.nonces.clone();
        let mut working_issued = self.issued.clone();
        let mut working_journal = self.journal_entries.clone();
        let block_height = self.next_height();

        for tx in txs {
            self.validate_transaction(tx, &working_balances, &working_nonces, &working_issued)?;
            apply_transaction(
                tx,
                block_height,
                &mut working_balances,
                &mut working_nonces,
                &mut working_issued,
                &mut working_journal,
            )?;
        }

        Ok(())
    }

    fn validate_transaction(
        &self,
        tx: &Transaction,
        balances: &HashMap<(String, String), i128>,
        nonces: &HashMap<String, i64>,
        issued: &HashMap<String, i128>,
    ) -> Result<(), LedgerError> {
        if tx.amount <= 0 {
            return Err(LedgerError::InvalidAmount);
        }

        if tx.asset.trim().is_empty() {
            return Err(LedgerError::MissingAsset);
        }

        let from_account = self
            .accounts
            .get(&tx.from)
            .ok_or_else(|| LedgerError::UnknownAccount(tx.from.clone()))?;
        let to_account = self
            .accounts
            .get(&tx.to)
            .ok_or_else(|| LedgerError::UnknownAccount(tx.to.clone()))?;

        let last_nonce = nonces.get(&tx.from).copied().unwrap_or_default();
        if tx.nonce <= last_nonce {
            return Err(LedgerError::InvalidNonce);
        }

        match tx.kind {
            TransactionKind::Transfer => {
                ensure_sufficient_balance(balances, &tx.from, &tx.asset, tx.amount)?;
            }
            TransactionKind::Mint => {
                if from_account.account_type != AccountType::Treasury {
                    return Err(LedgerError::MintRequiresTreasury);
                }
            }
            TransactionKind::Burn => {
                if to_account.account_type != AccountType::Treasury {
                    return Err(LedgerError::BurnRequiresTreasury);
                }
                ensure_sufficient_balance(balances, &tx.from, &tx.asset, tx.amount)?;
                if issued.get(&tx.asset).copied().unwrap_or_default() < tx.amount {
                    return Err(LedgerError::InsufficientFunds {
                        account_id: "ISSUANCE".to_string(),
                        asset: tx.asset.clone(),
                        available: issued.get(&tx.asset).copied().unwrap_or_default(),
                        required: tx.amount,
                    });
                }
            }
        }

        Ok(())
    }

    fn ensure_balance_row(&mut self, account_id: &str, asset: &str) {
        self.balances
            .entry((account_id.to_string(), asset.to_string()))
            .or_insert(0);
    }
}

#[derive(Clone)]
pub struct PostgresLedgerStore {
    pool: PgPool,
}

#[must_use = "block production locks must be released with release()"]
pub struct BlockProductionLock {
    connection: Option<PoolConnection<Postgres>>,
}

impl BlockProductionLock {
    pub async fn release(mut self) -> Result<(), LedgerStorageError> {
        let Some(mut connection) = self.connection.take() else {
            return Ok(());
        };

        let row = sqlx::query("SELECT pg_advisory_unlock($1) AS released")
            .bind(BLOCK_PRODUCTION_LOCK_ID)
            .fetch_one(&mut *connection)
            .await?;
        let released: bool = row.try_get("released")?;
        if !released {
            return Err(LedgerStorageError::AdvisoryLockReleaseFailed);
        }

        Ok(())
    }
}

impl PostgresLedgerStore {
    pub async fn connect(database_url: &str) -> Result<Self, LedgerStorageError> {
        let pool = PgPoolOptions::new()
            .max_connections(5)
            .connect(database_url)
            .await?;

        Ok(Self { pool })
    }

    pub async fn run_migrations(
        &self,
        migrations_path: impl AsRef<Path>,
    ) -> Result<(), LedgerStorageError> {
        let migrator = sqlx::migrate::Migrator::new(migrations_path.as_ref())
            .await
            .map_err(|error| LedgerStorageError::Migration(error.to_string()))?;

        migrator
            .run(&self.pool)
            .await
            .map_err(|error| LedgerStorageError::Migration(error.to_string()))?;

        Ok(())
    }

    pub async fn ensure_sandbox_seed(&self) -> Result<(), LedgerStorageError> {
        let snapshot = self.load_snapshot().await?;
        if snapshot.accounts.is_empty() {
            self.save_snapshot(&InMemoryLedger::sandbox().snapshot())
                .await?;
        } else if snapshot.institutions.is_empty() {
            for institution in InMemoryLedger::sandbox().snapshot().institutions {
                self.upsert_institution(&institution).await?;
            }
        }

        Ok(())
    }

    pub async fn upsert_institution(
        &self,
        institution: &Institution,
    ) -> Result<Institution, LedgerStorageError> {
        sqlx::query(
            r#"
            INSERT INTO institutions (
              id, legal_name, institution_code, jurisdiction, status, risk_tier,
              allowed_assets, roles, created_at, approved_at, suspended_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (id) DO UPDATE SET
              legal_name = EXCLUDED.legal_name,
              institution_code = EXCLUDED.institution_code,
              jurisdiction = EXCLUDED.jurisdiction,
              status = EXCLUDED.status,
              risk_tier = EXCLUDED.risk_tier,
              allowed_assets = EXCLUDED.allowed_assets,
              roles = EXCLUDED.roles,
              approved_at = EXCLUDED.approved_at,
              suspended_at = EXCLUDED.suspended_at,
              updated_at = EXCLUDED.updated_at
            "#,
        )
        .bind(&institution.id)
        .bind(&institution.legal_name)
        .bind(&institution.institution_code)
        .bind(&institution.jurisdiction)
        .bind(institution_status_to_db(&institution.status))
        .bind(institution_risk_tier_to_db(&institution.risk_tier))
        .bind(serde_json::to_value(&institution.allowed_assets)?)
        .bind(serde_json::to_value(
            institution
                .roles
                .iter()
                .map(institution_role_to_db)
                .collect::<Vec<_>>(),
        )?)
        .bind(institution.created_at)
        .bind(institution.approved_at)
        .bind(institution.suspended_at)
        .bind(institution.updated_at)
        .execute(&self.pool)
        .await?;

        Ok(institution.clone())
    }

    pub async fn institutions(&self) -> Result<Vec<Institution>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id, legal_name, institution_code, jurisdiction, status, risk_tier,
              allowed_assets, roles, created_at, approved_at, suspended_at, updated_at
            FROM institutions
            ORDER BY id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| institution_from_row(&row))
            .collect()
    }

    pub async fn get_institution(
        &self,
        institution_id: &str,
    ) -> Result<Option<Institution>, LedgerStorageError> {
        let row = sqlx::query(
            r#"
            SELECT
              id, legal_name, institution_code, jurisdiction, status, risk_tier,
              allowed_assets, roles, created_at, approved_at, suspended_at, updated_at
            FROM institutions
            WHERE id = $1
            "#,
        )
        .bind(institution_id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| institution_from_row(&row)).transpose()
    }

    pub async fn suspend_institution(
        &self,
        institution_id: &str,
    ) -> Result<Option<Institution>, LedgerStorageError> {
        let now = Utc::now();
        let row = sqlx::query(
            r#"
            UPDATE institutions
            SET status = 'SUSPENDED',
                suspended_at = COALESCE(suspended_at, $2),
                updated_at = $2
            WHERE id = $1
            RETURNING
              id, legal_name, institution_code, jurisdiction, status, risk_tier,
              allowed_assets, roles, created_at, approved_at, suspended_at, updated_at
            "#,
        )
        .bind(institution_id)
        .bind(now)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| institution_from_row(&row)).transpose()
    }

    pub async fn insert_institution_credential(
        &self,
        credential: &InstitutionCredential,
    ) -> Result<InstitutionCredential, LedgerStorageError> {
        sqlx::query(
            r#"
            INSERT INTO institution_credentials (
              id, institution_id, credential_type, label, fingerprint, issuer, subject,
              expires_at, status, created_at, revoked_at, revocation_reason
            )
            VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            "#,
        )
        .bind(&credential.id)
        .bind(&credential.institution_id)
        .bind(institution_credential_type_to_db(
            &credential.credential_type,
        ))
        .bind(&credential.label)
        .bind(&credential.fingerprint)
        .bind(&credential.issuer)
        .bind(&credential.subject)
        .bind(credential.expires_at)
        .bind(institution_credential_status_to_db(&credential.status))
        .bind(credential.created_at)
        .bind(credential.revoked_at)
        .bind(&credential.revocation_reason)
        .execute(&self.pool)
        .await?;

        Ok(credential.clone())
    }

    pub async fn institution_credentials(
        &self,
        institution_id: &str,
    ) -> Result<Vec<InstitutionCredential>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id, institution_id, credential_type, label, fingerprint, issuer,
              subject, expires_at, status, created_at, revoked_at, revocation_reason
            FROM institution_credentials
            WHERE institution_id = $1
            ORDER BY created_at, id
            "#,
        )
        .bind(institution_id)
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| institution_credential_from_row(&row))
            .collect()
    }

    pub async fn upsert_institution_limit(
        &self,
        limit: &InstitutionLimit,
    ) -> Result<InstitutionLimit, LedgerStorageError> {
        sqlx::query(
            r#"
            INSERT INTO institution_limits (
              institution_id, asset, daily_limit, per_transaction_limit, updated_at
            )
            VALUES ($1, $2, CAST($3 AS NUMERIC(38, 0)), CAST($4 AS NUMERIC(38, 0)), $5)
            ON CONFLICT (institution_id, asset) DO UPDATE SET
              daily_limit = EXCLUDED.daily_limit,
              per_transaction_limit = EXCLUDED.per_transaction_limit,
              updated_at = EXCLUDED.updated_at
            "#,
        )
        .bind(&limit.institution_id)
        .bind(&limit.asset)
        .bind(limit.daily_limit.to_string())
        .bind(limit.per_transaction_limit.to_string())
        .bind(limit.updated_at)
        .execute(&self.pool)
        .await?;

        Ok(limit.clone())
    }

    pub async fn institution_limits(
        &self,
        institution_id: &str,
    ) -> Result<Vec<InstitutionLimit>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              institution_id,
              asset,
              daily_limit::text AS daily_limit,
              per_transaction_limit::text AS per_transaction_limit,
              updated_at
            FROM institution_limits
            WHERE institution_id = $1
            ORDER BY asset
            "#,
        )
        .bind(institution_id)
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| institution_limit_from_row(&row))
            .collect()
    }

    pub async fn try_acquire_block_production_lock(
        &self,
    ) -> Result<Option<BlockProductionLock>, LedgerStorageError> {
        let mut connection = self.pool.acquire().await?;
        let row = sqlx::query("SELECT pg_try_advisory_lock($1) AS acquired")
            .bind(BLOCK_PRODUCTION_LOCK_ID)
            .fetch_one(&mut *connection)
            .await?;
        let acquired: bool = row.try_get("acquired")?;

        if !acquired {
            return Ok(None);
        }

        Ok(Some(BlockProductionLock {
            connection: Some(connection),
        }))
    }

    pub async fn next_nonce_for_account(
        &self,
        account_id: &str,
    ) -> Result<i64, LedgerStorageError> {
        let row = sqlx::query(
            r#"
            SELECT COALESCE(MAX(nonce), 0) + 1 AS next_nonce
            FROM transactions
            WHERE from_account = $1
            "#,
        )
        .bind(account_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(row.try_get("next_nonce")?)
    }

    pub async fn enqueue_pending_transaction(
        &self,
        tx_record: Transaction,
        client_reference_id: Option<String>,
        request_fingerprint: Option<String>,
    ) -> Result<PaymentRecord, LedgerStorageError> {
        if let Some(client_reference_id) = client_reference_id.as_deref() {
            if let Some(payment) = self
                .payment_by_client_reference_id(client_reference_id)
                .await?
            {
                ensure_idempotent_retry(
                    &payment,
                    &tx_record,
                    client_reference_id,
                    request_fingerprint.as_deref(),
                )?;
                return Ok(payment);
            }
        }

        let payment = PaymentRecord::pending(tx_record)
            .with_client_reference_id(client_reference_id.clone())
            .with_request_fingerprint(request_fingerprint.clone());
        let tx_record = &payment.transaction;

        let result = sqlx::query(
            r#"
            INSERT INTO transactions (
              id, block_height, from_account, to_account, asset, amount, nonce, kind, status,
              signatures, metadata, failure_reason, client_reference_id, request_fingerprint,
              created_at, updated_at
            )
            VALUES (
              $1::uuid, NULL, $2, $3, $4, CAST($5 AS NUMERIC(38, 0)), $6, $7, $8,
              $9, $10, NULL, $11, $12, $13, $14
            )
            ON CONFLICT (client_reference_id) WHERE client_reference_id IS NOT NULL DO NOTHING
            "#,
        )
        .bind(&tx_record.id)
        .bind(&tx_record.from)
        .bind(&tx_record.to)
        .bind(&tx_record.asset)
        .bind(tx_record.amount.to_string())
        .bind(tx_record.nonce)
        .bind(transaction_kind_to_db(&tx_record.kind))
        .bind(transaction_status_to_db(&payment.status))
        .bind(serde_json::to_value(&tx_record.signatures)?)
        .bind(serde_json::to_value(&tx_record.metadata)?)
        .bind(&payment.client_reference_id)
        .bind(&payment.request_fingerprint)
        .bind(payment.created_at)
        .bind(payment.updated_at)
        .execute(&self.pool)
        .await?;

        if result.rows_affected() == 0 {
            if let Some(client_reference_id) = client_reference_id.as_deref() {
                if let Some(payment) = self
                    .payment_by_client_reference_id(client_reference_id)
                    .await?
                {
                    ensure_idempotent_retry(
                        &payment,
                        tx_record,
                        client_reference_id,
                        request_fingerprint.as_deref(),
                    )?;
                    return Ok(payment);
                }
            }
        }

        Ok(payment)
    }

    pub async fn payment_by_client_reference_id(
        &self,
        client_reference_id: &str,
    ) -> Result<Option<PaymentRecord>, LedgerStorageError> {
        let row = sqlx::query(
            r#"
            SELECT
              t.id::text AS id,
              t.block_height,
              b.hash AS block_hash,
              t.from_account,
              t.to_account,
              t.asset,
              t.amount::text AS amount,
              t.nonce,
              t.kind,
              t.status,
              t.signatures,
              t.metadata,
              t.failure_reason,
              t.client_reference_id,
              t.request_fingerprint,
              t.created_at,
              t.updated_at
            FROM transactions t
            LEFT JOIN blocks b ON b.height = t.block_height
            WHERE t.client_reference_id = $1
            "#,
        )
        .bind(client_reference_id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| payment_from_row(&row)).transpose()
    }

    pub async fn payment(&self, payment_id: &str) -> Result<PaymentRecord, LedgerStorageError> {
        let row = sqlx::query(
            r#"
            SELECT
              t.id::text AS id,
              t.block_height,
              b.hash AS block_hash,
              t.from_account,
              t.to_account,
              t.asset,
              t.amount::text AS amount,
              t.nonce,
              t.kind,
              t.status,
              t.signatures,
              t.metadata,
              t.failure_reason,
              t.client_reference_id,
              t.request_fingerprint,
              t.created_at,
              t.updated_at
            FROM transactions t
            LEFT JOIN blocks b ON b.height = t.block_height
            WHERE t.id = $1::uuid
            "#,
        )
        .bind(payment_id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| payment_from_row(&row))
            .transpose()?
            .ok_or_else(|| LedgerStorageError::UnknownPayment(payment_id.to_string()))
    }

    pub async fn hold_payment_for_review(
        &self,
        tx_record: Transaction,
        client_reference_id: Option<String>,
        request_fingerprint: Option<String>,
        case_open: ComplianceCaseOpen,
    ) -> Result<(PaymentRecord, ComplianceCase), LedgerStorageError> {
        if let Some(client_reference_id) = client_reference_id.as_deref() {
            if let Some(payment) = self
                .payment_by_client_reference_id(client_reference_id)
                .await?
            {
                ensure_idempotent_retry(
                    &payment,
                    &tx_record,
                    client_reference_id,
                    request_fingerprint.as_deref(),
                )?;
                let compliance_case = self
                    .compliance_case_by_payment_id(&payment.transaction.id)
                    .await?;
                return Ok((payment, compliance_case));
            }
        }

        let payment = PaymentRecord::held(tx_record, case_open.reason.clone())
            .with_client_reference_id(client_reference_id.clone())
            .with_request_fingerprint(request_fingerprint.clone());
        let tx_record = &payment.transaction;
        let compliance_case = ComplianceCase::opened(case_open);

        let mut transaction = self.pool.begin().await?;
        let result = sqlx::query(
            r#"
            INSERT INTO transactions (
              id, block_height, from_account, to_account, asset, amount, nonce, kind, status,
              signatures, metadata, failure_reason, client_reference_id, request_fingerprint,
              created_at, updated_at
            )
            VALUES (
              $1::uuid, NULL, $2, $3, $4, CAST($5 AS NUMERIC(38, 0)), $6, $7, $8,
              $9, $10, $11, $12, $13, $14, $15
            )
            ON CONFLICT (client_reference_id) WHERE client_reference_id IS NOT NULL DO NOTHING
            "#,
        )
        .bind(&tx_record.id)
        .bind(&tx_record.from)
        .bind(&tx_record.to)
        .bind(&tx_record.asset)
        .bind(tx_record.amount.to_string())
        .bind(tx_record.nonce)
        .bind(transaction_kind_to_db(&tx_record.kind))
        .bind(transaction_status_to_db(&payment.status))
        .bind(serde_json::to_value(&tx_record.signatures)?)
        .bind(serde_json::to_value(&tx_record.metadata)?)
        .bind(&payment.failure_reason)
        .bind(&payment.client_reference_id)
        .bind(&payment.request_fingerprint)
        .bind(payment.created_at)
        .bind(payment.updated_at)
        .execute(&mut *transaction)
        .await?;

        if result.rows_affected() == 0 {
            transaction.rollback().await?;
            if let Some(client_reference_id) = client_reference_id.as_deref() {
                if let Some(payment) = self
                    .payment_by_client_reference_id(client_reference_id)
                    .await?
                {
                    ensure_idempotent_retry(
                        &payment,
                        tx_record,
                        client_reference_id,
                        request_fingerprint.as_deref(),
                    )?;
                    let compliance_case = self
                        .compliance_case_by_payment_id(&payment.transaction.id)
                        .await?;
                    return Ok((payment, compliance_case));
                }

                return Err(LedgerStorageError::IdempotencyConflict {
                    client_reference_id: client_reference_id.to_string(),
                    payment_id: "unknown".to_string(),
                });
            }

            return Err(LedgerStorageError::UnknownPayment(tx_record.id.clone()));
        }

        sqlx::query(
            r#"
            INSERT INTO compliance_cases (
              id, payment_id, status, policy_version, rule_id, reason, opened_by_institution,
              assigned_to, reviewer, resolution_reason, created_at, updated_at, resolved_at
            )
            VALUES (
              $1::uuid, $2::uuid, $3, $4, $5, $6, $7,
              $8, $9, $10, $11, $12, $13
            )
            ON CONFLICT (payment_id) DO NOTHING
            "#,
        )
        .bind(&compliance_case.id)
        .bind(&compliance_case.payment_id)
        .bind(compliance_case_status_to_db(&compliance_case.status))
        .bind(&compliance_case.policy_version)
        .bind(&compliance_case.rule_id)
        .bind(&compliance_case.reason)
        .bind(&compliance_case.opened_by_institution)
        .bind(&compliance_case.assigned_to)
        .bind(&compliance_case.reviewer)
        .bind(&compliance_case.resolution_reason)
        .bind(compliance_case.created_at)
        .bind(compliance_case.updated_at)
        .bind(compliance_case.resolved_at)
        .execute(&mut *transaction)
        .await?;

        transaction.commit().await?;
        Ok((payment, compliance_case))
    }

    pub async fn compliance_cases(
        &self,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<ComplianceCase>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              payment_id::text AS payment_id,
              status,
              policy_version,
              rule_id,
              reason,
              opened_by_institution,
              assigned_to,
              reviewer,
              resolution_reason,
              created_at,
              updated_at,
              resolved_at
            FROM compliance_cases
            ORDER BY created_at, id
            LIMIT $1
            OFFSET $2
            "#,
        )
        .bind(limit)
        .bind(offset)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(compliance_case_from_row).collect()
    }

    pub async fn compliance_case(
        &self,
        case_id: &str,
    ) -> Result<ComplianceCase, LedgerStorageError> {
        let row = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              payment_id::text AS payment_id,
              status,
              policy_version,
              rule_id,
              reason,
              opened_by_institution,
              assigned_to,
              reviewer,
              resolution_reason,
              created_at,
              updated_at,
              resolved_at
            FROM compliance_cases
            WHERE id = $1::uuid
            "#,
        )
        .bind(case_id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| compliance_case_from_row(&row))
            .transpose()?
            .ok_or_else(|| LedgerStorageError::UnknownComplianceCase(case_id.to_string()))
    }

    pub async fn compliance_case_by_payment_id(
        &self,
        payment_id: &str,
    ) -> Result<ComplianceCase, LedgerStorageError> {
        let row = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              payment_id::text AS payment_id,
              status,
              policy_version,
              rule_id,
              reason,
              opened_by_institution,
              assigned_to,
              reviewer,
              resolution_reason,
              created_at,
              updated_at,
              resolved_at
            FROM compliance_cases
            WHERE payment_id = $1::uuid
            "#,
        )
        .bind(payment_id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| compliance_case_from_row(&row))
            .transpose()?
            .ok_or_else(|| LedgerStorageError::UnknownComplianceCase(payment_id.to_string()))
    }

    pub async fn approve_compliance_case(
        &self,
        case_id: &str,
        reviewer: Option<String>,
        reason: Option<String>,
    ) -> Result<(ComplianceCase, PaymentRecord), LedgerStorageError> {
        let compliance_case = self.compliance_case(case_id).await?;
        ensure_storage_case_not_terminal(&compliance_case)?;
        let compliance_case = compliance_case.approved(reviewer, reason);
        let payment_id = compliance_case.payment_id.clone();

        let mut transaction = self.pool.begin().await?;
        self.update_compliance_case_in_transaction(&mut transaction, &compliance_case)
            .await?;
        sqlx::query(
            r#"
            UPDATE transactions
            SET status = 'PENDING',
                failure_reason = NULL,
                updated_at = now()
            WHERE id = $1::uuid
              AND status = 'HELD'
            "#,
        )
        .bind(&compliance_case.payment_id)
        .execute(&mut *transaction)
        .await?;
        transaction.commit().await?;

        Ok((compliance_case, self.payment(&payment_id).await?))
    }

    pub async fn reject_compliance_case(
        &self,
        case_id: &str,
        reviewer: Option<String>,
        reason: Option<String>,
    ) -> Result<(ComplianceCase, PaymentRecord), LedgerStorageError> {
        let compliance_case = self.compliance_case(case_id).await?;
        ensure_storage_case_not_terminal(&compliance_case)?;
        let rejection_reason = reason
            .clone()
            .unwrap_or_else(|| "compliance case rejected".to_string());
        let compliance_case = compliance_case.rejected(reviewer, reason);
        let payment_id = compliance_case.payment_id.clone();

        let mut transaction = self.pool.begin().await?;
        self.update_compliance_case_in_transaction(&mut transaction, &compliance_case)
            .await?;
        sqlx::query(
            r#"
            UPDATE transactions
            SET status = 'REJECTED',
                failure_reason = $2,
                updated_at = now()
            WHERE id = $1::uuid
              AND status = 'HELD'
            "#,
        )
        .bind(&compliance_case.payment_id)
        .bind(rejection_reason)
        .execute(&mut *transaction)
        .await?;
        transaction.commit().await?;

        Ok((compliance_case, self.payment(&payment_id).await?))
    }

    async fn update_compliance_case_in_transaction(
        &self,
        transaction: &mut sqlx::Transaction<'_, Postgres>,
        compliance_case: &ComplianceCase,
    ) -> Result<(), LedgerStorageError> {
        sqlx::query(
            r#"
            UPDATE compliance_cases
            SET status = $2,
                assigned_to = $3,
                reviewer = $4,
                resolution_reason = $5,
                updated_at = $6,
                resolved_at = $7
            WHERE id = $1::uuid
            "#,
        )
        .bind(&compliance_case.id)
        .bind(compliance_case_status_to_db(&compliance_case.status))
        .bind(&compliance_case.assigned_to)
        .bind(&compliance_case.reviewer)
        .bind(&compliance_case.resolution_reason)
        .bind(compliance_case.updated_at)
        .bind(compliance_case.resolved_at)
        .execute(&mut **transaction)
        .await?;

        Ok(())
    }

    pub async fn pending_transactions(
        &self,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<Transaction>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              from_account,
              to_account,
              asset,
              amount::text AS amount,
              nonce,
              kind,
              signatures,
              metadata,
              created_at
            FROM transactions
            WHERE status = 'PENDING'
            ORDER BY created_at, id
            LIMIT $1
            OFFSET $2
            "#,
        )
        .bind(limit)
        .bind(offset)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(transaction_from_row).collect()
    }

    pub async fn reject_transaction(
        &self,
        transaction_id: &str,
        reason: &str,
    ) -> Result<(), LedgerStorageError> {
        sqlx::query(
            r#"
            UPDATE transactions
            SET status = 'REJECTED',
                failure_reason = $2,
                updated_at = now()
            WHERE id = $1::uuid
              AND status = 'PENDING'
            "#,
        )
        .bind(transaction_id)
        .bind(reason)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn insert_audit_event(&self, event: &AuditEvent) -> Result<(), LedgerStorageError> {
        sqlx::query(
            r#"
            INSERT INTO audit_events (
              id, event_type, message, metadata, block_height, transaction_id, created_at
            )
            VALUES ($1::uuid, $2, $3, $4, $5, $6::uuid, $7)
            ON CONFLICT (id) DO NOTHING
            "#,
        )
        .bind(&event.id)
        .bind(&event.event_type)
        .bind(&event.message)
        .bind(serde_json::to_value(&event.metadata)?)
        .bind(event.block_height)
        .bind(&event.transaction_id)
        .bind(event.created_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn query_journal_entries(
        &self,
        search: &JournalEntrySearch,
    ) -> Result<Vec<JournalEntry>, LedgerStorageError> {
        let mut query_builder = QueryBuilder::<Postgres>::new(
            r#"
            SELECT
              id::text AS id,
              transaction_id::text AS transaction_id,
              account_id,
              asset,
              amount::text AS amount,
              direction,
              block_height,
              created_at
            FROM journal_entries
            WHERE account_id =
            "#,
        );
        query_builder.push_bind(&search.account_id);

        if let Some(asset) = search.asset.as_deref() {
            query_builder.push(" AND asset = ").push_bind(asset);
        }

        query_builder
            .push(" ORDER BY created_at, id LIMIT ")
            .push_bind(search.limit)
            .push(" OFFSET ")
            .push_bind(search.offset);

        let rows = query_builder.build().fetch_all(&self.pool).await?;
        rows.iter().map(journal_entry_from_row).collect()
    }

    pub async fn query_audit_events(
        &self,
        search: &AuditEventSearch,
    ) -> Result<Vec<AuditEvent>, LedgerStorageError> {
        let mut query_builder = QueryBuilder::<Postgres>::new(
            r#"
            SELECT
              id::text AS id,
              event_type,
              message,
              metadata,
              block_height,
              transaction_id::text AS transaction_id,
              created_at
            FROM audit_events
            "#,
        );
        let mut has_where = false;

        if let Some(event_type) = search.event_type.as_deref() {
            push_audit_where(&mut query_builder, &mut has_where);
            query_builder
                .push("lower(event_type) = lower(")
                .push_bind(event_type)
                .push(")");
        }

        if let Some(decision) = search.decision.as_deref() {
            push_audit_where(&mut query_builder, &mut has_where);
            query_builder
                .push("lower(metadata->>'decision') = lower(")
                .push_bind(decision)
                .push(")");
        }

        if let Some(institution_id) = search.institution_id.as_deref() {
            push_audit_where(&mut query_builder, &mut has_where);
            query_builder
                .push("metadata->>'institution_id' = ")
                .push_bind(institution_id);
        }

        if let Some(created_from) = search.created_from {
            push_audit_where(&mut query_builder, &mut has_where);
            query_builder.push("created_at >= ").push_bind(created_from);
        }

        if let Some(created_to) = search.created_to {
            push_audit_where(&mut query_builder, &mut has_where);
            query_builder.push("created_at <= ").push_bind(created_to);
        }

        query_builder
            .push(" ORDER BY created_at, id LIMIT ")
            .push_bind(search.limit)
            .push(" OFFSET ")
            .push_bind(search.offset);

        let rows = query_builder.build().fetch_all(&self.pool).await?;
        rows.iter().map(audit_event_from_row).collect()
    }

    pub async fn query_blocks(
        &self,
        search: &BlockSearch,
    ) -> Result<Vec<Block>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT height, prev_hash, hash, validator, signature, finalized_by, created_at
            FROM blocks
            ORDER BY height
            LIMIT $1
            OFFSET $2
            "#,
        )
        .bind(search.limit)
        .bind(search.offset)
        .fetch_all(&self.pool)
        .await?;

        let heights = rows
            .iter()
            .map(|row| row.try_get("height"))
            .collect::<Result<Vec<i64>, sqlx::Error>>()?;
        let mut txs_by_block = self.load_transactions_for_blocks(&heights).await?;

        rows.into_iter()
            .map(|row| {
                let height = row.try_get("height")?;
                block_from_row(&row, txs_by_block.remove(&height).unwrap_or_default())
            })
            .collect()
    }

    pub async fn record_validator_heartbeat(
        &self,
        validator_id: &str,
    ) -> Result<(), LedgerStorageError> {
        sqlx::query(
            r#"
            INSERT INTO validator_status (validator_id, last_seen_at)
            VALUES ($1, now())
            ON CONFLICT (validator_id) DO UPDATE SET
              last_seen_at = EXCLUDED.last_seen_at
            "#,
        )
        .bind(validator_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn record_validator_finalized_block(
        &self,
        validator_id: &str,
        block: &Block,
    ) -> Result<(), LedgerStorageError> {
        sqlx::query(
            r#"
            INSERT INTO validator_status (
              validator_id, last_seen_at, last_finalized_height, last_finalized_hash, last_finalized_at
            )
            VALUES ($1, now(), $2, $3, now())
            ON CONFLICT (validator_id) DO UPDATE SET
              last_seen_at = EXCLUDED.last_seen_at,
              last_finalized_height = EXCLUDED.last_finalized_height,
              last_finalized_hash = EXCLUDED.last_finalized_hash,
              last_finalized_at = EXCLUDED.last_finalized_at
            "#,
        )
        .bind(validator_id)
        .bind(block.height)
        .bind(&block.hash)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn validator_statuses(&self) -> Result<Vec<ValidatorStatus>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              validator_id,
              last_seen_at,
              last_finalized_height,
              last_finalized_hash,
              last_finalized_at
            FROM validator_status
            ORDER BY validator_id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| {
                Ok(ValidatorStatus {
                    validator_id: row.try_get("validator_id")?,
                    last_seen_at: row.try_get("last_seen_at")?,
                    last_finalized_height: row.try_get("last_finalized_height")?,
                    last_finalized_hash: row.try_get("last_finalized_hash")?,
                    last_finalized_at: row.try_get("last_finalized_at")?,
                })
            })
            .collect()
    }

    pub async fn save_snapshot(&self, snapshot: &LedgerSnapshot) -> Result<(), LedgerStorageError> {
        let mut tx = self.pool.begin().await?;

        for institution in &snapshot.institutions {
            sqlx::query(
                r#"
                INSERT INTO institutions (
                  id, legal_name, institution_code, jurisdiction, status, risk_tier,
                  allowed_assets, roles, created_at, approved_at, suspended_at, updated_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                ON CONFLICT (id) DO UPDATE SET
                  legal_name = EXCLUDED.legal_name,
                  institution_code = EXCLUDED.institution_code,
                  jurisdiction = EXCLUDED.jurisdiction,
                  status = EXCLUDED.status,
                  risk_tier = EXCLUDED.risk_tier,
                  allowed_assets = EXCLUDED.allowed_assets,
                  roles = EXCLUDED.roles,
                  approved_at = EXCLUDED.approved_at,
                  suspended_at = EXCLUDED.suspended_at,
                  updated_at = EXCLUDED.updated_at
                "#,
            )
            .bind(&institution.id)
            .bind(&institution.legal_name)
            .bind(&institution.institution_code)
            .bind(&institution.jurisdiction)
            .bind(institution_status_to_db(&institution.status))
            .bind(institution_risk_tier_to_db(&institution.risk_tier))
            .bind(serde_json::to_value(&institution.allowed_assets)?)
            .bind(serde_json::to_value(
                institution
                    .roles
                    .iter()
                    .map(institution_role_to_db)
                    .collect::<Vec<_>>(),
            )?)
            .bind(institution.created_at)
            .bind(institution.approved_at)
            .bind(institution.suspended_at)
            .bind(institution.updated_at)
            .execute(&mut *tx)
            .await?;
        }

        for credential in &snapshot.institution_credentials {
            sqlx::query(
                r#"
                INSERT INTO institution_credentials (
                  id, institution_id, credential_type, label, fingerprint, issuer, subject,
                  expires_at, status, created_at, revoked_at, revocation_reason
                )
                VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                ON CONFLICT (id) DO NOTHING
                "#,
            )
            .bind(&credential.id)
            .bind(&credential.institution_id)
            .bind(institution_credential_type_to_db(
                &credential.credential_type,
            ))
            .bind(&credential.label)
            .bind(&credential.fingerprint)
            .bind(&credential.issuer)
            .bind(&credential.subject)
            .bind(credential.expires_at)
            .bind(institution_credential_status_to_db(&credential.status))
            .bind(credential.created_at)
            .bind(credential.revoked_at)
            .bind(&credential.revocation_reason)
            .execute(&mut *tx)
            .await?;
        }

        for limit in &snapshot.institution_limits {
            sqlx::query(
                r#"
                INSERT INTO institution_limits (
                  institution_id, asset, daily_limit, per_transaction_limit, updated_at
                )
                VALUES ($1, $2, CAST($3 AS NUMERIC(38, 0)), CAST($4 AS NUMERIC(38, 0)), $5)
                ON CONFLICT (institution_id, asset) DO UPDATE SET
                  daily_limit = EXCLUDED.daily_limit,
                  per_transaction_limit = EXCLUDED.per_transaction_limit,
                  updated_at = EXCLUDED.updated_at
                "#,
            )
            .bind(&limit.institution_id)
            .bind(&limit.asset)
            .bind(limit.daily_limit.to_string())
            .bind(limit.per_transaction_limit.to_string())
            .bind(limit.updated_at)
            .execute(&mut *tx)
            .await?;
        }

        for account in &snapshot.accounts {
            sqlx::query(
                r#"
                INSERT INTO accounts (id, account_type, institution_id, created_at)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (id) DO UPDATE SET
                  account_type = EXCLUDED.account_type,
                  institution_id = EXCLUDED.institution_id
                "#,
            )
            .bind(&account.id)
            .bind(account_type_to_db(&account.account_type))
            .bind(&account.institution_id)
            .bind(account.created_at)
            .execute(&mut *tx)
            .await?;
        }

        for balance in &snapshot.balances {
            sqlx::query(
                r#"
                INSERT INTO balances (account_id, asset, amount, updated_at)
                VALUES ($1, $2, CAST($3 AS NUMERIC(38, 0)), now())
                ON CONFLICT (account_id, asset) DO UPDATE SET
                  amount = EXCLUDED.amount,
                  updated_at = now()
                "#,
            )
            .bind(&balance.account_id)
            .bind(&balance.asset)
            .bind(balance.amount.to_string())
            .execute(&mut *tx)
            .await?;
        }

        for block in &snapshot.blocks {
            sqlx::query(
                r#"
                INSERT INTO blocks (height, prev_hash, hash, validator, signature, finalized_by, created_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT (height) DO NOTHING
                "#,
            )
            .bind(block.height)
            .bind(&block.prev_hash)
            .bind(&block.hash)
            .bind(&block.validator)
            .bind(&block.signature)
            .bind(serde_json::to_value(&block.finalized_by)?)
            .bind(block.created_at)
            .execute(&mut *tx)
            .await?;
        }

        for payment in &snapshot.payments {
            let tx_record = &payment.transaction;
            sqlx::query(
                r#"
                INSERT INTO transactions (
                  id, block_height, from_account, to_account, asset, amount, nonce, kind, status,
                  signatures, metadata, failure_reason, client_reference_id, request_fingerprint,
                  created_at, updated_at
                )
                VALUES (
                  $1::uuid, $2, $3, $4, $5, CAST($6 AS NUMERIC(38, 0)), $7, $8, $9,
                  $10, $11, $12, $13, $14, $15, $16
                )
                ON CONFLICT (id) DO UPDATE SET
                  block_height = EXCLUDED.block_height,
                  status = EXCLUDED.status,
                  failure_reason = EXCLUDED.failure_reason,
                  updated_at = EXCLUDED.updated_at
                "#,
            )
            .bind(&tx_record.id)
            .bind(payment.block_height)
            .bind(&tx_record.from)
            .bind(&tx_record.to)
            .bind(&tx_record.asset)
            .bind(tx_record.amount.to_string())
            .bind(tx_record.nonce)
            .bind(transaction_kind_to_db(&tx_record.kind))
            .bind(transaction_status_to_db(&payment.status))
            .bind(serde_json::to_value(&tx_record.signatures)?)
            .bind(serde_json::to_value(&tx_record.metadata)?)
            .bind(&payment.failure_reason)
            .bind(&payment.client_reference_id)
            .bind(&payment.request_fingerprint)
            .bind(payment.created_at)
            .bind(payment.updated_at)
            .execute(&mut *tx)
            .await?;
        }

        for compliance_case in &snapshot.compliance_cases {
            sqlx::query(
                r#"
                INSERT INTO compliance_cases (
                  id, payment_id, status, policy_version, rule_id, reason, opened_by_institution,
                  assigned_to, reviewer, resolution_reason, created_at, updated_at, resolved_at
                )
                VALUES (
                  $1::uuid, $2::uuid, $3, $4, $5, $6, $7,
                  $8, $9, $10, $11, $12, $13
                )
                ON CONFLICT (id) DO UPDATE SET
                  status = EXCLUDED.status,
                  assigned_to = EXCLUDED.assigned_to,
                  reviewer = EXCLUDED.reviewer,
                  resolution_reason = EXCLUDED.resolution_reason,
                  updated_at = EXCLUDED.updated_at,
                  resolved_at = EXCLUDED.resolved_at
                "#,
            )
            .bind(&compliance_case.id)
            .bind(&compliance_case.payment_id)
            .bind(compliance_case_status_to_db(&compliance_case.status))
            .bind(&compliance_case.policy_version)
            .bind(&compliance_case.rule_id)
            .bind(&compliance_case.reason)
            .bind(&compliance_case.opened_by_institution)
            .bind(&compliance_case.assigned_to)
            .bind(&compliance_case.reviewer)
            .bind(&compliance_case.resolution_reason)
            .bind(compliance_case.created_at)
            .bind(compliance_case.updated_at)
            .bind(compliance_case.resolved_at)
            .execute(&mut *tx)
            .await?;
        }

        for entry in &snapshot.journal_entries {
            sqlx::query(
                r#"
                INSERT INTO journal_entries (
                  id, transaction_id, account_id, asset, amount, direction, block_height, created_at
                )
                VALUES ($1::uuid, $2::uuid, $3, $4, CAST($5 AS NUMERIC(38, 0)), $6, $7, $8)
                ON CONFLICT (id) DO NOTHING
                "#,
            )
            .bind(&entry.id)
            .bind(&entry.transaction_id)
            .bind(&entry.account_id)
            .bind(&entry.asset)
            .bind(entry.amount.to_string())
            .bind(journal_direction_to_db(&entry.direction))
            .bind(entry.block_height)
            .bind(entry.created_at)
            .execute(&mut *tx)
            .await?;
        }

        for event in &snapshot.audit_events {
            sqlx::query(
                r#"
                INSERT INTO audit_events (
                  id, event_type, message, metadata, block_height, transaction_id, created_at
                )
                VALUES ($1::uuid, $2, $3, $4, $5, $6::uuid, $7)
                ON CONFLICT (id) DO NOTHING
                "#,
            )
            .bind(&event.id)
            .bind(&event.event_type)
            .bind(&event.message)
            .bind(serde_json::to_value(&event.metadata)?)
            .bind(event.block_height)
            .bind(&event.transaction_id)
            .bind(event.created_at)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn load_snapshot(&self) -> Result<LedgerSnapshot, LedgerStorageError> {
        let accounts = self.load_accounts().await?;
        let institutions = self.institutions().await?;
        let institution_credentials = self.load_institution_credentials().await?;
        let institution_limits = self.load_institution_limits().await?;
        let balances = self.load_balances().await?;
        let (payments, nonces, issued, txs_by_block) = self.load_payments().await?;
        let compliance_cases = self.compliance_cases(i64::MAX, 0).await?;
        let blocks = self.load_blocks(txs_by_block).await?;
        let journal_entries = self.load_journal_entries().await?;
        let audit_events = self.load_audit_events().await?;

        Ok(LedgerSnapshot {
            accounts,
            institutions,
            institution_credentials,
            institution_limits,
            balances,
            payments,
            compliance_cases,
            blocks,
            audit_events,
            journal_entries,
            nonces,
            issued,
        })
    }

    async fn load_accounts(&self) -> Result<Vec<Account>, LedgerStorageError> {
        let rows = sqlx::query(
            "SELECT id, account_type, institution_id, created_at FROM accounts ORDER BY id",
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| {
                Ok(Account {
                    id: row.try_get("id")?,
                    account_type: account_type_from_db(row.try_get::<String, _>("account_type")?)?,
                    institution_id: row.try_get("institution_id")?,
                    created_at: row.try_get("created_at")?,
                })
            })
            .collect()
    }

    async fn load_institution_credentials(
        &self,
    ) -> Result<Vec<InstitutionCredential>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id, institution_id, credential_type, label, fingerprint, issuer,
              subject, expires_at, status, created_at, revoked_at, revocation_reason
            FROM institution_credentials
            ORDER BY created_at, id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| institution_credential_from_row(&row))
            .collect()
    }

    async fn load_institution_limits(&self) -> Result<Vec<InstitutionLimit>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              institution_id,
              asset,
              daily_limit::text AS daily_limit,
              per_transaction_limit::text AS per_transaction_limit,
              updated_at
            FROM institution_limits
            ORDER BY institution_id, asset
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| institution_limit_from_row(&row))
            .collect()
    }

    async fn load_balances(&self) -> Result<Vec<Balance>, LedgerStorageError> {
        let rows = sqlx::query(
            "SELECT account_id, asset, amount::text AS amount FROM balances ORDER BY account_id, asset",
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| {
                let amount = parse_amount(row.try_get("amount")?)?;
                Ok(Balance {
                    account_id: row.try_get("account_id")?,
                    asset: row.try_get("asset")?,
                    amount,
                })
            })
            .collect()
    }

    async fn load_payments(
        &self,
    ) -> Result<
        (
            Vec<PaymentRecord>,
            HashMap<String, i64>,
            HashMap<String, i128>,
            HashMap<i64, Vec<Transaction>>,
        ),
        LedgerStorageError,
    > {
        let rows = sqlx::query(
            r#"
            SELECT
              t.id::text AS id,
              t.block_height,
              b.hash AS block_hash,
              t.from_account,
              t.to_account,
              t.asset,
              t.amount::text AS amount,
              t.nonce,
              t.kind,
              t.status,
              t.signatures,
              t.metadata,
              t.failure_reason,
              t.client_reference_id,
              t.request_fingerprint,
              t.created_at,
              t.updated_at
            FROM transactions t
            LEFT JOIN blocks b ON b.height = t.block_height
            ORDER BY t.created_at, t.id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut payments = Vec::with_capacity(rows.len());
        let mut nonces = HashMap::new();
        let mut issued = HashMap::new();
        let mut txs_by_block: HashMap<i64, Vec<Transaction>> = HashMap::new();

        for row in rows {
            let payment = payment_from_row(&row)?;
            let status = payment.status.clone();
            let block_height: Option<i64> = row.try_get("block_height")?;
            let transaction = payment.transaction.clone();

            if status == TransactionStatus::Finalized {
                let next_nonce = nonces.entry(transaction.from.clone()).or_insert(0);
                *next_nonce = (*next_nonce).max(transaction.nonce);

                match transaction.kind {
                    TransactionKind::Mint => {
                        *issued.entry(transaction.asset.clone()).or_insert(0) += transaction.amount;
                    }
                    TransactionKind::Burn => {
                        *issued.entry(transaction.asset.clone()).or_insert(0) -= transaction.amount;
                    }
                    TransactionKind::Transfer => {}
                }
            }

            if let Some(height) = block_height {
                txs_by_block
                    .entry(height)
                    .or_default()
                    .push(transaction.clone());
            }

            payments.push(payment);
        }

        Ok((payments, nonces, issued, txs_by_block))
    }

    async fn load_blocks(
        &self,
        mut txs_by_block: HashMap<i64, Vec<Transaction>>,
    ) -> Result<Vec<Block>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT height, prev_hash, hash, validator, signature, finalized_by, created_at
            FROM blocks
            ORDER BY height
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| {
                let height = row.try_get("height")?;
                block_from_row(&row, txs_by_block.remove(&height).unwrap_or_default())
            })
            .collect()
    }

    async fn load_transactions_for_blocks(
        &self,
        heights: &[i64],
    ) -> Result<HashMap<i64, Vec<Transaction>>, LedgerStorageError> {
        if heights.is_empty() {
            return Ok(HashMap::new());
        }

        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              block_height,
              from_account,
              to_account,
              asset,
              amount::text AS amount,
              nonce,
              kind,
              signatures,
              metadata,
              created_at
            FROM transactions
            WHERE block_height = ANY($1::bigint[])
            ORDER BY block_height, created_at, id
            "#,
        )
        .bind(heights.to_vec())
        .fetch_all(&self.pool)
        .await?;

        let mut txs_by_block: HashMap<i64, Vec<Transaction>> = HashMap::new();
        for row in rows {
            let block_height = row.try_get("block_height")?;
            txs_by_block
                .entry(block_height)
                .or_default()
                .push(transaction_from_row(&row)?);
        }

        Ok(txs_by_block)
    }

    async fn load_journal_entries(&self) -> Result<Vec<JournalEntry>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              transaction_id::text AS transaction_id,
              account_id,
              asset,
              amount::text AS amount,
              direction,
              block_height,
              created_at
            FROM journal_entries
            ORDER BY created_at, id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(journal_entry_from_row).collect()
    }

    async fn load_audit_events(&self) -> Result<Vec<AuditEvent>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              event_type,
              message,
              metadata,
              block_height,
              transaction_id::text AS transaction_id,
              created_at
            FROM audit_events
            ORDER BY created_at, id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(audit_event_from_row).collect()
    }
}

fn push_audit_where(query_builder: &mut QueryBuilder<'_, Postgres>, has_where: &mut bool) {
    if *has_where {
        query_builder.push(" AND ");
    } else {
        query_builder.push(" WHERE ");
        *has_where = true;
    }
}

fn audit_event_from_row(row: &sqlx::postgres::PgRow) -> Result<AuditEvent, LedgerStorageError> {
    Ok(AuditEvent {
        id: row.try_get("id")?,
        event_type: row.try_get("event_type")?,
        message: row.try_get("message")?,
        metadata: serde_json::from_value(row.try_get::<Value, _>("metadata")?)?,
        block_height: row.try_get("block_height")?,
        transaction_id: row.try_get("transaction_id")?,
        created_at: row.try_get("created_at")?,
    })
}

fn journal_entry_from_row(row: &sqlx::postgres::PgRow) -> Result<JournalEntry, LedgerStorageError> {
    Ok(JournalEntry {
        id: row.try_get("id")?,
        transaction_id: row.try_get("transaction_id")?,
        account_id: row.try_get("account_id")?,
        asset: row.try_get("asset")?,
        amount: parse_amount(row.try_get("amount")?)?,
        direction: journal_direction_from_db(row.try_get::<String, _>("direction")?)?,
        block_height: row.try_get("block_height")?,
        created_at: row.try_get("created_at")?,
    })
}

fn institution_from_row(row: &sqlx::postgres::PgRow) -> Result<Institution, LedgerStorageError> {
    let roles: Vec<String> = serde_json::from_value(row.try_get::<Value, _>("roles")?)?;
    Ok(Institution {
        id: row.try_get("id")?,
        legal_name: row.try_get("legal_name")?,
        institution_code: row.try_get("institution_code")?,
        jurisdiction: row.try_get("jurisdiction")?,
        status: institution_status_from_db(row.try_get::<String, _>("status")?)?,
        risk_tier: institution_risk_tier_from_db(row.try_get::<String, _>("risk_tier")?)?,
        allowed_assets: serde_json::from_value(row.try_get::<Value, _>("allowed_assets")?)?,
        roles: roles
            .into_iter()
            .map(institution_role_from_db)
            .collect::<Result<Vec<_>, _>>()?,
        created_at: row.try_get("created_at")?,
        approved_at: row.try_get("approved_at")?,
        suspended_at: row.try_get("suspended_at")?,
        updated_at: row.try_get("updated_at")?,
    })
}

fn institution_credential_from_row(
    row: &sqlx::postgres::PgRow,
) -> Result<InstitutionCredential, LedgerStorageError> {
    Ok(InstitutionCredential {
        id: row.try_get("id")?,
        institution_id: row.try_get("institution_id")?,
        credential_type: institution_credential_type_from_db(
            row.try_get::<String, _>("credential_type")?,
        )?,
        label: row.try_get("label")?,
        fingerprint: row.try_get("fingerprint")?,
        issuer: row.try_get("issuer")?,
        subject: row.try_get("subject")?,
        expires_at: row.try_get("expires_at")?,
        status: institution_credential_status_from_db(row.try_get::<String, _>("status")?)?,
        created_at: row.try_get("created_at")?,
        revoked_at: row.try_get("revoked_at")?,
        revocation_reason: row.try_get("revocation_reason")?,
    })
}

fn institution_limit_from_row(
    row: &sqlx::postgres::PgRow,
) -> Result<InstitutionLimit, LedgerStorageError> {
    Ok(InstitutionLimit {
        institution_id: row.try_get("institution_id")?,
        asset: row.try_get("asset")?,
        daily_limit: parse_amount(row.try_get("daily_limit")?)?,
        per_transaction_limit: parse_amount(row.try_get("per_transaction_limit")?)?,
        updated_at: row.try_get("updated_at")?,
    })
}

fn block_from_row(
    row: &sqlx::postgres::PgRow,
    txs: Vec<Transaction>,
) -> Result<Block, LedgerStorageError> {
    Ok(Block {
        height: row.try_get("height")?,
        prev_hash: row.try_get("prev_hash")?,
        txs,
        validator: row.try_get("validator")?,
        signature: row.try_get("signature")?,
        hash: row.try_get("hash")?,
        finalized_by: serde_json::from_value(row.try_get::<Value, _>("finalized_by")?)?,
        created_at: row.try_get("created_at")?,
    })
}

fn payment_from_row(row: &sqlx::postgres::PgRow) -> Result<PaymentRecord, LedgerStorageError> {
    Ok(PaymentRecord {
        transaction: transaction_from_row(row)?,
        status: transaction_status_from_db(row.try_get::<String, _>("status")?)?,
        block_height: row.try_get("block_height")?,
        block_hash: row.try_get("block_hash")?,
        failure_reason: row.try_get("failure_reason")?,
        client_reference_id: row.try_get("client_reference_id")?,
        request_fingerprint: row.try_get("request_fingerprint")?,
        created_at: row.try_get("created_at")?,
        updated_at: row.try_get("updated_at")?,
    })
}

fn compliance_case_from_row(
    row: &sqlx::postgres::PgRow,
) -> Result<ComplianceCase, LedgerStorageError> {
    Ok(ComplianceCase {
        id: row.try_get("id")?,
        payment_id: row.try_get("payment_id")?,
        status: compliance_case_status_from_db(row.try_get::<String, _>("status")?)?,
        policy_version: row.try_get("policy_version")?,
        rule_id: row.try_get("rule_id")?,
        reason: row.try_get("reason")?,
        opened_by_institution: row.try_get("opened_by_institution")?,
        assigned_to: row.try_get("assigned_to")?,
        reviewer: row.try_get("reviewer")?,
        resolution_reason: row.try_get("resolution_reason")?,
        created_at: row.try_get("created_at")?,
        updated_at: row.try_get("updated_at")?,
        resolved_at: row.try_get("resolved_at")?,
    })
}

fn ensure_idempotent_retry(
    payment: &PaymentRecord,
    attempted_transaction: &Transaction,
    client_reference_id: &str,
    attempted_fingerprint: Option<&str>,
) -> Result<(), LedgerStorageError> {
    let fingerprint_matches = payment
        .request_fingerprint
        .as_deref()
        .zip(attempted_fingerprint)
        .map(|(existing, attempted)| existing == attempted)
        .unwrap_or_else(|| payment_matches_transaction(payment, attempted_transaction));

    if fingerprint_matches {
        return Ok(());
    }

    Err(LedgerStorageError::IdempotencyConflict {
        client_reference_id: client_reference_id.to_string(),
        payment_id: payment.transaction.id.clone(),
    })
}

fn payment_matches_transaction(
    payment: &PaymentRecord,
    attempted_transaction: &Transaction,
) -> bool {
    payment.transaction.kind == attempted_transaction.kind
        && payment.transaction.from == attempted_transaction.from
        && payment.transaction.to == attempted_transaction.to
        && payment.transaction.asset == attempted_transaction.asset
        && payment.transaction.amount == attempted_transaction.amount
}

fn ensure_case_not_terminal(compliance_case: &ComplianceCase) -> Result<(), LedgerError> {
    if compliance_case_is_terminal(compliance_case.status) {
        return Err(LedgerError::TerminalComplianceCase {
            case_id: compliance_case.id.clone(),
            status: compliance_case_status_to_db(&compliance_case.status).to_string(),
        });
    }

    Ok(())
}

fn ensure_storage_case_not_terminal(
    compliance_case: &ComplianceCase,
) -> Result<(), LedgerStorageError> {
    if compliance_case_is_terminal(compliance_case.status) {
        return Err(LedgerStorageError::TerminalComplianceCase {
            case_id: compliance_case.id.clone(),
            status: compliance_case_status_to_db(&compliance_case.status).to_string(),
        });
    }

    Ok(())
}

fn compliance_case_is_terminal(status: ComplianceCaseStatus) -> bool {
    matches!(
        status,
        ComplianceCaseStatus::Approved
            | ComplianceCaseStatus::Rejected
            | ComplianceCaseStatus::Closed
    )
}

fn metadata_matches(event: &AuditEvent, key: &str, expected: &str) -> bool {
    event
        .metadata
        .get(key)
        .map(|value| value == expected)
        .unwrap_or(false)
}

fn metadata_matches_ignore_case(event: &AuditEvent, key: &str, expected: &str) -> bool {
    event
        .metadata
        .get(key)
        .map(|value| value.eq_ignore_ascii_case(expected))
        .unwrap_or(false)
}

fn transaction_from_row(row: &sqlx::postgres::PgRow) -> Result<Transaction, LedgerStorageError> {
    Ok(Transaction {
        id: row.try_get("id")?,
        from: row.try_get("from_account")?,
        to: row.try_get("to_account")?,
        asset: row.try_get("asset")?,
        amount: parse_amount(row.try_get("amount")?)?,
        nonce: row.try_get("nonce")?,
        signatures: serde_json::from_value(row.try_get::<Value, _>("signatures")?)?,
        kind: transaction_kind_from_db(row.try_get::<String, _>("kind")?)?,
        metadata: serde_json::from_value(row.try_get::<Value, _>("metadata")?)?,
        created_at: row.try_get("created_at")?,
    })
}

fn parse_amount(value: String) -> Result<i128, LedgerStorageError> {
    value
        .parse()
        .map_err(|source| LedgerStorageError::ParseAmount { value, source })
}

fn account_type_to_db(account_type: &AccountType) -> &'static str {
    match account_type {
        AccountType::Treasury => "TREASURY",
        AccountType::Institution => "INSTITUTION",
        AccountType::Settlement => "SETTLEMENT",
        AccountType::Fee => "FEE",
    }
}

fn account_type_from_db(value: String) -> Result<AccountType, LedgerStorageError> {
    match value.as_str() {
        "TREASURY" => Ok(AccountType::Treasury),
        "INSTITUTION" => Ok(AccountType::Institution),
        "SETTLEMENT" => Ok(AccountType::Settlement),
        "FEE" => Ok(AccountType::Fee),
        _ => Err(LedgerStorageError::UnknownAccountType(value)),
    }
}

fn institution_status_to_db(status: &InstitutionStatus) -> &'static str {
    match status {
        InstitutionStatus::Requested => "REQUESTED",
        InstitutionStatus::DueDiligence => "DUE_DILIGENCE",
        InstitutionStatus::Approved => "APPROVED",
        InstitutionStatus::Rejected => "REJECTED",
        InstitutionStatus::Suspended => "SUSPENDED",
        InstitutionStatus::Offboarded => "OFFBOARDED",
    }
}

fn institution_status_from_db(value: String) -> Result<InstitutionStatus, LedgerStorageError> {
    match value.as_str() {
        "REQUESTED" => Ok(InstitutionStatus::Requested),
        "DUE_DILIGENCE" => Ok(InstitutionStatus::DueDiligence),
        "APPROVED" => Ok(InstitutionStatus::Approved),
        "REJECTED" => Ok(InstitutionStatus::Rejected),
        "SUSPENDED" => Ok(InstitutionStatus::Suspended),
        "OFFBOARDED" => Ok(InstitutionStatus::Offboarded),
        _ => Err(LedgerStorageError::UnknownInstitutionStatus(value)),
    }
}

fn institution_risk_tier_to_db(risk_tier: &InstitutionRiskTier) -> &'static str {
    match risk_tier {
        InstitutionRiskTier::Low => "LOW",
        InstitutionRiskTier::Medium => "MEDIUM",
        InstitutionRiskTier::High => "HIGH",
        InstitutionRiskTier::Restricted => "RESTRICTED",
    }
}

fn institution_risk_tier_from_db(value: String) -> Result<InstitutionRiskTier, LedgerStorageError> {
    match value.as_str() {
        "LOW" => Ok(InstitutionRiskTier::Low),
        "MEDIUM" => Ok(InstitutionRiskTier::Medium),
        "HIGH" => Ok(InstitutionRiskTier::High),
        "RESTRICTED" => Ok(InstitutionRiskTier::Restricted),
        _ => Err(LedgerStorageError::UnknownInstitutionRiskTier(value)),
    }
}

fn institution_role_to_db(role: &InstitutionRole) -> &'static str {
    match role {
        InstitutionRole::Operator => "OPERATOR",
        InstitutionRole::Approver => "APPROVER",
        InstitutionRole::Auditor => "AUDITOR",
        InstitutionRole::ComplianceReviewer => "COMPLIANCE_REVIEWER",
        InstitutionRole::TechnicalAdmin => "TECHNICAL_ADMIN",
    }
}

fn institution_role_from_db(value: String) -> Result<InstitutionRole, LedgerStorageError> {
    match value.as_str() {
        "OPERATOR" => Ok(InstitutionRole::Operator),
        "APPROVER" => Ok(InstitutionRole::Approver),
        "AUDITOR" => Ok(InstitutionRole::Auditor),
        "COMPLIANCE_REVIEWER" => Ok(InstitutionRole::ComplianceReviewer),
        "TECHNICAL_ADMIN" => Ok(InstitutionRole::TechnicalAdmin),
        _ => Err(LedgerStorageError::UnknownInstitutionRole(value)),
    }
}

fn institution_credential_type_to_db(credential_type: &InstitutionCredentialType) -> &'static str {
    match credential_type {
        InstitutionCredentialType::SandboxApiKey => "SANDBOX_API_KEY",
        InstitutionCredentialType::MtlsCertificate => "MTLS_CERTIFICATE",
        InstitutionCredentialType::OidcClient => "OIDC_CLIENT",
    }
}

fn institution_credential_type_from_db(
    value: String,
) -> Result<InstitutionCredentialType, LedgerStorageError> {
    match value.as_str() {
        "SANDBOX_API_KEY" => Ok(InstitutionCredentialType::SandboxApiKey),
        "MTLS_CERTIFICATE" => Ok(InstitutionCredentialType::MtlsCertificate),
        "OIDC_CLIENT" => Ok(InstitutionCredentialType::OidcClient),
        _ => Err(LedgerStorageError::UnknownInstitutionCredentialType(value)),
    }
}

fn institution_credential_status_to_db(status: &InstitutionCredentialStatus) -> &'static str {
    match status {
        InstitutionCredentialStatus::Pending => "PENDING",
        InstitutionCredentialStatus::Active => "ACTIVE",
        InstitutionCredentialStatus::Retired => "RETIRED",
        InstitutionCredentialStatus::Revoked => "REVOKED",
    }
}

fn institution_credential_status_from_db(
    value: String,
) -> Result<InstitutionCredentialStatus, LedgerStorageError> {
    match value.as_str() {
        "PENDING" => Ok(InstitutionCredentialStatus::Pending),
        "ACTIVE" => Ok(InstitutionCredentialStatus::Active),
        "RETIRED" => Ok(InstitutionCredentialStatus::Retired),
        "REVOKED" => Ok(InstitutionCredentialStatus::Revoked),
        _ => Err(LedgerStorageError::UnknownInstitutionCredentialStatus(
            value,
        )),
    }
}

fn transaction_kind_to_db(kind: &TransactionKind) -> &'static str {
    match kind {
        TransactionKind::Mint => "MINT",
        TransactionKind::Burn => "BURN",
        TransactionKind::Transfer => "TRANSFER",
    }
}

fn transaction_kind_from_db(value: String) -> Result<TransactionKind, LedgerStorageError> {
    match value.as_str() {
        "MINT" => Ok(TransactionKind::Mint),
        "BURN" => Ok(TransactionKind::Burn),
        "TRANSFER" => Ok(TransactionKind::Transfer),
        _ => Err(LedgerStorageError::UnknownTransactionKind(value)),
    }
}

fn transaction_status_to_db(status: &TransactionStatus) -> &'static str {
    match status {
        TransactionStatus::Pending => "PENDING",
        TransactionStatus::Held => "HELD",
        TransactionStatus::Finalized => "FINALIZED",
        TransactionStatus::Rejected => "REJECTED",
    }
}

fn transaction_status_from_db(value: String) -> Result<TransactionStatus, LedgerStorageError> {
    match value.as_str() {
        "PENDING" => Ok(TransactionStatus::Pending),
        "HELD" => Ok(TransactionStatus::Held),
        "FINALIZED" => Ok(TransactionStatus::Finalized),
        "REJECTED" => Ok(TransactionStatus::Rejected),
        _ => Err(LedgerStorageError::UnknownTransactionStatus(value)),
    }
}

fn compliance_case_status_to_db(status: &ComplianceCaseStatus) -> &'static str {
    match status {
        ComplianceCaseStatus::Opened => "OPENED",
        ComplianceCaseStatus::Assigned => "ASSIGNED",
        ComplianceCaseStatus::EvidenceRequested => "EVIDENCE_REQUESTED",
        ComplianceCaseStatus::Escalated => "ESCALATED",
        ComplianceCaseStatus::Approved => "APPROVED",
        ComplianceCaseStatus::Rejected => "REJECTED",
        ComplianceCaseStatus::Closed => "CLOSED",
    }
}

fn compliance_case_status_from_db(
    value: String,
) -> Result<ComplianceCaseStatus, LedgerStorageError> {
    match value.as_str() {
        "OPENED" => Ok(ComplianceCaseStatus::Opened),
        "ASSIGNED" => Ok(ComplianceCaseStatus::Assigned),
        "EVIDENCE_REQUESTED" => Ok(ComplianceCaseStatus::EvidenceRequested),
        "ESCALATED" => Ok(ComplianceCaseStatus::Escalated),
        "APPROVED" => Ok(ComplianceCaseStatus::Approved),
        "REJECTED" => Ok(ComplianceCaseStatus::Rejected),
        "CLOSED" => Ok(ComplianceCaseStatus::Closed),
        _ => Err(LedgerStorageError::UnknownComplianceCaseStatus(value)),
    }
}

fn journal_direction_to_db(direction: &JournalDirection) -> &'static str {
    match direction {
        JournalDirection::Debit => "DEBIT",
        JournalDirection::Credit => "CREDIT",
    }
}

fn journal_direction_from_db(value: String) -> Result<JournalDirection, LedgerStorageError> {
    match value.as_str() {
        "DEBIT" => Ok(JournalDirection::Debit),
        "CREDIT" => Ok(JournalDirection::Credit),
        _ => Err(LedgerStorageError::UnknownJournalDirection(value)),
    }
}

fn apply_transaction(
    tx: &Transaction,
    block_height: i64,
    balances: &mut HashMap<(String, String), i128>,
    nonces: &mut HashMap<String, i64>,
    issued: &mut HashMap<String, i128>,
    journal_entries: &mut Vec<JournalEntry>,
) -> Result<(), LedgerError> {
    match tx.kind {
        TransactionKind::Transfer => {
            debit(balances, &tx.from, &tx.asset, tx.amount)?;
            credit(balances, &tx.to, &tx.asset, tx.amount);
            journal_entries.push(JournalEntry::new(
                &tx.id,
                &tx.from,
                &tx.asset,
                tx.amount,
                JournalDirection::Debit,
                block_height,
            ));
            journal_entries.push(JournalEntry::new(
                &tx.id,
                &tx.to,
                &tx.asset,
                tx.amount,
                JournalDirection::Credit,
                block_height,
            ));
        }
        TransactionKind::Mint => {
            credit(balances, &tx.to, &tx.asset, tx.amount);
            *issued.entry(tx.asset.clone()).or_insert(0) += tx.amount;
            journal_entries.push(JournalEntry::new(
                &tx.id,
                &tx.to,
                &tx.asset,
                tx.amount,
                JournalDirection::Credit,
                block_height,
            ));
        }
        TransactionKind::Burn => {
            debit(balances, &tx.from, &tx.asset, tx.amount)?;
            *issued.entry(tx.asset.clone()).or_insert(0) -= tx.amount;
            journal_entries.push(JournalEntry::new(
                &tx.id,
                &tx.from,
                &tx.asset,
                tx.amount,
                JournalDirection::Debit,
                block_height,
            ));
        }
    }

    nonces.insert(tx.from.clone(), tx.nonce);
    Ok(())
}

fn debit(
    balances: &mut HashMap<(String, String), i128>,
    account_id: &str,
    asset: &str,
    amount: i128,
) -> Result<(), LedgerError> {
    ensure_sufficient_balance(balances, account_id, asset, amount)?;
    let balance = balances
        .entry((account_id.to_string(), asset.to_string()))
        .or_insert(0);
    *balance -= amount;
    Ok(())
}

fn credit(
    balances: &mut HashMap<(String, String), i128>,
    account_id: &str,
    asset: &str,
    amount: i128,
) {
    let balance = balances
        .entry((account_id.to_string(), asset.to_string()))
        .or_insert(0);
    *balance += amount;
}

fn ensure_sufficient_balance(
    balances: &HashMap<(String, String), i128>,
    account_id: &str,
    asset: &str,
    amount: i128,
) -> Result<(), LedgerError> {
    let available = balance_from(balances, account_id, asset);
    if available < amount {
        return Err(LedgerError::InsufficientFunds {
            account_id: account_id.to_string(),
            asset: asset.to_string(),
            available,
            required: amount,
        });
    }
    Ok(())
}

fn balance_from(balances: &HashMap<(String, String), i128>, account_id: &str, asset: &str) -> i128 {
    balances
        .get(&(account_id.to_string(), asset.to_string()))
        .copied()
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use kani_crypto::{hash_json, CryptoProfile};

    fn seal_test_block(ledger: &InMemoryLedger, txs: Vec<Transaction>) -> Block {
        let profile = CryptoProfile::hybrid_pqc_v1();
        let block =
            Block::new_unsealed(ledger.next_height(), ledger.last_hash(), txs, "validator-a");
        let hash = hash_json(&profile.hash, &block).unwrap();
        block.seal(
            hash,
            b"sandbox-signature".to_vec(),
            vec!["validator-a".to_string(), "validator-b".to_string()],
        )
    }

    #[test]
    fn sandbox_mint_and_transfer_keeps_balances_consistent() {
        let mut ledger = InMemoryLedger::sandbox();
        let mint = Transaction::new_mint(
            SANDBOX_TREASURY_ACCOUNT,
            SANDBOX_CORP_A_ACCOUNT,
            KCAD_TEST,
            1_000_000,
            ledger.next_nonce(SANDBOX_TREASURY_ACCOUNT),
        );
        let block = seal_test_block(&ledger, vec![mint]);
        ledger.apply_block(block).unwrap();

        let transfer = Transaction::new_transfer(
            SANDBOX_CORP_A_ACCOUNT,
            SANDBOX_CORP_B_ACCOUNT,
            KCAD_TEST,
            100_000,
            ledger.next_nonce(SANDBOX_CORP_A_ACCOUNT),
        );
        let block = seal_test_block(&ledger, vec![transfer]);
        ledger.apply_block(block).unwrap();

        assert_eq!(ledger.balance(SANDBOX_CORP_A_ACCOUNT, KCAD_TEST), 900_000);
        assert_eq!(ledger.balance(SANDBOX_CORP_B_ACCOUNT, KCAD_TEST), 100_000);
        assert_eq!(ledger.issued(KCAD_TEST), 1_000_000);
        assert_eq!(ledger.blocks().len(), 2);
        assert_eq!(ledger.audit_events().len(), 4);
    }

    #[test]
    fn journal_entry_search_filters_account_asset_and_pages_results() {
        let mut ledger = InMemoryLedger::sandbox();
        let mint = Transaction::new_mint(
            SANDBOX_TREASURY_ACCOUNT,
            SANDBOX_CORP_A_ACCOUNT,
            KCAD_TEST,
            1_000_000,
            ledger.next_nonce(SANDBOX_TREASURY_ACCOUNT),
        );
        ledger
            .apply_block(seal_test_block(&ledger, vec![mint]))
            .unwrap();

        let transfer = Transaction::new_transfer(
            SANDBOX_CORP_A_ACCOUNT,
            SANDBOX_CORP_B_ACCOUNT,
            KCAD_TEST,
            100_000,
            ledger.next_nonce(SANDBOX_CORP_A_ACCOUNT),
        );
        ledger
            .apply_block(seal_test_block(&ledger, vec![transfer]))
            .unwrap();

        let search = JournalEntrySearch {
            account_id: SANDBOX_CORP_A_ACCOUNT.to_string(),
            asset: Some(KCAD_TEST.to_string()),
            limit: 1,
            offset: 1,
        };
        let entries = search.apply(ledger.journal_entries().to_vec());

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].account_id, SANDBOX_CORP_A_ACCOUNT);
        assert_eq!(entries[0].asset, KCAD_TEST);
        assert_eq!(entries[0].direction, JournalDirection::Debit);
        assert_eq!(entries[0].amount, 100_000);
    }

    #[test]
    fn transfer_rejects_negative_balance() {
        let mut ledger = InMemoryLedger::sandbox();
        let transfer = Transaction::new_transfer(
            SANDBOX_CORP_A_ACCOUNT,
            SANDBOX_CORP_B_ACCOUNT,
            KCAD_TEST,
            1,
            ledger.next_nonce(SANDBOX_CORP_A_ACCOUNT),
        );
        let block = seal_test_block(&ledger, vec![transfer]);

        assert!(matches!(
            ledger.apply_block(block),
            Err(LedgerError::InsufficientFunds { .. })
        ));
        assert_eq!(ledger.blocks().len(), 0);
    }

    #[test]
    fn next_block_validation_checks_batch_without_mutating_ledger() {
        let mut ledger = InMemoryLedger::sandbox();
        let mint = Transaction::new_mint(
            SANDBOX_TREASURY_ACCOUNT,
            SANDBOX_CORP_A_ACCOUNT,
            KCAD_TEST,
            100,
            ledger.next_nonce(SANDBOX_TREASURY_ACCOUNT),
        );
        let block = seal_test_block(&ledger, vec![mint]);
        ledger.apply_block(block).unwrap();

        let valid = Transaction::new_transfer(
            SANDBOX_CORP_A_ACCOUNT,
            SANDBOX_CORP_B_ACCOUNT,
            KCAD_TEST,
            60,
            ledger.next_nonce(SANDBOX_CORP_A_ACCOUNT),
        );
        let invalid = Transaction::new_transfer(
            SANDBOX_CORP_A_ACCOUNT,
            SANDBOX_CORP_B_ACCOUNT,
            KCAD_TEST,
            60,
            ledger.next_nonce(SANDBOX_CORP_A_ACCOUNT) + 1,
        );

        assert!(matches!(
            ledger.validate_transactions_for_next_block(&[valid, invalid]),
            Err(LedgerError::InsufficientFunds { .. })
        ));
        assert_eq!(ledger.balance(SANDBOX_CORP_A_ACCOUNT, KCAD_TEST), 100);
        assert_eq!(ledger.blocks().len(), 1);
    }
}
