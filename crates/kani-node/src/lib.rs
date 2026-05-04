use chrono::{DateTime, Utc};
use kani_consensus::{ConsensusError, PoAConsensus, Validator};
use kani_crypto::{hash_bytes, hash_json, sandbox_validator_signature, CryptoError, CryptoProfile};
use kani_ledger::{
    AuditEventSearch, BlockSearch, InMemoryLedger, LedgerError, LedgerStorageError,
    PostgresLedgerStore, ValidatorStatus,
};
use kani_types::{Account, AuditEvent, Block, PaymentRecord, Transaction, TransactionKind};
use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    env,
    sync::Arc,
};
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
    #[error("block validator mismatch: expected {expected}, got {actual}")]
    InvalidBlockValidator { expected: String, actual: String },
    #[error("block finality vote from inactive or unknown validator {0}")]
    UnknownFinalityValidator(String),
    #[error("duplicate block finality vote from validator {0}")]
    DuplicateFinalityVote(String),
    #[error("block finality votes must include the block producer {0}")]
    MissingProducerFinalityVote(String),
    #[error("block hash mismatch: expected {expected}, got {actual}")]
    InvalidBlockHash { expected: String, actual: String },
    #[error("block signature mismatch for validator {validator} and hash {hash}")]
    InvalidBlockSignature { validator: String, hash: String },
    #[error("idempotency key {client_reference_id} was already used for a different payment")]
    IdempotencyConflict { client_reference_id: String },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SandboxRuntimeConfig {
    environment: String,
    real_value: bool,
    redeemable: bool,
}

#[derive(Debug, Error, Eq, PartialEq)]
pub enum SandboxRuntimeConfigError {
    #[error("Phase 1 runtime requires ENV=SANDBOX, got {actual}")]
    InvalidEnvironment { actual: String },
    #[error("Phase 1 runtime requires REAL_VALUE=FALSE, got {actual}")]
    RealValueEnabled { actual: String },
    #[error("Phase 1 runtime requires REDEEMABLE=FALSE, got {actual}")]
    RedeemableEnabled { actual: String },
}

impl SandboxRuntimeConfig {
    pub fn from_env() -> Result<Self, SandboxRuntimeConfigError> {
        Self::from_values(
            env::var("ENV").ok(),
            env::var("REAL_VALUE").ok(),
            env::var("REDEEMABLE").ok(),
        )
    }

    pub fn from_values(
        environment: Option<String>,
        real_value: Option<String>,
        redeemable: Option<String>,
    ) -> Result<Self, SandboxRuntimeConfigError> {
        let environment =
            environment.ok_or_else(|| SandboxRuntimeConfigError::InvalidEnvironment {
                actual: "<unset>".to_string(),
            })?;
        if !environment.eq_ignore_ascii_case("SANDBOX") {
            return Err(SandboxRuntimeConfigError::InvalidEnvironment {
                actual: environment,
            });
        }

        let real_value = real_value.ok_or_else(|| SandboxRuntimeConfigError::RealValueEnabled {
            actual: "<unset>".to_string(),
        })?;
        if !real_value.eq_ignore_ascii_case("FALSE") {
            return Err(SandboxRuntimeConfigError::RealValueEnabled { actual: real_value });
        }

        let redeemable =
            redeemable.ok_or_else(|| SandboxRuntimeConfigError::RedeemableEnabled {
                actual: "<unset>".to_string(),
            })?;
        if !redeemable.eq_ignore_ascii_case("FALSE") {
            return Err(SandboxRuntimeConfigError::RedeemableEnabled { actual: redeemable });
        }

        Ok(Self {
            environment: "SANDBOX".to_string(),
            real_value: false,
            redeemable: false,
        })
    }

    pub fn environment(&self) -> &str {
        &self.environment
    }

    pub fn real_value(&self) -> bool {
        self.real_value
    }

    pub fn redeemable(&self) -> bool {
        self.redeemable
    }
}

#[derive(Clone)]
pub struct KaniNode {
    ledger: Arc<Mutex<InMemoryLedger>>,
    consensus: PoAConsensus,
    crypto_profile: CryptoProfile,
    storage: Option<PostgresLedgerStore>,
}

