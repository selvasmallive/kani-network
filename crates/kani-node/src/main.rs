use kani_node::ValidatorRuntime;
use std::time::Duration;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "kani_node=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let database_url = std::env::var("DATABASE_URL")?;
    let validator_id =
        std::env::var("KANI_VALIDATOR_ID").unwrap_or_else(|_| "validator-a".to_string());
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

    let validator = ValidatorRuntime::connect(&database_url, validator_id.clone())
        .await?
        .with_max_transactions_per_block(max_transactions_per_block);

    tracing::info!(%validator_id, ?poll_interval, "starting kani validator");
    validator.run_forever(poll_interval).await?;

    Ok(())
}
