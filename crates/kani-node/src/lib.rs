use kani_consensus::{ConsensusError, PoAConsensus};
use kani_crypto::{hash_json, sandbox_validator_signature, CryptoError, CryptoProfile};
use kani_ledger::{InMemoryLedger, LedgerError};
use kani_types::{Account, AuditEvent, Block, PaymentRecord, Transaction};
use std::sync::{Arc, RwLock, RwLockReadGuard, RwLockWriteGuard};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum NodeError {
    #[error(transparent)]
    Ledger(#[from] LedgerError),
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
    ledger: Arc<RwLock<InMemoryLedger>>,
    consensus: PoAConsensus,
    crypto_profile: CryptoProfile,
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
            ledger: Arc::new(RwLock::new(ledger)),
            consensus,
            crypto_profile,
        }
    }

    pub fn sandbox_default() -> Self {
        Self::new(
            InMemoryLedger::sandbox(),
            PoAConsensus::phase1_default(),
            CryptoProfile::hybrid_pqc_v1(),
        )
    }

    pub fn submit_payment(
        &self,
        from: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
    ) -> Result<PaymentSubmission, NodeError> {
        let from = from.into();
        let to = to.into();
        let asset = asset.into();

        let mut ledger = self.ledger_write()?;
        let nonce = ledger.next_nonce(&from);
        let tx = Transaction::new_transfer(from, to, asset, amount, nonce);
        self.produce_and_apply_locked(&mut ledger, vec![tx])
    }

    pub fn mint_sandbox(
        &self,
        treasury: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
    ) -> Result<PaymentSubmission, NodeError> {
        let treasury = treasury.into();
        let to = to.into();
        let asset = asset.into();

        let mut ledger = self.ledger_write()?;
        let nonce = ledger.next_nonce(&treasury);
        let tx = Transaction::new_mint(treasury, to, asset, amount, nonce);
        self.produce_and_apply_locked(&mut ledger, vec![tx])
    }

    pub fn burn_sandbox(
        &self,
        from: impl Into<String>,
        treasury: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
    ) -> Result<PaymentSubmission, NodeError> {
        let from = from.into();
        let treasury = treasury.into();
        let asset = asset.into();

        let mut ledger = self.ledger_write()?;
        let nonce = ledger.next_nonce(&from);
        let tx = Transaction::new_burn(from, treasury, asset, amount, nonce);
        self.produce_and_apply_locked(&mut ledger, vec![tx])
    }

    pub fn get_payment(&self, payment_id: &str) -> Result<PaymentRecord, NodeError> {
        Ok(self.ledger_read()?.get_payment(payment_id)?)
    }

    pub fn balance(&self, account_id: &str, asset: &str) -> Result<i128, NodeError> {
        Ok(self.ledger_read()?.balance(account_id, asset))
    }

    pub fn issued(&self, asset: &str) -> Result<i128, NodeError> {
        Ok(self.ledger_read()?.issued(asset))
    }

    pub fn latest_block(&self) -> Result<Option<Block>, NodeError> {
        Ok(self.ledger_read()?.latest_block())
    }

    pub fn accounts(&self) -> Result<Vec<Account>, NodeError> {
        Ok(self.ledger_read()?.accounts())
    }

    pub fn audit_events(&self) -> Result<Vec<AuditEvent>, NodeError> {
        Ok(self.ledger_read()?.audit_events().to_vec())
    }

    pub fn consensus(&self) -> &PoAConsensus {
        &self.consensus
    }

    pub fn crypto_profile(&self) -> &CryptoProfile {
        &self.crypto_profile
    }

    fn produce_and_apply_locked(
        &self,
        ledger: &mut InMemoryLedger,
        txs: Vec<Transaction>,
    ) -> Result<PaymentSubmission, NodeError> {
        if txs.is_empty() {
            return Err(NodeError::EmptyBlock);
        }

        let block = self.build_block(ledger, txs)?;
        let records = ledger.apply_block(block.clone())?;
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

    fn ledger_read(&self) -> Result<RwLockReadGuard<'_, InMemoryLedger>, NodeError> {
        self.ledger.read().map_err(|_| NodeError::LockPoisoned)
    }

    fn ledger_write(&self) -> Result<RwLockWriteGuard<'_, InMemoryLedger>, NodeError> {
        self.ledger.write().map_err(|_| NodeError::LockPoisoned)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kani_types::{
        TransactionStatus, KCAD_TEST, SANDBOX_CORP_A_ACCOUNT, SANDBOX_CORP_B_ACCOUNT,
        SANDBOX_TREASURY_ACCOUNT,
    };

    #[test]
    fn node_processes_sandbox_payment_end_to_end() {
        let node = KaniNode::sandbox_default();

        let mint = node
            .mint_sandbox(
                SANDBOX_TREASURY_ACCOUNT,
                SANDBOX_CORP_A_ACCOUNT,
                KCAD_TEST,
                1_000_000,
            )
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
            .unwrap();

        assert_eq!(payment.payment.status, TransactionStatus::Finalized);
        assert_eq!(payment.block.height, 2);
        assert_eq!(
            node.balance(SANDBOX_CORP_A_ACCOUNT, KCAD_TEST).unwrap(),
            900_000
        );
        assert_eq!(
            node.balance(SANDBOX_CORP_B_ACCOUNT, KCAD_TEST).unwrap(),
            100_000
        );
        assert!(node.get_payment(&payment.payment.transaction.id).is_ok());
    }
}
