use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use kani_node::{KaniNode, NodeError};
use kani_types::{AuditEvent, Block, PaymentRecord, Transaction, TransactionStatus};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize)]
pub struct CreatePaymentRequest {
    pub from: String,
    pub to: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Debug, Deserialize)]
pub struct SandboxMintRequest {
    pub treasury: String,
    pub to: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Debug, Serialize)]
pub struct PaymentResponse {
    pub payment_id: String,
    pub transaction_id: String,
    pub status: TransactionStatus,
    pub block_height: Option<i64>,
    pub block_hash: Option<String>,
    pub failure_reason: Option<String>,
}

impl From<PaymentRecord> for PaymentResponse {
    fn from(record: PaymentRecord) -> Self {
        Self {
            payment_id: record.transaction.id.clone(),
            transaction_id: record.transaction.id,
            status: record.status,
            block_height: record.block_height,
            block_hash: record.block_hash,
            failure_reason: record.failure_reason,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct BalanceResponse {
    pub account_id: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Debug, Serialize)]
pub struct ValidatorResponse {
    pub id: String,
    pub public_key: String,
    pub active: bool,
    pub last_seen_at: Option<String>,
    pub last_finalized_height: Option<i64>,
    pub last_finalized_hash: Option<String>,
    pub last_finalized_at: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
pub struct HealthResponse {
    pub service: &'static str,
    pub status: &'static str,
    pub environment: &'static str,
    pub real_value: bool,
    pub redeemable: bool,
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    error: String,
}

#[derive(Debug)]
pub enum ApiError {
    BadRequest(String),
    NotFound(String),
    Internal(String),
}

impl From<NodeError> for ApiError {
    fn from(error: NodeError) -> Self {
        match error {
            NodeError::Ledger(kani_ledger_error) => {
                ApiError::BadRequest(kani_ledger_error.to_string())
            }
            NodeError::Storage(storage_error) => ApiError::Internal(storage_error.to_string()),
            NodeError::Consensus(consensus_error) => {
                ApiError::BadRequest(consensus_error.to_string())
            }
            NodeError::Crypto(crypto_error) => ApiError::Internal(crypto_error.to_string()),
            NodeError::LockPoisoned => ApiError::Internal("ledger lock poisoned".to_string()),
            NodeError::EmptyBlock => {
                ApiError::BadRequest("block must contain at least one transaction".to_string())
            }
            NodeError::InsufficientFinality { got, required } => ApiError::Internal(format!(
                "block finality threshold not met: got {got}, required {required}"
            )),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, error) = match self {
            ApiError::BadRequest(error) => (StatusCode::BAD_REQUEST, error),
            ApiError::NotFound(error) => (StatusCode::NOT_FOUND, error),
            ApiError::Internal(error) => (StatusCode::INTERNAL_SERVER_ERROR, error),
        };

        (status, Json(ErrorResponse { error })).into_response()
    }
}

pub fn build_router(node: KaniNode) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/v1/payments", post(create_payment))
        .route("/v1/payments/:id", get(get_payment))
        .route("/v1/transactions/pending", get(get_pending_transactions))
        .route("/v1/accounts/:account_id/balances/:asset", get(get_balance))
        .route("/v1/blocks", get(get_blocks))
        .route("/v1/blocks/latest", get(get_latest_block))
        .route("/v1/audit-events", get(get_audit_events))
        .route("/v1/validators", get(get_validators))
        .route("/v1/sandbox/mint", post(sandbox_mint))
        .with_state(node)
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        service: "kani-api",
        status: "ok",
        environment: "SANDBOX",
        real_value: false,
        redeemable: false,
    })
}

async fn create_payment(
    State(node): State<KaniNode>,
    Json(request): Json<CreatePaymentRequest>,
) -> Result<(StatusCode, Json<PaymentResponse>), ApiError> {
    let response = node
        .submit_payment(request.from, request.to, request.asset, request.amount)
        .await
        .map(PaymentResponse::from)?;

    Ok((StatusCode::CREATED, Json(response)))
}

async fn get_payment(
    State(node): State<KaniNode>,
    Path(id): Path<String>,
) -> Result<Json<PaymentResponse>, ApiError> {
    let record = node.get_payment(&id).await.map_err(|error| match error {
        NodeError::Ledger(kani_ledger::LedgerError::UnknownPayment(_)) => {
            ApiError::NotFound(format!("payment {id} not found"))
        }
        other => ApiError::from(other),
    })?;

    Ok(Json(record.into()))
}

async fn get_balance(
    State(node): State<KaniNode>,
    Path((account_id, asset)): Path<(String, String)>,
) -> Result<Json<BalanceResponse>, ApiError> {
    let amount = node.balance(&account_id, &asset).await?;
    Ok(Json(BalanceResponse {
        account_id,
        asset,
        amount,
    }))
}

async fn get_pending_transactions(
    State(node): State<KaniNode>,
) -> Result<Json<Vec<Transaction>>, ApiError> {
    Ok(Json(node.pending_transactions().await?))
}

async fn get_latest_block(State(node): State<KaniNode>) -> Result<Json<Block>, ApiError> {
    node.latest_block()
        .await?
        .map(Json)
        .ok_or_else(|| ApiError::NotFound("no finalized blocks yet".to_string()))
}

async fn get_blocks(State(node): State<KaniNode>) -> Result<Json<Vec<Block>>, ApiError> {
    Ok(Json(node.blocks().await?))
}

async fn get_audit_events(State(node): State<KaniNode>) -> Result<Json<Vec<AuditEvent>>, ApiError> {
    Ok(Json(node.audit_events().await?))
}

async fn get_validators(
    State(node): State<KaniNode>,
) -> Result<Json<Vec<ValidatorResponse>>, ApiError> {
    let validators = node
        .validators()
        .await?
        .into_iter()
        .map(|validator| ValidatorResponse {
            id: validator.id,
            public_key: validator.public_key,
            active: validator.active,
            last_seen_at: validator.last_seen_at.map(|value| value.to_rfc3339()),
            last_finalized_height: validator.last_finalized_height,
            last_finalized_hash: validator.last_finalized_hash,
            last_finalized_at: validator.last_finalized_at.map(|value| value.to_rfc3339()),
        })
        .collect();

    Ok(Json(validators))
}

async fn sandbox_mint(
    State(node): State<KaniNode>,
    Json(request): Json<SandboxMintRequest>,
) -> Result<(StatusCode, Json<PaymentResponse>), ApiError> {
    let response = node
        .mint_sandbox(request.treasury, request.to, request.asset, request.amount)
        .await
        .map(PaymentResponse::from)?;

    Ok((StatusCode::CREATED, Json(response)))
}
