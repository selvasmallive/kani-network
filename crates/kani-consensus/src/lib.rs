use chrono::Utc;
use kani_types::{
    ConsensusProposal, ConsensusValidator, ConsensusVote, ConsensusVoteKind, FinalityProof,
    QuorumCertificate, ValidatorSet,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use thiserror::Error;

pub const PHASE1_POA_ENGINE_ID: &str = "phase1-poa";
pub const SANDBOX_BFT_ENGINE_ID: &str = "sandbox-bft-prototype";
pub const SANDBOX_BFT_VALIDATOR_SET_ID: &str = "sandbox-bft-v1";
pub const SANDBOX_BFT_EPOCH: i64 = 1;

#[derive(Debug, Error)]
pub enum ConsensusError {
    #[error("phase 1 PoA requires at least 3 active validators")]
    NotEnoughValidators,
    #[error("invalid block height {0}")]
    InvalidHeight(i64),
    #[error("validator {0} is not active")]
    InactiveValidator(String),
    #[error("unsupported consensus engine {0}")]
    UnsupportedEngine(String),
    #[error("BFT prototype requires sandbox engine id {expected}, got {actual}")]
    BftPrototypeNotEnabled { expected: String, actual: String },
    #[error("quorum certificate epoch mismatch: expected {expected}, got {actual}")]
    InvalidEpoch { expected: i64, actual: i64 },
    #[error("finality proof validator set mismatch: expected {expected}, got {actual}")]
    InvalidValidatorSet { expected: String, actual: String },
    #[error("quorum certificate block hash is empty")]
    EmptyBlockHash,
    #[error("quorum certificate threshold not met: got {got}, required {required}")]
    InvalidQuorum { got: usize, required: usize },
    #[error("duplicate consensus vote from validator {0}")]
    DuplicateVote(String),
    #[error("finality proof block hash mismatch: expected {expected}, got {actual}")]
    FinalityProofBlockHashMismatch { expected: String, actual: String },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Validator {
    pub id: String,
    pub public_key: String,
    pub active: bool,
}

impl Validator {
    pub fn active(id: impl Into<String>, public_key: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            public_key: public_key.into(),
            active: true,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ConsensusAlgorithm {
    Poa,
    Bft,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ConsensusEngineConfig {
    pub engine_id: String,
    pub algorithm: ConsensusAlgorithm,
    pub validators: Vec<Validator>,
}

impl ConsensusEngineConfig {
    pub fn phase1_poa() -> Self {
        Self {
            engine_id: PHASE1_POA_ENGINE_ID.to_string(),
            algorithm: ConsensusAlgorithm::Poa,
            validators: phase1_default_validators(),
        }
    }

    pub fn sandbox_bft_prototype() -> Self {
        Self {
            engine_id: SANDBOX_BFT_ENGINE_ID.to_string(),
            algorithm: ConsensusAlgorithm::Bft,
            validators: phase1_default_validators(),
        }
    }

    pub fn build_engine(&self) -> Result<ConfiguredConsensusEngine, ConsensusError> {
        match self.algorithm {
            ConsensusAlgorithm::Poa => Ok(ConfiguredConsensusEngine::Poa(
                PoAConsensus::new_phase1(self.validators.clone())?,
            )),
            ConsensusAlgorithm::Bft => {
                if self.engine_id != SANDBOX_BFT_ENGINE_ID {
                    return Err(ConsensusError::BftPrototypeNotEnabled {
                        expected: SANDBOX_BFT_ENGINE_ID.to_string(),
                        actual: self.engine_id.clone(),
                    });
                }

                Ok(ConfiguredConsensusEngine::Bft(
                    BftConsensus::new_sandbox_prototype(self.validators.clone())?,
                ))
            }
        }
    }
}

pub trait ConsensusEngine {
    fn engine_id(&self) -> &str;
    fn algorithm(&self) -> ConsensusAlgorithm;
    fn validators(&self) -> &[Validator];
    fn finality_threshold(&self) -> usize;
    fn leader_for_height(&self, height: i64) -> Result<Validator, ConsensusError>;
    fn finality_votes_for_block(&self, height: i64) -> Result<Vec<String>, ConsensusError>;

    fn active_validators(&self) -> Vec<&Validator> {
        self.validators()
            .iter()
            .filter(|validator| validator.active)
            .collect()
    }
}

#[derive(Clone, Debug)]
pub enum ConfiguredConsensusEngine {
    Poa(PoAConsensus),
    Bft(BftConsensus),
}

impl ConsensusEngine for ConfiguredConsensusEngine {
    fn engine_id(&self) -> &str {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.engine_id(),
            ConfiguredConsensusEngine::Bft(engine) => engine.engine_id(),
        }
    }

    fn algorithm(&self) -> ConsensusAlgorithm {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.algorithm(),
            ConfiguredConsensusEngine::Bft(engine) => engine.algorithm(),
        }
    }

    fn validators(&self) -> &[Validator] {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.validators(),
            ConfiguredConsensusEngine::Bft(engine) => engine.validators(),
        }
    }

    fn finality_threshold(&self) -> usize {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.finality_threshold(),
            ConfiguredConsensusEngine::Bft(engine) => engine.finality_threshold(),
        }
    }

    fn leader_for_height(&self, height: i64) -> Result<Validator, ConsensusError> {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.leader_for_height(height),
            ConfiguredConsensusEngine::Bft(engine) => engine.leader_for_height(height),
        }
    }

    fn finality_votes_for_block(&self, height: i64) -> Result<Vec<String>, ConsensusError> {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.finality_votes_for_block(height),
            ConfiguredConsensusEngine::Bft(engine) => engine.finality_votes_for_block(height),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BftFinalityPrototype {
    pub validator_set: ValidatorSet,
    pub proposal: ConsensusProposal,
    pub prevotes: Vec<ConsensusVote>,
    pub precommits: Vec<ConsensusVote>,
    pub precommit_qc: QuorumCertificate,
    pub finality_proof: FinalityProof,
}

#[derive(Clone, Debug)]
pub struct BftConsensus {
    engine_id: String,
    validators: Vec<Validator>,
    validator_set: ValidatorSet,
    epoch: i64,
}

impl BftConsensus {
    pub fn new_sandbox_prototype(validators: Vec<Validator>) -> Result<Self, ConsensusError> {
        let active_count = validators
            .iter()
            .filter(|validator| validator.active)
            .count();
        if active_count < 3 {
            return Err(ConsensusError::NotEnoughValidators);
        }

        let validator_set = ValidatorSet {
            id: SANDBOX_BFT_VALIDATOR_SET_ID.to_string(),
            epoch: SANDBOX_BFT_EPOCH,
            validators: validators
                .iter()
                .map(|validator| ConsensusValidator {
                    id: validator.id.clone(),
                    public_key: validator.public_key.clone(),
                    voting_power: if validator.active { 1 } else { 0 },
                    active: validator.active,
                })
                .collect(),
            created_at: Utc::now(),
        };

        Ok(Self {
            engine_id: SANDBOX_BFT_ENGINE_ID.to_string(),
            validators,
            validator_set,
            epoch: SANDBOX_BFT_EPOCH,
        })
    }

    pub fn sandbox_default() -> Self {
        Self::new_sandbox_prototype(phase1_default_validators())
            .expect("default validator set satisfies sandbox BFT prototype")
    }

    pub fn engine_id(&self) -> &str {
        &self.engine_id
    }

    pub fn validators(&self) -> &[Validator] {
        &self.validators
    }

    pub fn validator_set(&self) -> &ValidatorSet {
        &self.validator_set
    }

    pub fn epoch(&self) -> i64 {
        self.epoch
    }

    pub fn active_validators(&self) -> Vec<&Validator> {
        self.validators
            .iter()
            .filter(|validator| validator.active)
            .collect()
    }

    pub fn finality_threshold(&self) -> usize {
        let active = self.active_validators().len();
        (active * 2 / 3) + 1
    }

    pub fn leader_for_height(&self, height: i64) -> Result<Validator, ConsensusError> {
        if height < 1 {
            return Err(ConsensusError::InvalidHeight(height));
        }

        let active = self.active_validators();
        if active.len() < 3 {
            return Err(ConsensusError::NotEnoughValidators);
        }

        let index = ((height - 1) as usize) % active.len();
        Ok((*active[index]).clone())
    }

    pub fn finality_votes_for_block(&self, height: i64) -> Result<Vec<String>, ConsensusError> {
        let active = self.active_validators();
        if active.len() < 3 {
            return Err(ConsensusError::NotEnoughValidators);
        }

        let leader = self.leader_for_height(height)?;
        let leader_index = active
            .iter()
            .position(|validator| validator.id == leader.id)
            .ok_or_else(|| ConsensusError::InactiveValidator(leader.id.clone()))?;

        let threshold = self.finality_threshold();
        Ok((0..threshold)
            .map(|offset| active[(leader_index + offset) % active.len()].id.clone())
            .collect())
    }

    pub fn simulate_finality_proof(
        &self,
        height: i64,
        prev_hash: impl Into<String>,
        block_hash: impl Into<String>,
    ) -> Result<BftFinalityPrototype, ConsensusError> {
        let round = 0;
        let block_hash = block_hash.into();
        if block_hash.trim().is_empty() {
            return Err(ConsensusError::EmptyBlockHash);
        }

        let proposer = self.leader_for_height(height)?;
        let proposal = ConsensusProposal {
            id: format!(
                "{}:{}:{}:{}",
                self.validator_set.id, height, round, block_hash
            ),
            height,
            round,
            epoch: self.epoch,
            proposer: proposer.id,
            block_hash: block_hash.clone(),
            prev_hash: prev_hash.into(),
            created_at: Utc::now(),
        };

        let voters = self.finality_votes_for_block(height)?;
        let prevotes = self.build_votes(&proposal, &voters, ConsensusVoteKind::Prevote);
        let precommits = self.build_votes(&proposal, &voters, ConsensusVoteKind::Precommit);
        let precommit_qc = self.build_certificate(&proposal, &voters, ConsensusVoteKind::Precommit);
        self.verify_quorum_certificate(&precommit_qc)?;

        let finality_proof = FinalityProof {
            block_height: height,
            block_hash: block_hash.clone(),
            validator_set_id: self.validator_set.id.clone(),
            quorum_certificate: precommit_qc.clone(),
            finalized_at: Utc::now(),
        };
        self.verify_finality_proof(&finality_proof)?;

        Ok(BftFinalityPrototype {
            validator_set: self.validator_set.clone(),
            proposal,
            prevotes,
            precommits,
            precommit_qc,
            finality_proof,
        })
    }

    pub fn verify_quorum_certificate(
        &self,
        certificate: &QuorumCertificate,
    ) -> Result<(), ConsensusError> {
        if certificate.epoch != self.epoch {
            return Err(ConsensusError::InvalidEpoch {
                expected: self.epoch,
                actual: certificate.epoch,
            });
        }

        if certificate.block_hash.trim().is_empty() {
            return Err(ConsensusError::EmptyBlockHash);
        }

        let required = self.finality_threshold();
        if certificate.voters.len() < required {
            return Err(ConsensusError::InvalidQuorum {
                got: certificate.voters.len(),
                required,
            });
        }

        let active_validators: BTreeSet<String> = self
            .active_validators()
            .into_iter()
            .map(|validator| validator.id.clone())
            .collect();
        let mut seen = BTreeSet::new();
        for voter in &certificate.voters {
            if !active_validators.contains(voter) {
                return Err(ConsensusError::InactiveValidator(voter.clone()));
            }

            if !seen.insert(voter.clone()) {
                return Err(ConsensusError::DuplicateVote(voter.clone()));
            }
        }

        Ok(())
    }

    pub fn verify_finality_proof(&self, proof: &FinalityProof) -> Result<(), ConsensusError> {
        if proof.validator_set_id != self.validator_set.id {
            return Err(ConsensusError::InvalidValidatorSet {
                expected: self.validator_set.id.clone(),
                actual: proof.validator_set_id.clone(),
            });
        }

        if proof.block_hash != proof.quorum_certificate.block_hash {
            return Err(ConsensusError::FinalityProofBlockHashMismatch {
                expected: proof.block_hash.clone(),
                actual: proof.quorum_certificate.block_hash.clone(),
            });
        }

        self.verify_quorum_certificate(&proof.quorum_certificate)
    }

    fn build_votes(
        &self,
        proposal: &ConsensusProposal,
        voters: &[String],
        vote_kind: ConsensusVoteKind,
    ) -> Vec<ConsensusVote> {
        voters
            .iter()
            .map(|voter| ConsensusVote {
                id: format!(
                    "{}:{}:{}:{}",
                    proposal.id,
                    vote_kind_label(vote_kind),
                    proposal.round,
                    voter
                ),
                proposal_id: proposal.id.clone(),
                height: proposal.height,
                round: proposal.round,
                epoch: proposal.epoch,
                voter: voter.clone(),
                vote_kind,
                block_hash: proposal.block_hash.clone(),
                signature: prototype_signature(voter, &proposal.id, &proposal.block_hash),
                created_at: Utc::now(),
            })
            .collect()
    }

    fn build_certificate(
        &self,
        proposal: &ConsensusProposal,
        voters: &[String],
        vote_kind: ConsensusVoteKind,
    ) -> QuorumCertificate {
        QuorumCertificate {
            id: format!("{}:{}:{}", proposal.id, vote_kind_label(vote_kind), "qc"),
            height: proposal.height,
            round: proposal.round,
            epoch: proposal.epoch,
            block_hash: proposal.block_hash.clone(),
            vote_kind,
            voters: voters.to_vec(),
            signature: prototype_signature("quorum", &proposal.id, &proposal.block_hash),
            created_at: Utc::now(),
        }
    }
}

impl ConsensusEngine for BftConsensus {
    fn engine_id(&self) -> &str {
        &self.engine_id
    }

    fn algorithm(&self) -> ConsensusAlgorithm {
        ConsensusAlgorithm::Bft
    }

    fn validators(&self) -> &[Validator] {
        BftConsensus::validators(self)
    }

    fn finality_threshold(&self) -> usize {
        BftConsensus::finality_threshold(self)
    }

    fn leader_for_height(&self, height: i64) -> Result<Validator, ConsensusError> {
        BftConsensus::leader_for_height(self, height)
    }

    fn finality_votes_for_block(&self, height: i64) -> Result<Vec<String>, ConsensusError> {
        BftConsensus::finality_votes_for_block(self, height)
    }
}

#[derive(Clone, Debug)]
pub struct PoAConsensus {
    engine_id: String,
    validators: Vec<Validator>,
}

impl PoAConsensus {
    pub fn new_phase1(validators: Vec<Validator>) -> Result<Self, ConsensusError> {
        let consensus = Self {
            engine_id: PHASE1_POA_ENGINE_ID.to_string(),
            validators,
        };
        if consensus.active_validators().len() < 3 {
            return Err(ConsensusError::NotEnoughValidators);
        }
        Ok(consensus)
    }

    pub fn phase1_default() -> Self {
        Self::new_phase1(phase1_default_validators())
            .expect("default validator set satisfies phase 1")
    }

    pub fn validators(&self) -> &[Validator] {
        &self.validators
    }

    pub fn active_validators(&self) -> Vec<&Validator> {
        self.validators
            .iter()
            .filter(|validator| validator.active)
            .collect()
    }

    pub fn finality_threshold(&self) -> usize {
        let active = self.active_validators().len();
        (active * 2).div_ceil(3)
    }

    pub fn leader_for_height(&self, height: i64) -> Result<Validator, ConsensusError> {
        if height < 1 {
            return Err(ConsensusError::InvalidHeight(height));
        }

        let active = self.active_validators();
        if active.len() < 3 {
            return Err(ConsensusError::NotEnoughValidators);
        }

        let index = ((height - 1) as usize) % active.len();
        Ok((*active[index]).clone())
    }

    pub fn finality_votes_for_block(&self, height: i64) -> Result<Vec<String>, ConsensusError> {
        let active = self.active_validators();
        if active.len() < 3 {
            return Err(ConsensusError::NotEnoughValidators);
        }

        let leader = self.leader_for_height(height)?;
        let leader_index = active
            .iter()
            .position(|validator| validator.id == leader.id)
            .ok_or_else(|| ConsensusError::InactiveValidator(leader.id.clone()))?;

        let threshold = self.finality_threshold();
        Ok((0..threshold)
            .map(|offset| active[(leader_index + offset) % active.len()].id.clone())
            .collect())
    }
}

impl ConsensusEngine for PoAConsensus {
    fn engine_id(&self) -> &str {
        &self.engine_id
    }

    fn algorithm(&self) -> ConsensusAlgorithm {
        ConsensusAlgorithm::Poa
    }

    fn validators(&self) -> &[Validator] {
        PoAConsensus::validators(self)
    }

    fn finality_threshold(&self) -> usize {
        PoAConsensus::finality_threshold(self)
    }

    fn leader_for_height(&self, height: i64) -> Result<Validator, ConsensusError> {
        PoAConsensus::leader_for_height(self, height)
    }

    fn finality_votes_for_block(&self, height: i64) -> Result<Vec<String>, ConsensusError> {
        PoAConsensus::finality_votes_for_block(self, height)
    }
}

fn vote_kind_label(vote_kind: ConsensusVoteKind) -> &'static str {
    match vote_kind {
        ConsensusVoteKind::Prevote => "prevote",
        ConsensusVoteKind::Precommit => "precommit",
        ConsensusVoteKind::Finality => "finality",
    }
}

fn prototype_signature(voter: &str, proposal_id: &str, block_hash: &str) -> Vec<u8> {
    format!("sandbox-bft-signature:{voter}:{proposal_id}:{block_hash}").into_bytes()
}

pub fn phase1_default_validators() -> Vec<Validator> {
    vec![
        Validator::active("validator-a", "sandbox-pubkey-a"),
        Validator::active("validator-b", "sandbox-pubkey-b"),
        Validator::active("validator-c", "sandbox-pubkey-c"),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn phase1_rotates_leader_and_requires_two_of_three() {
        let consensus = PoAConsensus::phase1_default();

        assert_eq!(consensus.finality_threshold(), 2);
        assert_eq!(consensus.leader_for_height(1).unwrap().id, "validator-a");
        assert_eq!(consensus.leader_for_height(2).unwrap().id, "validator-b");
        assert_eq!(consensus.leader_for_height(3).unwrap().id, "validator-c");
        assert_eq!(consensus.leader_for_height(4).unwrap().id, "validator-a");
    }

    #[test]
    fn phase1_poa_builds_through_consensus_engine_config() {
        let config = ConsensusEngineConfig::phase1_poa();
        let engine = config.build_engine().unwrap();

        assert_eq!(engine.engine_id(), PHASE1_POA_ENGINE_ID);
        assert_eq!(engine.algorithm(), ConsensusAlgorithm::Poa);
        assert_eq!(engine.finality_threshold(), 2);
        assert_eq!(engine.leader_for_height(1).unwrap().id, "validator-a");
    }

    #[test]
    fn bft_engine_requires_sandbox_prototype_id() {
        let config = ConsensusEngineConfig {
            engine_id: "production-bft".to_string(),
            algorithm: ConsensusAlgorithm::Bft,
            validators: phase1_default_validators(),
        };

        assert!(matches!(
            config.build_engine(),
            Err(ConsensusError::BftPrototypeNotEnabled { .. })
        ));
    }

    #[test]
    fn sandbox_bft_prototype_builds_through_config() {
        let config = ConsensusEngineConfig::sandbox_bft_prototype();
        let engine = config.build_engine().unwrap();

        assert_eq!(engine.engine_id(), SANDBOX_BFT_ENGINE_ID);
        assert_eq!(engine.algorithm(), ConsensusAlgorithm::Bft);
        assert_eq!(engine.finality_threshold(), 3);
        assert_eq!(
            engine.finality_votes_for_block(1).unwrap(),
            vec![
                "validator-a".to_string(),
                "validator-b".to_string(),
                "validator-c".to_string()
            ]
        );
    }

    #[test]
    fn sandbox_bft_prototype_simulates_proposal_votes_and_finality() {
        let consensus = BftConsensus::sandbox_default();
        let proof = consensus
            .simulate_finality_proof(1, "KANI_GENESIS_V1", "block-hash-1")
            .unwrap();

        assert_eq!(proof.validator_set.id, SANDBOX_BFT_VALIDATOR_SET_ID);
        assert_eq!(proof.validator_set.epoch, SANDBOX_BFT_EPOCH);
        assert_eq!(proof.proposal.height, 1);
        assert_eq!(proof.proposal.round, 0);
        assert_eq!(proof.proposal.proposer, "validator-a");
        assert_eq!(proof.proposal.block_hash, "block-hash-1");
        assert_eq!(proof.prevotes.len(), 3);
        assert_eq!(proof.precommits.len(), 3);
        assert_eq!(proof.precommit_qc.vote_kind, ConsensusVoteKind::Precommit);
        assert_eq!(proof.precommit_qc.voters.len(), 3);
        assert_eq!(proof.finality_proof.block_height, 1);
        assert_eq!(proof.finality_proof.block_hash, "block-hash-1");

        consensus
            .verify_finality_proof(&proof.finality_proof)
            .unwrap();
    }

    #[test]
    fn sandbox_bft_rejects_invalid_quorum_certificates() {
        let consensus = BftConsensus::sandbox_default();
        let proof = consensus
            .simulate_finality_proof(1, "KANI_GENESIS_V1", "block-hash-1")
            .unwrap();

        let mut under_threshold = proof.precommit_qc.clone();
        under_threshold.voters = vec!["validator-a".to_string(), "validator-b".to_string()];
        assert!(matches!(
            consensus.verify_quorum_certificate(&under_threshold),
            Err(ConsensusError::InvalidQuorum {
                got: 2,
                required: 3
            })
        ));

        let mut duplicate = proof.precommit_qc.clone();
        duplicate.voters = vec![
            "validator-a".to_string(),
            "validator-b".to_string(),
            "validator-a".to_string(),
        ];
        assert!(matches!(
            consensus.verify_quorum_certificate(&duplicate),
            Err(ConsensusError::DuplicateVote(voter)) if voter == "validator-a"
        ));

        let mut wrong_set = proof.finality_proof.clone();
        wrong_set.validator_set_id = "production-validator-set".to_string();
        assert!(matches!(
            consensus.verify_finality_proof(&wrong_set),
            Err(ConsensusError::InvalidValidatorSet { .. })
        ));
    }
}