#[derive(Clone, Debug)]
pub struct ValidatorInfo {
    pub id: String,
    pub public_key: String,
    pub active: bool,
    pub last_seen_at: Option<DateTime<Utc>>,
    pub last_finalized_height: Option<i64>,
    pub last_finalized_hash: Option<String>,
    pub last_finalized_at: Option<DateTime<Utc>>,
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
        storage.ensure_sandbox_seed().await?;
        let ledger = InMemoryLedger::from_snapshot(storage.load_snapshot().await?);

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
        client_reference_id: Option<String>,
    ) -> Result<PaymentRecord, NodeError> {
        let from = from.into();
        let to = to.into();
        let asset = asset.into();
        let request_fingerprint =
            self.request_fingerprint(TransactionKind::Transfer, &from, &to, &asset, amount);

        if let Some(storage) = &self.storage {
            let nonce = storage.next_nonce_for_account(&from).await?;
            let mut tx = Transaction::new_transfer(from, to, asset, amount, nonce);
            if let Some(client_reference_id) = client_reference_id.as_deref() {
                tx.metadata.insert(
                    "client_reference_id".to_string(),
                    client_reference_id.to_string(),
                );
                tx.metadata.insert(
                    "request_fingerprint".to_string(),
                    request_fingerprint.clone(),
                );
            }
            return self
                .enqueue_postgres_payment(
                    storage,
                    tx,
                    client_reference_id,
                    Some(request_fingerprint),
                )
                .await;
        }

        let mut ledger = self.ledger.lock().await;
        if let Some(client_reference_id) = client_reference_id.as_deref() {
            if let Some(payment) = ledger.get_payment_by_client_reference_id(client_reference_id) {
                ensure_idempotent_retry(
                    &payment,
                    IdempotencyAttempt {
                        kind: TransactionKind::Transfer,
                        from: &from,
                        to: &to,
                        asset: &asset,
                        amount,
                        request_fingerprint: &request_fingerprint,
                        client_reference_id,
                    },
                )?;
                return Ok(payment);
            }
        }

        let nonce = ledger.next_nonce(&from);
        let mut tx = Transaction::new_transfer(from, to, asset, amount, nonce);
        if let Some(client_reference_id) = client_reference_id.as_deref() {
            tx.metadata.insert(
                "client_reference_id".to_string(),
                client_reference_id.to_string(),
            );
            tx.metadata.insert(
                "request_fingerprint".to_string(),
                request_fingerprint.clone(),
            );
        }
        self.produce_and_apply_locked(&mut ledger, vec![tx]).await
    }

    pub async fn mint_sandbox(
        &self,
        treasury: impl Into<String>,
        to: impl Into<String>,
        asset: impl Into<String>,
        amount: i128,
    ) -> Result<PaymentRecord, NodeError> {
        let treasury = treasury.into();
        let to = to.into();
        let asset = asset.into();

        if let Some(storage) = &self.storage {
            let nonce = storage.next_nonce_for_account(&treasury).await?;
            let tx = Transaction::new_mint(treasury, to, asset, amount, nonce);
            return Ok(storage.enqueue_pending_transaction(tx, None, None).await?);
        }

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
    ) -> Result<PaymentRecord, NodeError> {
        let from = from.into();
        let treasury = treasury.into();
        let asset = asset.into();

        if let Some(storage) = &self.storage {
            let nonce = storage.next_nonce_for_account(&from).await?;
            let tx = Transaction::new_burn(from, treasury, asset, amount, nonce);
            return Ok(storage.enqueue_pending_transaction(tx, None, None).await?);
        }

        let mut ledger = self.ledger.lock().await;
        let nonce = ledger.next_nonce(&from);
        let tx = Transaction::new_burn(from, treasury, asset, amount, nonce);
        self.produce_and_apply_locked(&mut ledger, vec![tx]).await
    }

    pub async fn get_payment(&self, payment_id: &str) -> Result<PaymentRecord, NodeError> {
        Ok(self.current_ledger().await?.get_payment(payment_id)?)
    }

    pub async fn balance(&self, account_id: &str, asset: &str) -> Result<i128, NodeError> {
        Ok(self.current_ledger().await?.balance(account_id, asset))
    }

    pub async fn issued(&self, asset: &str) -> Result<i128, NodeError> {
        Ok(self.current_ledger().await?.issued(asset))
    }

    pub async fn latest_block(&self) -> Result<Option<Block>, NodeError> {
        Ok(self.current_ledger().await?.latest_block())
    }

    pub async fn blocks(&self, search: BlockSearch) -> Result<Vec<Block>, NodeError> {
        if let Some(storage) = &self.storage {
            return Ok(storage.query_blocks(&search).await?);
        }

        Ok(search.apply(self.current_ledger().await?.blocks().to_vec()))
    }

    pub async fn accounts(&self) -> Result<Vec<Account>, NodeError> {
        Ok(self.current_ledger().await?.accounts())
    }

    pub async fn audit_events(
        &self,
        search: AuditEventSearch,
    ) -> Result<Vec<AuditEvent>, NodeError> {
        if let Some(storage) = &self.storage {
            return Ok(storage.query_audit_events(&search).await?);
        }

        Ok(search.apply(self.current_ledger().await?.audit_events().to_vec()))
    }

    pub async fn record_audit_event(&self, event: AuditEvent) -> Result<(), NodeError> {
        if let Some(storage) = &self.storage {
            storage.insert_audit_event(&event).await?;
            return Ok(());
        }

        let mut ledger = self.ledger.lock().await;
        ledger.record_audit_event(event);
        Ok(())
    }

    pub async fn pending_transactions(
        &self,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<Transaction>, NodeError> {
        if let Some(storage) = &self.storage {
            return Ok(storage.pending_transactions(limit, offset).await?);
        }

        Ok(Vec::new())
    }

    pub async fn validators(&self) -> Result<Vec<ValidatorInfo>, NodeError> {
        let statuses = if let Some(storage) = &self.storage {
            storage
                .validator_statuses()
                .await?
                .into_iter()
                .map(|status| (status.validator_id.clone(), status))
                .collect()
        } else {
            HashMap::new()
        };

        Ok(self
            .consensus
            .validators()
            .iter()
            .map(|validator| validator_info_from(validator, statuses.get(&validator.id)))
            .collect())
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
    ) -> Result<PaymentRecord, NodeError> {
        if txs.is_empty() {
            return Err(NodeError::EmptyBlock);
        }

        let block = self.build_block(ledger, txs)?;
        verify_phase1_block(ledger, &block, &self.consensus, &self.crypto_profile)?;
        let mut working_ledger = ledger.clone();
        let records = working_ledger.apply_block(block.clone())?;
        *ledger = working_ledger;

        records.into_iter().next().ok_or(NodeError::EmptyBlock)
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

        let block = block.seal(hash, signature, votes);
        verify_phase1_block(ledger, &block, &self.consensus, &self.crypto_profile)?;
        Ok(block)
    }

    async fn enqueue_postgres_payment(
        &self,
        storage: &PostgresLedgerStore,
        tx: Transaction,
        client_reference_id: Option<String>,
        request_fingerprint: Option<String>,
    ) -> Result<PaymentRecord, NodeError> {
        storage
            .enqueue_pending_transaction(tx, client_reference_id, request_fingerprint)
            .await
            .map_err(|error| match error {
                LedgerStorageError::IdempotencyConflict {
                    client_reference_id,
                    ..
                } => NodeError::IdempotencyConflict {
                    client_reference_id,
                },
                other => NodeError::Storage(other),
            })
    }

    fn request_fingerprint(
        &self,
        kind: TransactionKind,
        from: &str,
        to: &str,
        asset: &str,
        amount: i128,
    ) -> String {
        let payload = format!(
            "kind={}\nfrom={}\nto={}\nasset={}\namount={}\n",
            transaction_kind_fingerprint_value(kind),
            from,
            to,
            asset,
            amount
        );

        hash_bytes(&self.crypto_profile.hash, payload.as_bytes())
    }

    async fn current_ledger(&self) -> Result<InMemoryLedger, NodeError> {
        if let Some(storage) = &self.storage {
            return Ok(InMemoryLedger::from_snapshot(
                storage.load_snapshot().await?,
            ));
        }

        Ok(self.ledger.lock().await.clone())
    }
}

