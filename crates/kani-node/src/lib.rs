use kani_consensus::{ConsensusError, PoAConsensus};
use kani_crypto::{hash_json, sandbox_validator_signature, CryptoError, CryptoProfile};
use kani_ledger::{InMemoryLedger, LedgerError, LedgerStorageError, PostgresLedgerStore};
use kani_types::{Account, AuditEvent, Block, PaymentRecord, Transaction};
use std::sync::Arc;
use thiserror::Error;
use tokio::sync::Mutex;

#[derive(Debug, Error)]
pub enum NodeError {
    #[error(transparent)]
    Ledger(#[from] LedgerError),
    #[error(transparent)]
    Storage(#[from] LedgerStorageError),
    #[error(transparent)]
    Consensus(#[from] ConsensusError),
    #[error(transparent)]
    Crypto(#[from] CryptoError),
    #[error("ledger lock poisoned")]
    LockPoisoned,
    #[error("block must contain at least one transaction")]
    EmptyBlock,
    #[error("block finality threshold not met: got {got}, required {required}")]
    InsufficientFinality { got: usize, required: usize },
}

#[derive(Clone)]
pub struct KaniNode {
    ledger: Arc<Mutex<InMemoryLedger>>,
    consensus: PoAConsensus,
    crypto_profile: CryptoProfile,
    storage: Option<PostgresLedgerStore>,
}

#[derive(Clone, Debug)]
pub struct PaymentSubmission {
    pub payment: PaymentRecord,
    pub block: Block,
}

impl KaniNode {
    pub fn new(
        ledger: InMemoryLedger,
        consensus: PoAConsensus,
        crypto_profile: CryptoProfile,
    ) -> Self {
        Self {
            ledger: Arc::new(Mutex::new(ledger)),
            consensus,
            crypto_profile,
            storage: None,
        }
    }

    pub fn sandbox_default() -> Self {
        Self::new(
            InMemoryLedger::sandbox(),
            PoAConsensus::phase1_default(),
            CryptoProfile::hybrid_pqc_v1(),
        )
    }

    pub async fn postgres(database_url: &str) -> Result<Self, NodeError> {
        let storage = PostgresLedgerStore::connect(database_url).await?;
        storage.run_migrations("migrations").await?;

        let snapshot = storage.load_snapshot().await?;
        let ledger = if snapshot.accounts.is_empty() {
            InMemoryLedger::sandbox()
        } else {
            InMemoryLedger::from_snapshot(snapshot)
        };

        if ledger.is_pristine() {
            storage.save_snapshot(&ledger.snapshot()).await?;
        }

        Ok(Self {
            ledger: Arc::new(Mutex::new(ledger)),
            consensus: PoAConsensus::phase1_default(),
            crypto_profile: CryptoProfile::hybrid_pqc_v1(),
            storage: Some(storage),
        })
    }

    pub async fn submit_payment(
        &self,
        from: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
    ) -> Result<PaymentSubmission, NodeError> {
        let from = from.into();
        let to = to.into();
        let asset = asset.into();

        let mut ledger = self.ledger.lock().await;
        let nonce = ledger.next_nonce(&from);
        let tx = Transaction::new_transfer(from, to, asset, amount, nonce);
        self.produce_and_apply_locked(&mut ledger, vec![tx]).await
    }

    pub async fn mint_sandbox(
        &self,
        treasury: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
    ) -> Result<PaymentSubmission, NodeError> {
        let treasury = treasury.into();
        let to = to.into();
        let asset = asset.into();

        let mut ledger = self.ledger.lock().await;
        let nonce = ledger.next_nonce(&treasury);
        let tx = Transaction::new_mint(treasury, to, asset, amount, nonce);
        self.produce_and_apply_locked(&mut ledger, vec![tx]).await
    }

    pub async fn burn_sandbox(
        &self,
        from: impl Into<String>,
        treasury: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
    ) -> Result<PaymentSubmission, NodeError> {
        let from = from.into();
        let treasury = treasury.into();
        let asset = asset.into();

        let mut ledger = self.ledger.lock().await;
        let nonce = ledger.next_nonce(&from);
        let tx = Transaction::new_burn(from, treasury, asset, amount, nonce);
        self.produce_and_apply_locked(&mut ledger, vec![tx]).await
    }

    pub async fn get_payment(&self, payment_id: &str) -> Result<PaymentRecord, NodeError> {
        Ok(self.ledger.lock().await.get_payment(payment_id)?)
    }

    pub async fn balance(&self, account_id: &str, asset: &str) -> Result<i128, NodeError> {
        Ok(self.ledger.lock().await.balance(account_id, asset))
    }

    pub async fn issued(&self, asset: &str) -> Result<i128, NodeError> {
        Ok(self.ledger.lock().await.issued(asset))
    }

    pub async fn latest_block(&self) -> Result<Option<Block>, NodeError> {
        Ok(self.ledger.lock().await.latest_block())
    }

    pub async fn blocks(&self) -> Result<Vec<Block>, NodeError> {
        Ok(self.ledger.lock().await.blocks().to_vec())
    }

    pub async fn accounts(&self) -> Result<Vec<Account>, NodeError> {
        Ok(self.ledger.lock().await.accounts())
    }

    pub async fn audit_events(&self) -> Result<Vec<AuditEvent>, NodeError> {
        Ok(self.ledger.lock().await.audit_events().to_vec())
    }

    pub fn consensus(&self) -> &PoAConsensus {
        &self.consensus
    }

    pub fn crypto_profile(&self) -> &CryptoProfile {
        &self.crypto_profile
    }

    async fn produce_and_apply_locked(
        &self,
        ledger: &mut InMemoryLedger,
        txs: Vec<Transaction>,
    ) -> Result<PaymentSubmission, NodeError> {
        if txs.is_empty() {
            return Err(NodeError::EmptyBlock);
        }

        let block = self.build_block(ledger, txs)?;
        let mut working_ledger = ledger.clone();
        let records = working_ledger.apply_block(block.clone())?;
        if let Some(storage) = &self.storage {
            storage.save_snapshot(&working_ledger.snapshot()).await?;
        }
        *ledger = working_ledger;

        let payment = records.into_iter().next().ok_or(NodeError::EmptyBlock)?;

        Ok(PaymentSubmission { payment, block })
    }

    fn build_block(
        &self,
        ledger: &InMemoryLedger,
        txs: Vec<Transaction>,
    ) -> Result<Block, NodeError> {
        let height = ledger.next_height();
        let validator = self.consensus.leader_for_height(height)?;
        let votes = self.consensus.finality_votes_for_block(height)?;
        let required = self.consensus.finality_threshold();
        if votes.len() < required {
            return Err(NodeError::InsufficientFinality {
                got: votes.len(),
                required,
            });
        }

        let block = Block::new_unsealed(height, ledger.last_hash(), txs, validator.id.clone());
        let hash = hash_json(&self.crypto_profile.hash, &block)?;
        let signature = sandbox_validator_signature(&self.crypto_profile, &validator.id, &hash);

        Ok(block.seal(hash, signature, votes))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kani_types::{
        TransactionStatus, KCAD_TEST, SANDBOX_CORP_A_ACCOUNT, SANDBOX_CORP_B_ACCOUNT,
        SANDBOX_TREASURY_ACCOUNT,
    };

    #[tokio::test]
    async fn node_processes_sandbox_payment_end_to_end() {
        let node = KaniNode::sandbox_default();

        let mint = node
            .mint_sandbox(
                SANDBOX_TREASURY_ACCOUNT,
                SANDBOX_CORP_A_ACCOUNT,
                KCAD_TEST,
                1_000_000,
            )
            .await
            .unwrap();
        assert_eq!(mint.payment.status, TransactionStatus::Finalized);
        assert_eq!(mint.block.height, 1);
        assert_eq!(mint.block.finalized_by.len(), 2);

        let payment = node
            .submit_payment(
                SANDBOX_CORP_A_ACCOUNT,
                SANDBOX_CORP_B_ACCOUNT,
                KCAD_TEST,
                100_000,
            )
            .await
            .unwrap();

        assert_eq!(payment.payment.status, TransactionStatus::Finalized);
        assert_eq!(payment.block.height, 2);
        assert_eq!(
            node.balance(SANDBOX_CORP_A_ACCOUNT, KCAD_TEST)
                .await
                .unwrap(),
            900_000
        );
        assert_eq!(
            node.balance(SANDBOX_CORP_B_ACCOUNT, KCAD_TEST)
                .await
                .unwrap(),
            100_000
        );
        assert!(node
            .get_payment(&payment.payment.transaction.id)
            .await
            .is_ok());
    }
}
