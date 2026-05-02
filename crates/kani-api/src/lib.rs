use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use kani_node::{KaniNode, NodeError};
use kani_types::{
    Account, AccountType, AuditEvent, Block, PaymentRecord, Transaction, TransactionStatus,
};
use serde::{Deserialize, Serialize};
use std::env;

pub const INSTITUTION_ID_HEADER: &str = "x-kani-institution-id";
pub const API_KEY_HEADER: &str = "x-kani-api-key";

const SANDBOX_TREASURY_INSTITUTION_ID: &str = "KANI_TREASURY";
const SANDBOX_CORP_A_INSTITUTION_ID: &str = "CORP_A";
const SANDBOX_CORP_B_INSTITUTION_ID: &str = "CORP_B";
const DEFAULT_TREASURY_API_KEY: &str = "sandbox-treasury-token";
const DEFAULT_CORP_A_API_KEY: &str = "sandbox-corp-a-token";
const DEFAULT_CORP_B_API_KEY: &str = "sandbox-corp-b-token";
const TREASURY_API_KEY_ENV: &str = "KANI_SANDBOX_TREASURY_API_KEY";
const CORP_A_API_KEY_ENV: &str = "KANI_SANDBOX_CORP_A_API_KEY";
const CORP_B_API_KEY_ENV: &str = "KANI_SANDBOX_CORP_B_API_KEY";

#[derive(Clone)]
struct AppState {
    node: KaniNode,
    auth: SandboxAuthConfig,
}

#[derive(Clone, Debug)]
pub struct SandboxAuthConfig {
    credentials: Vec<SandboxCredential>,
}

impl SandboxAuthConfig {
    pub fn new(credentials: Vec<(String, String)>) -> Self {
        Self {
            credentials: credentials
                .into_iter()
                .map(|(institution_id, api_key)| SandboxCredential {
                    institution_id,
                    api_key,
                })
                .collect(),
        }
    }

    pub fn sandbox_defaults() -> Self {
        Self::new(vec![
            (
                SANDBOX_TREASURY_INSTITUTION_ID.to_string(),
                env::var(TREASURY_API_KEY_ENV)
                    .unwrap_or_else(|_| DEFAULT_TREASURY_API_KEY.to_string()),
            ),
            (
                SANDBOX_CORP_A_INSTITUTION_ID.to_string(),
                env::var(CORP_A_API_KEY_ENV).unwrap_or_else(|_| DEFAULT_CORP_A_API_KEY.to_string()),
            ),
            (
                SANDBOX_CORP_B_INSTITUTION_ID.to_string(),
                env::var(CORP_B_API_KEY_ENV).unwrap_or_else(|_| DEFAULT_CORP_B_API_KEY.to_string()),
            ),
        ])
    }

    fn authenticate(&self, headers: &HeaderMap) -> Result<AuthenticatedInstitution, ApiError> {
        let institution_id = required_header(headers, INSTITUTION_ID_HEADER)?;
        let api_key = required_header(headers, API_KEY_HEADER)?;

        let authenticated = self.credentials.iter().any(|credential| {
            credential.institution_id == institution_id && credential.api_key == api_key
        });

        if authenticated {
            return Ok(AuthenticatedInstitution { institution_id });
        }

        Err(ApiError::Unauthorized(
            "invalid sandbox credentials".to_string(),
        ))
    }
}

#[derive(Clone, Debug)]
struct SandboxCredential {
    institution_id: String,
    api_key: String,
}

#[derive(Clone, Debug)]
struct AuthenticatedInstitution {
    institution_id: String,
}

#[derive(Clone, Debug, Deserialize)]
pub struct CreatePaymentRequest {
    pub from: String,
    pub to: String,
    pub asset: String,
    pub amount: i128,
    pub client_reference_id: Option<String>,
    pub idempotency_key: Option<String>,
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
    pub client_reference_id: Option<String>,
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
            client_reference_id: record.client_reference_id,
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
    Conflict(String),
    Unauthorized(String),
    Forbidden(String),
    NotFound(String),
    Internal(String),
}