#[derive(Clone)]
pub struct ValidatorRuntime {
    storage: PostgresLedgerStore,
    consensus: PoAConsensus,
    crypto_profile: CryptoProfile,
    validator_id: String,
    max_transactions_per_block: i64,
}

impl ValidatorRuntime {
    pub async fn connect(
        database_url: &str,
        validator_id: impl Into<String>,
    ) -> Result<Self, NodeError> {
        let storage = PostgresLedgerStore::connect(database_url).await?;
        storage.run_migrations("migrations").await?;
        storage.ensure_sandbox_seed().await?;

        Ok(Self {
            storage,
            consensus: PoAConsensus::phase1_default(),
            crypto_profile: CryptoProfile::hybrid_pqc_v1(),
            validator_id: validator_id.into(),
            max_transactions_per_block: 25,
        })
    }

    pub fn with_max_transactions_per_block(mut self, max_transactions_per_block: i64) -> Self {
        self.max_transactions_per_block = max_transactions_per_block.max(1);
        self
    }

    pub async fn run_once(&self) -> Result<Option<Block>, NodeError> {
        self.storage
            .record_validator_heartbeat(&self.validator_id)
            .await?;

        let ledger = InMemoryLedger::from_snapshot(self.storage.load_snapshot().await?);
        let height = ledger.next_height();
        let leader = self.consensus.leader_for_height(height)?;

        if leader.id != self.validator_id {
            return Ok(None);
        }

        let Some(lock) = self.storage.try_acquire_block_production_lock().await? else {
            tracing::debug!(
                validator = %self.validator_id,
                height,
                "block production lock is busy"
            );
            return Ok(None);
        };

        let result = self.run_once_with_block_lock().await;
        if let Err(error) = lock.release().await {
            tracing::warn!(
                validator = %self.validator_id,
                %error,
                "failed to release block production lock"
            );
            if result.is_ok() {
                return Err(error.into());
            }
        }

        result
    }

