use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ComplianceError {
    #[error("sandbox mode forbids real value movement")]
    RealValueForbidden,
    #[error("sandbox assets are not redeemable")]
    RedemptionForbidden,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct EnvironmentFlags {
    pub env: String,
    pub real_value: bool,
    pub redeemable: bool,
}

impl EnvironmentFlags {
    pub fn sandbox() -> Self {
        Self {
            env: "SANDBOX".to_string(),
            real_value: false,
            redeemable: false,
        }
    }

    pub fn assert_sandbox_boundary(&self) -> Result<(), ComplianceError> {
        if self.real_value {
            return Err(ComplianceError::RealValueForbidden);
        }
        if self.redeemable {
            return Err(ComplianceError::RedemptionForbidden);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ComplianceDecision {
    Allow,
    Review,
    Reject,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ComplianceResult {
    pub decision: ComplianceDecision,
    pub reason: String,
}

pub fn screen_sandbox_payment(from: &str, to: &str, asset: &str, amount: i128) -> ComplianceResult {
    if from.trim().is_empty() || to.trim().is_empty() || asset.trim().is_empty() || amount <= 0 {
        return ComplianceResult {
            decision: ComplianceDecision::Reject,
            reason: "payment shape is invalid".to_string(),
        };
    }

    ComplianceResult {
        decision: ComplianceDecision::Allow,
        reason: "sandbox-only payment allowed".to_string(),
    }
}
