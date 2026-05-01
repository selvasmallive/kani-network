use kani_types::{
    Account, AccountType, AuditEvent, Block, JournalDirection, JournalEntry, PaymentRecord,
    Transaction, TransactionKind, TransactionStatus, GENESIS_HASH, KCAD_TEST, KUSD_TEST,
    SANDBOX_CORP_A_ACCOUNT, SANDBOX_CORP_B_ACCOUNT, SANDBOX_FEE_ACCOUNT, SANDBOX_TREASURY_ACCOUNT,
};
use serde_json::Value;
use sqlx::{pool::PoolConnection, postgres::PgPoolOptions, PgPool, Postgres, Row};
use std::{collections::HashMap, path::Path};
use thiserror::Error;

const BLOCK_PRODUCTION_LOCK_ID: i64 = 0x4B414E49504F4131_i64;

#[derive(Debug, Error)]
pub enum LedgerError {
    #[error("account {0} does not exist")]
    UnknownAccount(String),
    #[error("payment {0} does not exist")]
    UnknownPayment(String),
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
    #[error("unknown transaction kind {0}")]
    UnknownTransactionKind(String),
    #[error("unknown transaction status {0}")]
    UnknownTransactionStatus(String),
    #[error("unknown journal direction {0}")]
    UnknownJournalDirection(String),
    #[error("migration failed: {0}")]
    Migration(String),
    #[error("failed to release block production advisory lock")]
    AdvisoryLockReleaseFailed,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Balance {
    pub account_id: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Debug, Default)]
pub struct LedgerSnapshot {
    pub accounts: Vec<Account>,
    pub balances: Vec<Balance>,
    pub payments: Vec<PaymentRecord>,
    pub blocks: Vec<Block>,
    pub audit_events: Vec<AuditEvent>,
    pub journal_entries: Vec<JournalEntry>,
    pub nonces: HashMap<String, i64>,
    pub issued: HashMap<String, i128>,
}

#[derive(Clone, Debug)]
pub struct InMemoryLedger {
    accounts: HashMap<String, Account>,
    balances: HashMap<(String, String), i128>,
    payments: HashMap<String, PaymentRecord>,
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
            balances: HashMap::new(),
            payments: HashMap::new(),
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
        ledger.upsert_account(Account::new(
            SANDBOX_TREASURY_ACCOUNT,
            AccountType::Treasury,
            Some("KANI_TREASURY".to_string()),
        ));
        ledger.upsert_account(Account::new(
            SANDBOX_CORP_A_ACCOUNT,
            AccountType::Institution,
            Some("CORP_A".to_string()),
        ));
        ledger.upsert_account(Account::new(
            SANDBOX_CORP_B_ACCOUNT,
            AccountType::Institution,
            Some("CORP_B".to_string()),
        ));
        ledger.upsert_account(Account::new(
            SANDBOX_FEE_ACCOUNT,
            AccountType::Fee,
            Some("KANI".to_string()),
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

    pub fn latest_block(&self) -> Option<Block> {
        self.blocks.last().cloned()
    }

    pub fn blocks(&self) -> &[Block] {
        &self.blocks
    }

    pub fn audit_events(&self) -> &[AuditEvent] {
        &self.audit_events
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
        }

        Ok(())
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
    ) -> Result<PaymentRecord, LedgerStorageError> {
        let payment = PaymentRecord::pending(tx_record);
        let tx_record = &payment.transaction;

        sqlx::query(
            r#"
            INSERT INTO transactions (
              id, block_height, from_account, to_account, asset, amount, nonce, kind, status,
              signatures, metadata, failure_reason, created_at, updated_at
            )
            VALUES (
              $1::uuid, NULL, $2, $3, $4, CAST($5 AS NUMERIC(38, 0)), $6, $7, $8,
              $9, $10, NULL, $11, $12
            )
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
        .bind(payment.created_at)
        .bind(payment.updated_at)
        .execute(&self.pool)
        .await?;

        Ok(payment)
    }

    pub async fn pending_transactions(
        &self,
        limit: i64,
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
            "#,
        )
        .bind(limit)
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

    pub async fn save_snapshot(&self, snapshot: &LedgerSnapshot) -> Result<(), LedgerStorageError> {
        let mut tx = self.pool.begin().await?;

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
                  signatures, metadata, failure_reason, created_at, updated_at
                )
                VALUES (
                  $1::uuid, $2, $3, $4, $5, CAST($6 AS NUMERIC(38, 0)), $7, $8, $9,
                  $10, $11, $12, $13, $14
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
            .bind(payment.created_at)
            .bind(payment.updated_at)
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
                  id, event_type, message, block_height, transaction_id, created_at
                )
                VALUES ($1::uuid, $2, $3, $4, $5::uuid, $6)
                ON CONFLICT (id) DO NOTHING
                "#,
            )
            .bind(&event.id)
            .bind(&event.event_type)
            .bind(&event.message)
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
        let balances = self.load_balances().await?;
        let (payments, nonces, issued, txs_by_block) = self.load_payments().await?;
        let blocks = self.load_blocks(txs_by_block).await?;
        let journal_entries = self.load_journal_entries().await?;
        let audit_events = self.load_audit_events().await?;

        Ok(LedgerSnapshot {
            accounts,
            balances,
            payments,
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
            let status = transaction_status_from_db(row.try_get::<String, _>("status")?)?;
            let block_height: Option<i64> = row.try_get("block_height")?;
            let transaction = transaction_from_row(&row)?;

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

            payments.push(PaymentRecord {
                transaction,
                status,
                block_height,
                block_hash: row.try_get("block_hash")?,
                failure_reason: row.try_get("failure_reason")?,
                created_at: row.try_get("created_at")?,
                updated_at: row.try_get("updated_at")?,
            });
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
                let finalized_by =
                    serde_json::from_value(row.try_get::<Value, _>("finalized_by")?)?;

                Ok(Block {
                    height,
                    prev_hash: row.try_get("prev_hash")?,
                    txs: txs_by_block.remove(&height).unwrap_or_default(),
                    validator: row.try_get("validator")?,
                    signature: row.try_get("signature")?,
                    hash: row.try_get("hash")?,
                    finalized_by,
                    created_at: row.try_get("created_at")?,
                })
            })
            .collect()
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

        rows.into_iter()
            .map(|row| {
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
            })
            .collect()
    }

    async fn load_audit_events(&self) -> Result<Vec<AuditEvent>, LedgerStorageError> {
        let rows = sqlx::query(
            r#"
            SELECT
              id::text AS id,
              event_type,
              message,
              block_height,
              transaction_id::text AS transaction_id,
              created_at
            FROM audit_events
            ORDER BY created_at, id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.into_iter()
            .map(|row| {
                Ok(AuditEvent {
                    id: row.try_get("id")?,
                    event_type: row.try_get("event_type")?,
                    message: row.try_get("message")?,
                    block_height: row.try_get("block_height")?,
                    transaction_id: row.try_get("transaction_id")?,
                    created_at: row.try_get("created_at")?,
                })
            })
            .collect()
    }
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
        TransactionStatus::Finalized => "FINALIZED",
        TransactionStatus::Rejected => "REJECTED",
    }
}

fn transaction_status_from_db(value: String) -> Result<TransactionStatus, LedgerStorageError> {
    match value.as_str() {
        "PENDING" => Ok(TransactionStatus::Pending),
        "FINALIZED" => Ok(TransactionStatus::Finalized),
        "REJECTED" => Ok(TransactionStatus::Rejected),
        _ => Err(LedgerStorageError::UnknownTransactionStatus(value)),
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
}