    async fn run_once_with_block_lock(&self) -> Result<Option<Block>, NodeError> {
        let ledger = InMemoryLedger::from_snapshot(self.storage.load_snapshot().await?);
        let height = ledger.next_height();
        let leader = self.consensus.leader_for_height(height)?;

        if leader.id != self.validator_id {
            return Ok(None);
        }

        let pending = self
            .storage
            .pending_transactions(self.max_transactions_per_block, 0)
            .await?;
        if pending.is_empty() {
            return Ok(None);
        }

        let mut accepted = Vec::with_capacity(pending.len());
        for tx in pending {
            let mut candidate = accepted.clone();
            candidate.push(tx.clone());
            if let Err(error) = ledger.validate_transactions_for_next_block(&candidate) {
                self.reject_pending_transaction(&tx, &error.to_string())
                    .await?;
                continue;
            }

            accepted.push(tx);
        }

        if accepted.is_empty() {
            return Ok(None);
        }

        let block = build_block_for_validator(
            &ledger,
            accepted,
            &self.consensus,
            &self.crypto_profile,
            &self.validator_id,
        )?;
        verify_phase1_block(&ledger, &block, &self.consensus, &self.crypto_profile)?;
        let mut working_ledger = ledger;

        if let Err(error) = working_ledger.apply_block(block.clone()) {
            let reason = error.to_string();
            for tx in &block.txs {
                self.reject_pending_transaction(tx, &reason).await?;
            }
            return Err(error.into());
        }

        self.storage
            .save_snapshot(&working_ledger.snapshot())
            .await?;
        self.storage
            .record_validator_finalized_block(&self.validator_id, &block)
            .await?;
        Ok(Some(block))
    }

    async fn reject_pending_transaction(
        &self,
        tx: &Transaction,
        reason: &str,
    ) -> Result<(), NodeError> {
        self.storage.reject_transaction(&tx.id, reason).await?;

        let mut metadata = BTreeMap::new();
        metadata.insert("asset".to_string(), tx.asset.clone());
        metadata.insert("from".to_string(), tx.from.clone());
        metadata.insert(
            "kind".to_string(),
            transaction_kind_fingerprint_value(tx.kind).to_string(),
        );
        metadata.insert("reason".to_string(), reason.to_string());
        metadata.insert("to".to_string(), tx.to.clone());
        metadata.insert("transaction_id".to_string(), tx.id.clone());
        metadata.insert("validator".to_string(), self.validator_id.clone());

        let event = AuditEvent::new(
            "TRANSACTION_REJECTED",
            format!(
                "transaction {} rejected by validator {}: {}",
                tx.id, self.validator_id, reason
            ),
            None,
            Some(tx.id.clone()),
        )
        .with_metadata(metadata);

        self.storage.insert_audit_event(&event).await?;
        Ok(())
    }

