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
    pub rule_id: String,
    pub reason: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CompliancePayment {
    pub from: String,
    pub to: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct SandboxCompliancePolicy {
    pub allowed_accounts: Vec<String>,
    pub allowed_asset_prefixes: Vec<String>,
    pub max_payment_amount: i128,
    pub allow_self_transfers: bool,
}

impl SandboxCompliancePolicy {
    pub fn sandbox_default() -> Self {
        Self {
            allowed_accounts: vec!["CORP_A".to_string(), "CORP_B".to_string()],
            allowed_asset_prefixes: vec!["KCAD_TEST".to_string(), "KUSD_TEST".to_string()],
            max_payment_amount: 500_000,
            allow_self_transfers: false,
        }
    }
}

impl Default for SandboxCompliancePolicy {
    fn default() -> Self {
        Self::sandbox_default()
    }
}

pub fn screen_sandbox_payment(from: &str, to: &str, asset: &str, amount: i128) -> ComplianceResult {
    let payment = CompliancePayment {
        from: from.to_string(),
        to: to.to_string(),
        asset: asset.to_string(),
        amount,
    };
    screen_sandbox_payment_with_policy(&SandboxCompliancePolicy::sandbox_default(), &payment)
}

pub fn screen_sandbox_payment_with_policy(
    policy: &SandboxCompliancePolicy,
    payment: &CompliancePayment,
) -> ComplianceResult {
    let from = payment.from.trim();
    let to = payment.to.trim();
    let asset = payment.asset.trim();

    if from.is_empty() || to.is_empty() || asset.is_empty() || payment.amount <= 0 {
        return reject("PAYMENT_SHAPE", "payment shape is invalid");
    }

    if !policy.allow_self_transfers && from == to {
        return reject("NO_SELF_TRANSFER", "self transfers are disabled in sandbox");
    }

    if !account_allowed(policy, from) || !account_allowed(policy, to) {
        return reject(
            "ACCOUNT_ALLOWLIST",
            "sandbox payments are limited to approved test institution accounts",
        );
    }

    if !asset_allowed(policy, asset) {
        return reject(
            "ASSET_ALLOWLIST",
            "sandbox payment asset is not approved for this compliance profile",
        );
    }

    if payment.amount > policy.max_payment_amount {
        return review(
            "MAX_PAYMENT_AMOUNT",
            "payment amount exceeds the sandbox straight-through-processing limit",
        );
    }

    ComplianceResult {
        decision: ComplianceDecision::Allow,
        rule_id: "SANDBOX_STP".to_string(),
        reason: "sandbox-only payment allowed".to_string(),
    }
}

fn account_allowed(policy: &SandboxCompliancePolicy, account_id: &str) -> bool {
    policy
        .allowed_accounts
        .iter()
        .any(|allowed| allowed == account_id)
}

fn asset_allowed(policy: &SandboxCompliancePolicy, asset: &str) -> bool {
    policy
        .allowed_asset_prefixes
        .iter()
        .any(|prefix| asset == prefix || asset.starts_with(&format!("{prefix}_")))
}

fn reject(rule_id: &str, reason: &str) -> ComplianceResult {
    ComplianceResult {
        decision: ComplianceDecision::Reject,
        rule_id: rule_id.to_string(),
        reason: reason.to_string(),
    }
}

fn review(rule_id: &str, reason: &str) -> ComplianceResult {
    ComplianceResult {
        decision: ComplianceDecision::Review,
        rule_id: rule_id.to_string(),
        reason: reason.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sandbox_payment_policy_allows_approved_test_transfer() {
        let result = screen_sandbox_payment("CORP_A", "CORP_B", "KCAD_TEST_20260508", 100_000);

        assert_eq!(result.decision, ComplianceDecision::Allow);
        assert_eq!(result.rule_id, "SANDBOX_STP");
    }

    #[test]
    fn sandbox_payment_policy_rejects_invalid_shape() {
        let result = screen_sandbox_payment("", "CORP_B", "KCAD_TEST", 100_000);

        assert_eq!(result.decision, ComplianceDecision::Reject);
        assert_eq!(result.rule_id, "PAYMENT_SHAPE");
    }

    #[test]
    fn sandbox_payment_policy_rejects_self_transfer() {
        let result = screen_sandbox_payment("CORP_A", "CORP_A", "KCAD_TEST", 100_000);

        assert_eq!(result.decision, ComplianceDecision::Reject);
        assert_eq!(result.rule_id, "NO_SELF_TRANSFER");
    }

    #[test]
    fn sandbox_payment_policy_rejects_unapproved_assets_and_accounts() {
        let account_result =
            screen_sandbox_payment("TREASURY_SANDBOX", "CORP_A", "KCAD_TEST", 100_000);
        let asset_result = screen_sandbox_payment("CORP_A", "CORP_B", "KEUR_TEST", 100_000);

        assert_eq!(account_result.decision, ComplianceDecision::Reject);
        assert_eq!(account_result.rule_id, "ACCOUNT_ALLOWLIST");
        assert_eq!(asset_result.decision, ComplianceDecision::Reject);
        assert_eq!(asset_result.rule_id, "ASSET_ALLOWLIST");
    }

    #[test]
    fn sandbox_payment_policy_flags_large_amounts_for_review() {
        let result = screen_sandbox_payment("CORP_A", "CORP_B", "KCAD_TEST", 500_001);

        assert_eq!(result.decision, ComplianceDecision::Review);
        assert_eq!(result.rule_id, "MAX_PAYMENT_AMOUNT");
    }
}
