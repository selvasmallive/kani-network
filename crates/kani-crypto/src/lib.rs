use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sha3::Sha3_256;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum CryptoError {
    #[error("failed to serialize signing payload: {0}")]
    Serialization(#[from] serde_json::Error),
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CryptoProfile {
    pub name: String,
    pub transaction_signature: Vec<SignatureAlgorithm>,
    pub validator_signature: Vec<SignatureAlgorithm>,
    pub hash: HashAlgorithm,
}

impl CryptoProfile {
    pub fn hybrid_pqc_v1() -> Self {
        Self {
            name: "hybrid-pqc-v1".to_string(),
            transaction_signature: vec![SignatureAlgorithm::Ed25519, SignatureAlgorithm::MlDsa65],
            validator_signature: vec![SignatureAlgorithm::MlDsa65],
            hash: HashAlgorithm::Sha3_256,
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum SignatureAlgorithm {
    #[serde(rename = "ED25519")]
    Ed25519,
    #[serde(rename = "ML_DSA_65")]
    MlDsa65,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum HashAlgorithm {
    #[serde(rename = "SHA2_256")]
    Sha2_256,
    #[serde(rename = "SHA3_256")]
    Sha3_256,
}

pub fn hash_bytes(algorithm: &HashAlgorithm, bytes: &[u8]) -> String {
    match algorithm {
        HashAlgorithm::Sha2_256 => {
            let mut hasher = Sha256::new();
            hasher.update(bytes);
            hex::encode(hasher.finalize())
        }
        HashAlgorithm::Sha3_256 => {
            let mut hasher = Sha3_256::new();
            hasher.update(bytes);
            hex::encode(hasher.finalize())
        }
    }
}

pub fn hash_json<T: Serialize>(
    algorithm: &HashAlgorithm,
    value: &T,
) -> Result<String, CryptoError> {
    let bytes = serde_json::to_vec(value)?;
    Ok(hash_bytes(algorithm, &bytes))
}

pub fn sandbox_validator_signature(
    profile: &CryptoProfile,
    validator_id: &str,
    block_hash: &str,
) -> Vec<u8> {
    let payload = format!("{}:{}:{}", profile.name, validator_id, block_hash);
    hash_bytes(&profile.hash, payload.as_bytes()).into_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_is_profile_driven() {
        let payload = b"kani";

        assert_ne!(
            hash_bytes(&HashAlgorithm::Sha2_256, payload),
            hash_bytes(&HashAlgorithm::Sha3_256, payload)
        );
    }
}