    pub async fn run_forever(&self, poll_interval: std::time::Duration) -> Result<(), NodeError> {
        loop {
            match self.run_once().await {
                Ok(Some(block)) => {
                    tracing::info!(
                        validator = %self.validator_id,
                        height = block.height,
                        tx_count = block.txs.len(),
                        "finalized block"
                    );
                }
                Ok(None) => {}
                Err(error) => {
                    tracing::warn!(validator = %self.validator_id, %error, "validator pass failed");
                }
            }

            tokio::time::sleep(poll_interval).await;
        }
    }
}

fn validator_info_from(validator: &Validator, status: Option<&ValidatorStatus>) -> ValidatorInfo {
    ValidatorInfo {
        id: validator.id.clone(),
        public_key: validator.public_key.clone(),
        active: validator.active,
        last_seen_at: status.map(|status| status.last_seen_at.to_owned()),
        last_finalized_height: status.and_then(|status| status.last_finalized_height),
        last_finalized_hash: status.and_then(|status| status.last_finalized_hash.clone()),
        last_finalized_at: status.and_then(|status| status.last_finalized_at.to_owned()),
    }
}

struct IdempotencyAttempt<'a> {
    kind: TransactionKind,
    from: &'a str,
    to: &'a str,
    asset: &'a str,
    amount: i128,
    request_fingerprint: &'a str,
    client_reference_id: &'a str,
}

fn ensure_idempotent_retry(
    payment: &PaymentRecord,
    attempt: IdempotencyAttempt<'_>,
) -> Result<(), NodeError> {
    let fingerprint_matches = payment
        .request_fingerprint
        .as_deref()
        .map(|existing| existing == attempt.request_fingerprint)
        .unwrap_or_else(|| {
            payment.transaction.kind == attempt.kind
                && payment.transaction.from == attempt.from
                && payment.transaction.to == attempt.to
                && payment.transaction.asset == attempt.asset
                && payment.transaction.amount == attempt.amount
        });

    if fingerprint_matches {
        return Ok(());
    }

    Err(NodeError::IdempotencyConflict {
        client_reference_id: attempt.client_reference_id.to_string(),
    })
}

fn transaction_kind_fingerprint_value(kind: TransactionKind) -> &'static str {
    match kind {
        TransactionKind::Mint => "MINT",
        TransactionKind::Burn => "BURN",
        TransactionKind::Transfer => "TRANSFER",
    }
}

fn build_block_for_validator(
    ledger: &InMemoryLedger,
    txs: Vec<Transaction>,
    consensus: &PoAConsensus,
    crypto_profile: &CryptoProfile,
    validator_id: &str,
) -> Result<Block, NodeError> {
    if txs.is_empty() {
        return Err(NodeError::EmptyBlock);
    }

    let height = ledger.next_height();
    let votes = consensus.finality_votes_for_block(height)?;
    let required = consensus.finality_threshold();
    if votes.len() < required {
        return Err(NodeError::InsufficientFinality {
            got: votes.len(),
            required,
        });
    }

    let block = Block::new_unsealed(height, ledger.last_hash(), txs, validator_id);
    let hash = hash_json(&crypto_profile.hash, &block)?;
    let signature = sandbox_validator_signature(crypto_profile, validator_id, &hash);

    let block = block.seal(hash, signature, votes);
    verify_phase1_block(ledger, &block, consensus, crypto_profile)?;
    Ok(block)
}

