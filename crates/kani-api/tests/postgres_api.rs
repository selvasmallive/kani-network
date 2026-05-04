use anyhow::{bail, ensure, Context, Result};
use axum::{
    body::{to_bytes, Body},
    http::{header, Method, Request, StatusCode},
    Router,
};
use kani_api::{build_router, API_KEY_HEADER, INSTITUTION_ID_HEADER};
use kani_node::{KaniNode, ValidatorRuntime};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::{
    env,
    path::Path,
    time::{SystemTime, UNIX_EPOCH},
};
use tower::ServiceExt;

const TEST_DATABASE_URL_ENV: &str = "KANI_TEST_DATABASE_URL";
const TREASURY_ACCOUNT: &str = "TREASURY_SANDBOX";
const CORP_A_ACCOUNT: &str = "CORP_A";
const CORP_B_ACCOUNT: &str = "CORP_B";

#[tokio::test]
async fn postgres_api_persists_finalized_payments_and_admin_reads() -> Result<()> {
    set_workspace_root_as_current_dir()?;
    let Some(database) = TestDatabase::create().await? else {
        return Ok(());
    };

    let result = run_postgres_api_flow(&database.database_url, &database.database_name).await;
    let cleanup = database.cleanup().await;
    result?;
    cleanup?;

    Ok(())
}

