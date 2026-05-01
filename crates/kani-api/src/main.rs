use kani_api::build_router;
use kani_node::KaniNode;
use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "kani_api=info,kani_node=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let addr: SocketAddr = std::env::var("KANI_API_ADDR")
        .unwrap_or_else(|_| "127.0.0.1:8080".to_string())
        .parse()?;

    let ledger_mode = std::env::var("KANI_LEDGER_MODE")
        .unwrap_or_else(|_| "memory".to_string())
        .to_lowercase();
    let node = if ledger_mode == "postgres" {
        let database_url = std::env::var("DATABASE_URL")?;
        tracing::info!("starting node with PostgreSQL persistence");
        KaniNode::postgres(&database_url).await?
    } else {
        tracing::info!("starting node with in-memory sandbox ledger");
        KaniNode::sandbox_default()
    };

    let app = build_router(node);
    let listener = tokio::net::TcpListener::bind(addr).await?;

    tracing::info!(%addr, "starting kani-api in SANDBOX mode");
    axum::serve(listener, app).await?;

    Ok(())
}
