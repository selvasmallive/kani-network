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

    let app = build_router(KaniNode::sandbox_default());
    let listener = tokio::net::TcpListener::bind(addr).await?;

    tracing::info!(%addr, "starting kani-api in SANDBOX mode");
    axum::serve(listener, app).await?;

    Ok(())
}