impl From<NodeError> for ApiError {
    fn from(error: NodeError) -> Self {
        match error {
            NodeError::Ledger(kani_ledger_error) => {
                ApiError::BadRequest(kani_ledger_error.to_string())
            }
            NodeError::Storage(kani_ledger::LedgerStorageError::IdempotencyConflict {
                client_reference_id,
                ..
            }) => ApiError::Conflict(format!(
                "idempotency key {client_reference_id} was already used for a different payment"
            )),
            NodeError::Storage(storage_error) => ApiError::Internal(storage_error.to_string()),
            NodeError::IdempotencyConflict {
                client_reference_id,
            } => ApiError::Conflict(format!(
                "idempotency key {client_reference_id} was already used for a different payment"
            )),
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
            ApiError::Conflict(error) => (StatusCode::CONFLICT, error),
            ApiError::Unauthorized(error) => (StatusCode::UNAUTHORIZED, error),
            ApiError::Forbidden(error) => (StatusCode::FORBIDDEN, error),
            ApiError::NotFound(error) => (StatusCode::NOT_FOUND, error),
            ApiError::Internal(error) => (StatusCode::INTERNAL_SERVER_ERROR, error),
        };

        (status, Json(ErrorResponse { error })).into_response()
    }
}

pub fn build_router(node: KaniNode) -> Router {
    build_router_with_auth(node, SandboxAuthConfig::sandbox_defaults())
}

pub fn build_router_with_auth(node: KaniNode, auth: SandboxAuthConfig) -> Router {
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
        .with_state(AppState { node, auth })
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
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<CreatePaymentRequest>,
) -> Result<(StatusCode, Json<PaymentResponse>), ApiError> {
    let auth = state.auth.authenticate(&headers)?;
    authorize_account_control(&state.node, &auth, &request.from).await?;

    let client_reference_id =
        normalized_client_reference_id(request.client_reference_id, request.idempotency_key)?;
    let response = state
        .node
        .submit_payment(
            request.from,
            request.to,
            request.asset,
            request.amount,
            client_reference_id,
        )
        .await
        .map(PaymentResponse::from)?;

    Ok((StatusCode::CREATED, Json(response)))
}

fn normalized_client_reference_id(
    client_reference_id: Option<String>,
    idempotency_key: Option<String>,
) -> Result<Option<String>, ApiError> {
    let client_reference_id = normalize_optional_id(client_reference_id);
    let idempotency_key = normalize_optional_id(idempotency_key);

    match (client_reference_id, idempotency_key) {
        (Some(client_reference_id), Some(idempotency_key))
            if client_reference_id != idempotency_key =>
        {
            Err(ApiError::BadRequest(
                "client_reference_id and idempotency_key must match when both are provided"
                    .to_string(),
            ))
        }
        (Some(client_reference_id), _) => Ok(Some(client_reference_id)),
        (_, Some(idempotency_key)) => Ok(Some(idempotency_key)),
        (None, None) => Ok(None),
    }
}

