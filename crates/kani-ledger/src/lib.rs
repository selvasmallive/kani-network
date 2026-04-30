use kani_types::{
    Account, AccountType, AuditEvent, Block, JournalDirection, JournalEntry, PaymentRecord,
    Transaction, TransactionKind, GENESIS_HASH, KCAD_TEST, KUSD_TEST, SANDBOX_CORP_A_ACCOUNT,
    SANDBOX_CORP_B_ACCOUNT, SANDBOX_FEE_ACCOUNT, SANDBOX_TREASURY_ACCOUNT,
};
use std::collections::HashMap;
use thiserror::Error;

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
