use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ConsensusError {
    #[error("phase 1 PoA requires at least 3 active validators")]
    NotEnoughValidators,
    #[error("invalid block height {0}")]
    InvalidHeight(i64),
    #[error("validator {0} is not active")]
    InactiveValidator(String),
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

#[derive(Clone, Debug)]
pub struct PoAConsensus {
    validators: Vec<Validator>,
}

impl PoAConsensus {
    pub fn new_phase1(validators: Vec<Validator>) -> Result<Self, ConsensusError> {
        let consensus = Self { validators };
        if consensus.active_validators().len() < 3 {
            return Err(ConsensusError::NotEnoughValidators);
        }
        Ok(consensus)
    }

    pub fn phase1_default() -> Self {
        Self::new_phase1(vec![
            Validator::active("validator-a", "sandbox-pubkey-a"),
            Validator::active("validator-b", "sandbox-pubkey-b"),
            Validator::active("validator-c", "sandbox-pubkey-c"),
        ])
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
}
