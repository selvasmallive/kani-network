use kani_node::{SandboxRuntimeConfig, ValidatorRuntime};
use std::time::Duration;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ValidatorRunMode {
    Forever,
    Once,
    Sweep,
}

impl ValidatorRunMode {
    fn from_env_value(value: Option<String>) -> anyhow::Result<Self> {
        match value
            .unwrap_or_else(|| "forever".to_string())
            .to_ascii_lowercase()
            .as_str()
        {
            "forever" => Ok(Self::Forever),
            "once" => Ok(Self::Once),
            "sweep" => Ok(Self::Sweep),
            other => anyhow::bail!(
                "KANI_VALIDATOR_RUN_MODE must be forever, once, or sweep; got {other}"
            ),
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "kani_node=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let sandbox_runtime = SandboxRuntimeConfig::from_env()?;
    tracing::info!(
        environment = %sandbox_runtime.environment(),
        real_value = sandbox_runtime.real_value(),
        redeemable = sandbox_runtime.redeemable(),
        "validated Phase 1 sandbox runtime flags"
    );

    let database_url = std::env::var("DATABASE_URL")?;
    let validator_id =
        std::env::var("KANI_VALIDATOR_ID").unwrap_or_else(|_| "validator-a".to_string());
    let run_mode = ValidatorRunMode::from_env_value(std::env::var("KANI_VALIDATOR_RUN_MODE").ok())?;
    let poll_interval = Duration::from_millis(
        std::env::var("KANI_VALIDATOR_POLL_MS")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(750),
    );
    let max_transactions_per_block = std::env::var("KANI_MAX_TXS_PER_BLOCK")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(25);

    match run_mode {
        ValidatorRunMode::Forever => {
            let validator = ValidatorRuntime::connect(&database_url, validator_id.clone())
                .await?
                .with_max_transactions_per_block(max_transactions_per_block);

            tracing::info!(%validator_id, ?poll_interval, "starting kani validator");
            validator.run_forever(poll_interval).await?;
        }
        ValidatorRunMode::Once => {
            let validator = ValidatorRuntime::connect(&database_url, validator_id.clone())
                .await?
                .with_max_transactions_per_block(max_transactions_per_block);

            run_validator_once(&validator, &validator_id).await?;
        }
        ValidatorRunMode::Sweep => {
            let validator_ids =
                parse_validator_ids(std::env::var("KANI_VALIDATOR_IDS").ok(), &validator_id);
            let mut finalized_blocks = 0usize;

            for validator_id in validator_ids {
                let validator = ValidatorRuntime::connect(&database_url, validator_id.clone())
                    .await?
                    .with_max_transactions_per_block(max_transactions_per_block);

                if run_validator_once(&validator, &validator_id).await? {
                    finalized_blocks += 1;
                }
            }

            tracing::info!(finalized_blocks, "completed validator sweep");
        }
    }

    Ok(())
}

async fn run_validator_once(
    validator: &ValidatorRuntime,
    validator_id: &str,
) -> anyhow::Result<bool> {
    match validator.run_once().await? {
        Some(block) => {
            tracing::info!(
                validator = %validator_id,
                height = block.height,
                tx_count = block.txs.len(),
                "finalized block"
            );
            Ok(true)
        }
        None => {
            tracing::info!(validator = %validator_id, "no block finalized");
            Ok(false)
        }
    }
}

fn parse_validator_ids(value: Option<String>, fallback_validator_id: &str) -> Vec<String> {
    let ids: Vec<String> = value
        .unwrap_or_else(|| fallback_validator_id.to_string())
        .split(',')
        .map(str::trim)
        .filter(|id| !id.is_empty())
        .map(str::to_string)
        .collect();

    if ids.is_empty() {
        vec![fallback_validator_id.to_string()]
    } else {
        ids
    }
}

#[cfg(test)]
mod tests {
    use super::{parse_validator_ids, ValidatorRunMode};

    #[test]
    fn validator_run_mode_defaults_to_forever() {
        assert_eq!(
            ValidatorRunMode::from_env_value(None).unwrap(),
            ValidatorRunMode::Forever
        );
    }

    #[test]
    fn validator_run_mode_accepts_job_modes() {
        assert_eq!(
            ValidatorRunMode::from_env_value(Some("once".to_string())).unwrap(),
            ValidatorRunMode::Once
        );
        assert_eq!(
            ValidatorRunMode::from_env_value(Some("SWEEP".to_string())).unwrap(),
            ValidatorRunMode::Sweep
        );
    }

    #[test]
    fn parse_validator_ids_ignores_empty_items() {
        assert_eq!(
            parse_validator_ids(
                Some("validator-a, validator-b,, validator-c".to_string()),
                "x"
            ),
            vec!["validator-a", "validator-b", "validator-c"]
        );
        assert_eq!(
            parse_validator_ids(Some(" , ".to_string()), "fallback"),
            vec!["fallback"]
        );
    }
}