fn verify_phase1_block(
    ledger: &InMemoryLedger,
    block: &Block,
    consensus: &PoAConsensus,
    crypto_profile: &CryptoProfile,
) -> Result<(), NodeError> {
    if block.txs.is_empty() {
        return Err(NodeError::EmptyBlock);
    }

    let leader = consensus.leader_for_height(block.height)?;
    if block.validator != leader.id {
        return Err(NodeError::InvalidBlockValidator {
            expected: leader.id,
            actual: block.validator.clone(),
        });
    }

    let required = consensus.finality_threshold();
    if block.finalized_by.len() < required {
        return Err(NodeError::InsufficientFinality {
            got: block.finalized_by.len(),
            required,
        });
    }

    let active_validators: BTreeSet<String> = consensus
        .active_validators()
        .into_iter()
        .map(|validator| validator.id.clone())
        .collect();
    let mut seen = BTreeSet::new();
    for validator_id in &block.finalized_by {
        if !active_validators.contains(validator_id) {
            return Err(NodeError::UnknownFinalityValidator(validator_id.clone()));
        }

        if !seen.insert(validator_id.clone()) {
            return Err(NodeError::DuplicateFinalityVote(validator_id.clone()));
        }
    }

    if !seen.contains(&block.validator) {
        return Err(NodeError::MissingProducerFinalityVote(
            block.validator.clone(),
        ));
    }

    let mut unsealed = block.clone();
    unsealed.hash.clear();
    unsealed.signature.clear();
    unsealed.finalized_by.clear();
    let expected_hash = hash_json(&crypto_profile.hash, &unsealed)?;
    if block.hash != expected_hash {
        return Err(NodeError::InvalidBlockHash {
            expected: expected_hash,
            actual: block.hash.clone(),
        });
    }

    let expected_signature =
        sandbox_validator_signature(crypto_profile, &block.validator, &block.hash);
    if block.signature != expected_signature {
        return Err(NodeError::InvalidBlockSignature {
            validator: block.validator.clone(),
            hash: block.hash.clone(),
        });
    }

    ledger.validate_transactions_for_next_block(&block.txs)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use kani_types::{
        TransactionStatus, KCAD_TEST, SANDBOX_CORP_A_ACCOUNT, SANDBOX_CORP_B_ACCOUNT,
        SANDBOX_TREASURY_ACCOUNT,
    };

    #[test]
    fn sandbox_runtime_config_accepts_phase1_flags() {
        let config = SandboxRuntimeConfig::from_values(
            Some("SANDBOX".to_string()),
            Some("FALSE".to_string()),
            Some("FALSE".to_string()),
        )
        .unwrap();

        assert_eq!(config.environment(), "SANDBOX");
        assert!(!config.real_value());
        assert!(!config.redeemable());
    }

    #[test]
    fn sandbox_runtime_config_rejects_unsafe_flags() {
        let missing_env = SandboxRuntimeConfig::from_values(
            None,
            Some("FALSE".to_string()),
            Some("FALSE".to_string()),
        )
        .unwrap_err();
        assert!(matches!(
            missing_env,
            SandboxRuntimeConfigError::InvalidEnvironment { .. }
        ));

        let real_value_enabled = SandboxRuntimeConfig::from_values(
            Some("SANDBOX".to_string()),
            Some("TRUE".to_string()),
            Some("FALSE".to_string()),
        )
        .unwrap_err();
        assert!(matches!(
            real_value_enabled,
            SandboxRuntimeConfigError::RealValueEnabled { .. }
        ));

        let redeemable_enabled = SandboxRuntimeConfig::from_values(
            Some("SANDBOX".to_string()),
            Some("FALSE".to_string()),
            Some("TRUE".to_string()),
        )
        .unwrap_err();
        assert!(matches!(
            redeemable_enabled,
            SandboxRuntimeConfigError::RedeemableEnabled { .. }
        ));
    }

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
        assert_eq!(mint.status, TransactionStatus::Finalized);
        assert_eq!(mint.block_height, Some(1));

        let payment = node
            .submit_payment(
                SANDBOX_CORP_A_ACCOUNT,
                SANDBOX_CORP_B_ACCOUNT,
                KCAD_TEST,
                100_000,
                None,
            )
            .await
            .unwrap();

        assert_eq!(payment.status, TransactionStatus::Finalized);
        assert_eq!(payment.block_height, Some(2));
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
        assert!(node.get_payment(&payment.transaction.id).await.is_ok());
    }

    #[tokio::test]
    async fn node_rejects_idempotency_key_conflicts() {
        let node = KaniNode::sandbox_default();

        node.mint_sandbox(
            SANDBOX_TREASURY_ACCOUNT,
            SANDBOX_CORP_A_ACCOUNT,
            KCAD_TEST,
            1_000_000,
        )
        .await
        .unwrap();

        let payment = node
            .submit_payment(
                SANDBOX_CORP_A_ACCOUNT,
                SANDBOX_CORP_B_ACCOUNT,
                KCAD_TEST,
                100_000,
                Some("unit-test-transfer".to_string()),
            )
            .await
            .unwrap();
        let retry = node
            .submit_payment(
                SANDBOX_CORP_A_ACCOUNT,
                SANDBOX_CORP_B_ACCOUNT,
                KCAD_TEST,
                100_000,
                Some("unit-test-transfer".to_string()),
            )
            .await
            .unwrap();

        assert_eq!(payment.transaction.id, retry.transaction.id);

        let conflict = node
            .submit_payment(
                SANDBOX_CORP_A_ACCOUNT,
                SANDBOX_CORP_B_ACCOUNT,
                KCAD_TEST,
                200_000,
                Some("unit-test-transfer".to_string()),
            )
            .await
            .unwrap_err();

        assert!(matches!(conflict, NodeError::IdempotencyConflict { .. }));
    }

    #[test]
    fn phase1_block_integrity_rejects_tampered_hash_and_signature() {
        let (ledger, mut block, consensus, crypto_profile) = integrity_fixture();
        block.hash = "tampered-hash".to_string();

        assert!(matches!(
            verify_phase1_block(&ledger, &block, &consensus, &crypto_profile),
            Err(NodeError::InvalidBlockHash { .. })
        ));

        let (ledger, mut block, consensus, crypto_profile) = integrity_fixture();
        block.signature.push(0);

        assert!(matches!(
            verify_phase1_block(&ledger, &block, &consensus, &crypto_profile),
            Err(NodeError::InvalidBlockSignature { .. })
        ));
    }

    #[test]
    fn phase1_block_integrity_rejects_invalid_validator_and_votes() {
        let (ledger, tx, consensus, crypto_profile) = integrity_inputs();
        let invalid_validator = build_block_for_validator(
            &ledger,
            vec![tx],
            &consensus,
            &crypto_profile,
            "validator-b",
        )
        .unwrap_err();
        assert!(matches!(
            invalid_validator,
            NodeError::InvalidBlockValidator { .. }
        ));

        let (ledger, mut block, consensus, crypto_profile) = integrity_fixture();
        block.finalized_by = vec!["validator-a".to_string(), "validator-a".to_string()];
        assert!(matches!(
            verify_phase1_block(&ledger, &block, &consensus, &crypto_profile),
            Err(NodeError::DuplicateFinalityVote(_))
        ));

        let (ledger, mut block, consensus, crypto_profile) = integrity_fixture();
        block.finalized_by = vec!["validator-a".to_string(), "validator-x".to_string()];
        assert!(matches!(
            verify_phase1_block(&ledger, &block, &consensus, &crypto_profile),
            Err(NodeError::UnknownFinalityValidator(_))
        ));

        let (ledger, mut block, consensus, crypto_profile) = integrity_fixture();
        block.finalized_by = vec!["validator-b".to_string(), "validator-c".to_string()];
        assert!(matches!(
            verify_phase1_block(&ledger, &block, &consensus, &crypto_profile),
            Err(NodeError::MissingProducerFinalityVote(_))
        ));
    }

    fn integrity_fixture() -> (InMemoryLedger, Block, PoAConsensus, CryptoProfile) {
        let (ledger, tx, consensus, crypto_profile) = integrity_inputs();
        let block = build_block_for_validator(
            &ledger,
            vec![tx],
            &consensus,
            &crypto_profile,
            "validator-a",
        )
        .unwrap();

        (ledger, block, consensus, crypto_profile)
    }

    fn integrity_inputs() -> (InMemoryLedger, Transaction, PoAConsensus, CryptoProfile) {
        let ledger = InMemoryLedger::sandbox();
        let tx = Transaction::new_mint(
            SANDBOX_TREASURY_ACCOUNT,
            SANDBOX_CORP_A_ACCOUNT,
            KCAD_TEST,
            1_000,
            ledger.next_nonce(SANDBOX_TREASURY_ACCOUNT),
        );
        (
            ledger,
            tx,
            PoAConsensus::phase1_default(),
            CryptoProfile::hybrid_pqc_v1(),
        )
    }
}