fn normalize_optional_id(value: Option<String>) -> Option<String> {
    value
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

async fn authorize_account_control(
    node: &KaniNode,
    auth: &AuthenticatedInstitution,
    account_id: &str,
) -> Result<Account, ApiError> {
    let account = node
        .accounts()
        .await?
        .into_iter()
        .find(|account| account.id == account_id)
        .ok_or_else(|| ApiError::BadRequest(format!("account {account_id} does not exist")))?;

    if account.institution_id.as_deref() == Some(auth.institution_id.as_str()) {
        return Ok(account);
    }

    Err(ApiError::Forbidden(format!(
        "institution is not authorized to debit account {account_id}"
    )))
}

fn required_header(headers: &HeaderMap, name: &'static str) -> Result<String, ApiError> {
    let value = headers
        .get(name)
        .ok_or_else(|| ApiError::Unauthorized(format!("missing {name} header")))?;
    let value = value
        .to_str()
        .map_err(|_| ApiError::Unauthorized("invalid sandbox credentials".to_string()))?
        .trim();

    if value.is_empty() {
        return Err(ApiError::Unauthorized(format!("missing {name} header")));
    }

    Ok(value.to_string())
}

async fn get_payment(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<PaymentResponse>, ApiError> {
    let record = state
        .node
        .get_payment(&id)
        .await
        .map_err(|error| match error {
            NodeError::Ledger(kani_ledger::LedgerError::UnknownPayment(_)) => {
                ApiError::NotFound(format!("payment {id} not found"))
            }
            other => ApiError::from(other),
        })?;

    Ok(Json(record.into()))
}

async fn get_balance(
    State(state): State<AppState>,
    Path((account_id, asset)): Path<(String, String)>,
) -> Result<Json<BalanceResponse>, ApiError> {
    let amount = state.node.balance(&account_id, &asset).await?;
    Ok(Json(BalanceResponse {
        account_id,
        asset,
        amount,
    }))
}

async fn get_pending_transactions(
    State(state): State<AppState>,
) -> Result<Json<Vec<Transaction>>, ApiError> {
    Ok(Json(state.node.pending_transactions().await?))
}

async fn get_latest_block(State(state): State<AppState>) -> Result<Json<Block>, ApiError> {
    state
        .node
        .latest_block()
        .await?
        .map(Json)
        .ok_or_else(|| ApiError::NotFound("no finalized blocks yet".to_string()))
}

async fn get_blocks(State(state): State<AppState>) -> Result<Json<Vec<Block>>, ApiError> {
    Ok(Json(state.node.blocks().await?))
}

async fn get_audit_events(
    State(state): State<AppState>,
) -> Result<Json<Vec<AuditEvent>>, ApiError> {
    Ok(Json(state.node.audit_events().await?))
}

async fn get_validators(
    State(state): State<AppState>,
) -> Result<Json<Vec<ValidatorResponse>>, ApiError> {
    let validators = state
        .node
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
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<SandboxMintRequest>,
) -> Result<(StatusCode, Json<PaymentResponse>), ApiError> {
    let auth = state.auth.authenticate(&headers)?;
    let treasury_account = authorize_account_control(&state.node, &auth, &request.treasury).await?;
    if treasury_account.account_type != AccountType::Treasury {
        return Err(ApiError::BadRequest(format!(
            "account {} is not a treasury account",
            request.treasury
        )));
    }

    let response = state
        .node
        .mint_sandbox(request.treasury, request.to, request.asset, request.amount)
        .await
        .map(PaymentResponse::from)?;

    Ok((StatusCode::CREATED, Json(response)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use kani_types::{SANDBOX_CORP_A_ACCOUNT, SANDBOX_TREASURY_ACCOUNT};

    #[test]
    fn sandbox_auth_accepts_matching_credentials() {
        let config = SandboxAuthConfig::new(vec![("CORP_A".to_string(), "corp-a-key".to_string())]);
        let auth = config
            .authenticate(&headers_for("CORP_A", "corp-a-key"))
            .unwrap();

        assert_eq!(auth.institution_id, "CORP_A");
    }

    #[test]
    fn sandbox_auth_rejects_invalid_credentials() {
        let config = SandboxAuthConfig::new(vec![("CORP_A".to_string(), "corp-a-key".to_string())]);
        let error = config
            .authenticate(&headers_for("CORP_A", "wrong-key"))
            .unwrap_err();

        assert!(matches!(error, ApiError::Unauthorized(_)));
    }

    #[tokio::test]
    async fn institution_can_authorize_own_account() {
        let node = KaniNode::sandbox_default();
        let auth = AuthenticatedInstitution {
            institution_id: "CORP_A".to_string(),
        };

        let account = authorize_account_control(&node, &auth, SANDBOX_CORP_A_ACCOUNT)
            .await
            .unwrap();

        assert_eq!(account.id, SANDBOX_CORP_A_ACCOUNT);
    }

    #[tokio::test]
    async fn institution_cannot_authorize_another_institutions_account() {
        let node = KaniNode::sandbox_default();
        let auth = AuthenticatedInstitution {
            institution_id: "CORP_B".to_string(),
        };

        let error = authorize_account_control(&node, &auth, SANDBOX_CORP_A_ACCOUNT)
            .await
            .unwrap_err();

        assert!(matches!(error, ApiError::Forbidden(_)));
    }

    #[tokio::test]
    async fn treasury_account_is_controlled_by_treasury_institution() {
        let node = KaniNode::sandbox_default();
        let auth = AuthenticatedInstitution {
            institution_id: SANDBOX_TREASURY_INSTITUTION_ID.to_string(),
        };

        let account = authorize_account_control(&node, &auth, SANDBOX_TREASURY_ACCOUNT)
            .await
            .unwrap();

        assert_eq!(account.account_type, AccountType::Treasury);
    }

    fn headers_for(institution_id: &str, api_key: &str) -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert(INSTITUTION_ID_HEADER, institution_id.parse().unwrap());
        headers.insert(API_KEY_HEADER, api_key.parse().unwrap());
        headers
    }
}