async fn run_postgres_api_flow(database_url: &str, test_id: &str) -> Result<()> {
    let app = build_router(KaniNode::postgres(database_url).await?);
    let asset_suffix: String = test_id
        .chars()
        .rev()
        .take(20)
        .collect::<String>()
        .chars()
        .rev()
        .collect();
    let asset = format!("KCAD_{}", asset_suffix.to_ascii_uppercase());

    let (status, mint) = post_json(
        &app,
        "/v1/sandbox/mint",
        Headers::treasury(),
        json!({
            "treasury": TREASURY_ACCOUNT,
            "to": CORP_A_ACCOUNT,
            "asset": asset,
            "amount": 1_000_000
        }),
    )
    .await?;
    ensure!(
        status == StatusCode::CREATED,
        "mint returned {status}: {mint}"
    );
    ensure!(mint["status"] == "PENDING", "mint was not queued: {mint}");
    let mint_id = required_string(&mint, "payment_id")?;

    let mint_block_height = finalize_next_block(database_url).await?;
    ensure!(mint_block_height == 1, "expected mint block height 1");

    let (status, finalized_mint) = get_json(
        &app,
        &format!("/v1/payments/{mint_id}"),
        Headers::treasury(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "mint lookup returned {status}: {finalized_mint}"
    );
    ensure!(
        finalized_mint["status"] == "FINALIZED",
        "mint was not finalized: {finalized_mint}"
    );
    ensure!(
        finalized_mint["block_height"] == 1,
        "mint block height was not persisted: {finalized_mint}"
    );

    let client_reference_id = format!("{test_id}-transfer");
    let transfer_body = json!({
        "from": CORP_A_ACCOUNT,
        "to": CORP_B_ACCOUNT,
        "asset": asset,
        "amount": 100_000,
        "client_reference_id": client_reference_id
    });
    let (status, transfer) = post_json(
        &app,
        "/v1/payments",
        Headers::corp_a(),
        transfer_body.clone(),
    )
    .await?;
    ensure!(
        status == StatusCode::CREATED,
        "transfer returned {status}: {transfer}"
    );
    ensure!(
        transfer["status"] == "PENDING",
        "transfer was not queued: {transfer}"
    );
    let transfer_id = required_string(&transfer, "payment_id")?;

    let (status, retry) = post_json(&app, "/v1/payments", Headers::corp_a(), transfer_body).await?;
    ensure!(
        status == StatusCode::CREATED,
        "idempotent retry returned {status}: {retry}"
    );
    ensure!(
        retry["payment_id"] == transfer["payment_id"],
        "idempotent retry returned a different payment: {retry}"
    );

    let transfer_block_height = finalize_next_block(database_url).await?;
    ensure!(
        transfer_block_height == 2,
        "expected transfer block height 2"
    );

    let reloaded_app = build_router(KaniNode::postgres(database_url).await?);
    let (status, finalized_transfer) = get_json(
        &reloaded_app,
        &format!("/v1/payments/{transfer_id}"),
        Headers::corp_b(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "transfer lookup returned {status}: {finalized_transfer}"
    );
    ensure!(
        finalized_transfer["status"] == "FINALIZED",
        "transfer was not finalized: {finalized_transfer}"
    );
    ensure!(
        finalized_transfer["block_height"] == 2,
        "transfer block height was not persisted: {finalized_transfer}"
    );

    let (status, balance_a) = get_json(
        &reloaded_app,
        &format!("/v1/accounts/{CORP_A_ACCOUNT}/balances/{asset}"),
        Headers::corp_a(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "CORP_A balance returned {status}: {balance_a}"
    );
    ensure!(balance_a["amount"] == 900_000, "unexpected CORP_A balance");

    let (status, balance_b) = get_json(
        &reloaded_app,
        &format!("/v1/accounts/{CORP_B_ACCOUNT}/balances/{asset}"),
        Headers::corp_b(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "CORP_B balance returned {status}: {balance_b}"
    );
    ensure!(balance_b["amount"] == 100_000, "unexpected CORP_B balance");

    let overdraw_body = json!({
        "from": CORP_A_ACCOUNT,
        "to": CORP_B_ACCOUNT,
        "asset": asset,
        "amount": 2_000_000,
        "client_reference_id": format!("{test_id}-overdraw")
    });
    let (status, overdraw) = post_json(
        &reloaded_app,
        "/v1/payments",
        Headers::corp_a(),
        overdraw_body,
    )
    .await?;
    ensure!(
        status == StatusCode::CREATED,
        "overdraw transfer returned {status}: {overdraw}"
    );
    ensure!(
        overdraw["status"] == "PENDING",
        "overdraw transfer was not queued: {overdraw}"
    );
    let overdraw_id = required_string(&overdraw, "payment_id")?;

    run_validator_passes(database_url).await?;
    let reloaded_app = build_router(KaniNode::postgres(database_url).await?);
    let (status, rejected_overdraw) = get_json(
        &reloaded_app,
        &format!("/v1/payments/{overdraw_id}"),
        Headers::corp_a(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "overdraw lookup returned {status}: {rejected_overdraw}"
    );
    ensure!(
        rejected_overdraw["status"] == "REJECTED",
        "overdraw transfer was not rejected: {rejected_overdraw}"
    );
    ensure!(
        rejected_overdraw["failure_reason"]
            .as_str()
            .unwrap_or_default()
            .contains("insufficient"),
        "overdraw rejection reason was not persisted: {rejected_overdraw}"
    );

    let (status, pending_page) = get_json(
        &reloaded_app,
        "/v1/transactions/pending?limit=10&offset=0",
        Headers::admin(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "pending transaction page returned {status}: {pending_page}"
    );
    ensure!(
        pending_page["count"] == 0,
        "expected rejected overdraw to leave no pending transactions: {pending_page}"
    );

    let (status, rejection_audit_page) = get_json(
        &reloaded_app,
        "/v1/audit-events?event_type=TRANSACTION_REJECTED&limit=10&offset=0",
        Headers::admin(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "rejection audit page returned {status}: {rejection_audit_page}"
    );
    let rejection_audit_items = rejection_audit_page["items"]
        .as_array()
        .context("rejection audit page items must be an array")?;
    ensure!(
        rejection_audit_items
            .iter()
            .any(|event| event["transaction_id"].as_str() == Some(overdraw_id.as_str())),
        "expected TRANSACTION_REJECTED audit event for {overdraw_id}: {rejection_audit_page}"
    );

    let (status, block_page) = get_json(
        &reloaded_app,
        "/v1/blocks?limit=1&offset=1",
        Headers::admin(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "block page returned {status}: {block_page}"
    );
    ensure!(block_page["count"] == 1, "expected one paged block");
    ensure!(
        block_page["items"][0]["height"] == 2,
        "expected second block on offset 1 page: {block_page}"
    );

    let (status, audit_page) = get_json(
        &reloaded_app,
        "/v1/audit-events?event_type=API_AUTHORIZATION_DECISION&decision=ALLOWED&institution_id=KANI_ADMIN&limit=10&offset=0",
        Headers::admin(),
    )
    .await?;
    ensure!(
        status == StatusCode::OK,
        "audit page returned {status}: {audit_page}"
    );
    ensure!(
        audit_page["count"].as_u64().unwrap_or_default() >= 1,
        "expected allowed admin authorization audit event: {audit_page}"
    );

    Ok(())
}

async fn finalize_next_block(database_url: &str) -> Result<i64> {
    for validator_id in ["validator-a", "validator-b", "validator-c"] {
        let validator = ValidatorRuntime::connect(database_url, validator_id).await?;
        if let Some(block) = validator.run_once().await? {
            return Ok(block.height);
        }
    }

    bail!("no validator finalized a pending block")
}

async fn run_validator_passes(database_url: &str) -> Result<()> {
    for validator_id in ["validator-a", "validator-b", "validator-c"] {
        let validator = ValidatorRuntime::connect(database_url, validator_id).await?;
        validator.run_once().await?;
    }

    Ok(())
}

async fn post_json(
    app: &Router,
    uri: &str,
    headers: Headers,
    body: Value,
) -> Result<(StatusCode, Value)> {
    json_request(app, Method::POST, uri, headers, Some(body)).await
}

async fn get_json(app: &Router, uri: &str, headers: Headers) -> Result<(StatusCode, Value)> {
    json_request(app, Method::GET, uri, headers, None).await
}

async fn json_request(
    app: &Router,
    method: Method,
    uri: &str,
    headers: Headers,
    body: Option<Value>,
) -> Result<(StatusCode, Value)> {
    let request_body = body
        .map(|body| Body::from(body.to_string()))
        .unwrap_or_else(Body::empty);
    let request = Request::builder()
        .method(method)
        .uri(uri)
        .header(header::CONTENT_TYPE, "application/json")
        .header(INSTITUTION_ID_HEADER, headers.institution_id)
        .header(API_KEY_HEADER, headers.api_key)
        .body(request_body)?;

    let response = app.clone().oneshot(request).await?;
    let status = response.status();
    let bytes = to_bytes(response.into_body(), usize::MAX).await?;
    let body = if bytes.is_empty() {
        Value::Null
    } else {
        serde_json::from_slice(&bytes)?
    };

    Ok((status, body))
}

fn required_string(value: &Value, field: &'static str) -> Result<String> {
    value[field]
        .as_str()
        .map(ToString::to_string)
        .with_context(|| format!("missing string field {field}: {value}"))
}

fn set_workspace_root_as_current_dir() -> Result<()> {
    let crate_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let workspace_root = crate_dir
        .parent()
        .and_then(Path::parent)
        .context("kani-api crate must live under crates/kani-api")?;
    env::set_current_dir(workspace_root)?;
    Ok(())
}

#[derive(Clone, Copy)]
struct Headers {
    institution_id: &'static str,
    api_key: &'static str,
}

impl Headers {
    fn treasury() -> Self {
        Self {
            institution_id: "KANI_TREASURY",
            api_key: "sandbox-treasury-token",
        }
    }

    fn corp_a() -> Self {
        Self {
            institution_id: "CORP_A",
            api_key: "sandbox-corp-a-token",
        }
    }

    fn corp_b() -> Self {
        Self {
            institution_id: "CORP_B",
            api_key: "sandbox-corp-b-token",
        }
    }

    fn admin() -> Self {
        Self {
            institution_id: "KANI_ADMIN",
            api_key: "sandbox-admin-token",
        }
    }
}

struct TestDatabase {
    pool: PgPool,
    database_name: String,
    database_url: String,
}

impl TestDatabase {
    async fn create() -> Result<Option<Self>> {
        let Some(base_url) = env::var(TEST_DATABASE_URL_ENV).ok() else {
            eprintln!("skipping Postgres API integration test; set {TEST_DATABASE_URL_ENV}");
            return Ok(None);
        };

        let pool = PgPoolOptions::new()
            .max_connections(1)
            .connect(&base_url)
            .await
            .with_context(|| format!("failed to connect to {TEST_DATABASE_URL_ENV}"))?;
        let database_name = unique_database_name()?;
        sqlx::query(&format!("CREATE DATABASE {database_name}"))
            .execute(&pool)
            .await?;
        let database_url = database_url_with_database_name(&base_url, &database_name)?;

        Ok(Some(Self {
            pool,
            database_name,
            database_url,
        }))
    }

    async fn cleanup(self) -> Result<()> {
        sqlx::query(&format!(
            "DROP DATABASE IF EXISTS {} WITH (FORCE)",
            self.database_name
        ))
        .execute(&self.pool)
        .await?;
        Ok(())
    }
}

fn unique_database_name() -> Result<String> {
    let nanos = SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos();
    Ok(format!("kani_it_{}_{}", std::process::id(), nanos))
}

fn database_url_with_database_name(base_url: &str, database_name: &str) -> Result<String> {
    let (without_query, query) = base_url
        .split_once('?')
        .map_or((base_url, ""), |(url, query)| (url, query));
    let database_start = without_query
        .rfind('/')
        .context("database URL must include a database name")?;
    let query = if query.is_empty() {
        String::new()
    } else {
        format!("?{query}")
    };

    Ok(format!(
        "{}{}{}",
        &without_query[..database_start + 1],
        database_name,
        query
    ))
}
