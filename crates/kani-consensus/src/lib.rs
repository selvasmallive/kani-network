use serde::{Deserialize, Serialize};
use thiserror::Error;

pub const PHASE1_POA_ENGINE_ID: &str = "phase1-poa";

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

    pub fn build_engine(&self) -> Result<ConfiguredConsensusEngine, ConsensusError> {
        match self.algorithm {
            ConsensusAlgorithm::Poa => Ok(ConfiguredConsensusEngine::Poa(
                PoAConsensus::new_phase1(self.validators.clone())?,
            )),
            ConsensusAlgorithm::Bft => Err(ConsensusError::UnsupportedEngine(
                "BFT consensus is planned for a later sandbox slice".to_string(),
            )),
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
}

impl ConsensusEngine for ConfiguredConsensusEngine {
    fn engine_id(&self) -> &str {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.engine_id(),
        }
    }

    fn algorithm(&self) -> ConsensusAlgorithm {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.algorithm(),
        }
    }

    fn validators(&self) -> &[Validator] {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.validators(),
        }
    }

    fn finality_threshold(&self) -> usize {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.finality_threshold(),
        }
    }

    fn leader_for_height(&self, height: i64) -> Result<Validator, ConsensusError> {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.leader_for_height(height),
        }
    }

    fn finality_votes_for_block(&self, height: i64) -> Result<Vec<String>, ConsensusError> {
        match self {
            ConfiguredConsensusEngine::Poa(engine) => engine.finality_votes_for_block(height),
        }
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
    fn bft_engine_is_explicitly_deferred() {
        let config = ConsensusEngineConfig {
            engine_id: "sandbox-bft".to_string(),
            algorithm: ConsensusAlgorithm::Bft,
            validators: phase1_default_validators(),
        };

        assert!(matches!(
            config.build_engine(),
            Err(ConsensusError::UnsupportedEngine(_))
        ));
    }
}
