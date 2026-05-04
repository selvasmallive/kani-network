use axum::{
    extract::{Path, Query, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use kani_ledger::{AuditEventSearch, BlockSearch};
use kani_node::{KaniNode, NodeError};
use kani_types::{
    Account, AccountType, AuditEvent, Block, PaymentRecord, Transaction, TransactionStatus,
};
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, env};

pub const INSTITUTION_ID_HEADER: &str = "x-kani-institution-id";
pub const API_KEY_HEADER: &str = "x-kani-api-key";

const SANDBOX_TREASURY_INSTITUTION_ID: &str = "KANI_TREASURY";
const SANDBOX_CORP_A_INSTITUTION_ID: &str = "CORP_A";
const SANDBOX_CORP_B_INSTITUTION_ID: &str = "CORP_B";
const SANDBOX_ADMIN_ID: &str = "KANI_ADMIN";
const DEFAULT_TREASURY_API_KEY: &str = "sandbox-treasury-token";
const DEFAULT_CORP_A_API_KEY: &str = "sandbox-corp-a-token";
const DEFAULT_CORP_B_API_KEY: &str = "sandbox-corp-b-token";
const DEFAULT_ADMIN_API_KEY: &str = "sandbox-admin-token";
const TREASURY_API_KEY_ENV: &str = "KANI_SANDBOX_TREASURY_API_KEY";
const CORP_A_API_KEY_ENV: &str = "KANI_SANDBOX_CORP_A_API_KEY";
const CORP_B_API_KEY_ENV: &str = "KANI_SANDBOX_CORP_B_API_KEY";
const ADMIN_API_KEY_ENV: &str = "KANI_SANDBOX_ADMIN_API_KEY";
const DEFAULT_BLOCK_LIMIT: i64 = 100;
const MAX_BLOCK_LIMIT: i64 = 500;
const DEFAULT_AUDIT_EVENT_LIMIT: i64 = 100;
const MAX_AUDIT_EVENT_LIMIT: i64 = 500;
const OPENAPI_JSON: &str = include_str!("../../../openapi/kani-api.v1.json");

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
                    role: SandboxCredentialRole::Institution,
                })
                .collect(),
        }
    }

    pub fn new_with_admins(
        institution_credentials: Vec<(String, String)>,
        admin_credentials: Vec<(String, String)>,
    ) -> Self {
        let mut credentials: Vec<SandboxCredential> = institution_credentials
            .into_iter()
            .map(|(institution_id, api_key)| SandboxCredential {
                institution_id,
                api_key,
                role: SandboxCredentialRole::Institution,
            })
            .collect();
        credentials.extend(
            admin_credentials
                .into_iter()
                .map(|(institution_id, api_key)| SandboxCredential {
                    institution_id,
                    api_key,
                    role: SandboxCredentialRole::Admin,
                }),
        );

        Self { credentials }
    }

    pub fn sandbox_defaults() -> Self {
        Self::new_with_admins(
            vec![
                (
                    SANDBOX_TREASURY_INSTITUTION_ID.to_string(),
                    env::var(TREASURY_API_KEY_ENV)
                        .unwrap_or_else(|_| DEFAULT_TREASURY_API_KEY.to_string()),
                ),
                (
                    SANDBOX_CORP_A_INSTITUTION_ID.to_string(),
                    env::var(CORP_A_API_KEY_ENV)
                        .unwrap_or_else(|_| DEFAULT_CORP_A_API_KEY.to_string()),
                ),
                (
                    SANDBOX_CORP_B_INSTITUTION_ID.to_string(),
                    env::var(CORP_B_API_KEY_ENV)
                        .unwrap_or_else(|_| DEFAULT_CORP_B_API_KEY.to_string()),
                ),
            ],
            vec![(
                SANDBOX_ADMIN_ID.to_string(),
                env::var(ADMIN_API_KEY_ENV).unwrap_or_else(|_| DEFAULT_ADMIN_API_KEY.to_string()),
            )],
        )
    }

    fn authenticate(&self, headers: &HeaderMap) -> Result<AuthenticatedInstitution, ApiError> {
        let institution_id = required_header(headers, INSTITUTION_ID_HEADER)?;
        let api_key = required_header(headers, API_KEY_HEADER)?;

        let credential = self.credentials.iter().find(|credential| {
            credential.institution_id == institution_id && credential.api_key == api_key
        });

        if let Some(credential) = credential {
            return Ok(AuthenticatedInstitution {
                institution_id,
                is_admin: credential.role == SandboxCredentialRole::Admin,
            });
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
    role: SandboxCredentialRole,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum SandboxCredentialRole {
    Institution,
    Admin,
}

#[derive(Clone, Debug)]
struct AuthenticatedInstitution {
    institution_id: String,
    is_admin: bool,
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

#[derive(Clone, Debug)]
struct ValidatedPaymentRequest {
    from: String,
    to: String,
    asset: String,
    amount: i128,
    client_reference_id: Option<String>,
    idempotency_key: Option<String>,
}

impl CreatePaymentRequest {
    fn validate(self) -> Result<ValidatedPaymentRequest, ApiError> {
        Ok(ValidatedPaymentRequest {
            from: normalize_required_field("from", self.from)?,
            to: normalize_required_field("to", self.to)?,
            asset: normalize_asset_code(self.asset)?,
            amount: validate_positive_amount(self.amount)?,
            client_reference_id: self.client_reference_id,
            idempotency_key: self.idempotency_key,
        })
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct SandboxMintRequest {
    pub treasury: String,
    pub to: String,
    pub asset: String,
    pub amount: i128,
}

#[derive(Clone, Debug)]
struct ValidatedSandboxMintRequest {
    treasury: String,
    to: String,
    asset: String,
    amount: i128,
}

impl SandboxMintRequest {
    fn validate(self) -> Result<ValidatedSandboxMintRequest, ApiError> {
        Ok(ValidatedSandboxMintRequest {
            treasury: normalize_required_field("treasury", self.treasury)?,
            to: normalize_required_field("to", self.to)?,
            asset: normalize_asset_code(self.asset)?,
            amount: validate_positive_amount(self.amount)?,
        })
    }
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
pub struct IssuedResponse {
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

#[derive(Clone, Debug, Serialize)]
pub struct PaginatedResponse<T> {
    pub items: Vec<T>,
    pub limit: i64,
    pub offset: i64,
    pub count: usize,
    pub next_offset: Option<i64>,
}

impl<T> PaginatedResponse<T> {
    fn from_limit_plus_one(mut items: Vec<T>, limit: i64, offset: i64) -> Self {
        let requested = limit as usize;
        let has_more = items.len() > requested;
        if has_more {
            items.truncate(requested);
        }

        Self {
            count: items.len(),
            items,
            limit,
            offset,
            next_offset: has_more.then_some(offset + limit),
        }
    }
}

#[derive(Clone, Debug, Default, Deserialize)]
pub struct AuditEventQuery {
    pub event_type: Option<String>,
    pub decision: Option<String>,
    pub institution_id: Option<String>,
    pub created_from: Option<String>,
    pub created_to: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Clone, Debug, Default, Deserialize)]
pub struct BlockQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
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

impl ApiError {
    fn status_code(&self) -> StatusCode {
        match self {
            ApiError::BadRequest(_) => StatusCode::BAD_REQUEST,
            ApiError::Conflict(_) => StatusCode::CONFLICT,
            ApiError::Unauthorized(_) => StatusCode::UNAUTHORIZED,
            ApiError::Forbidden(_) => StatusCode::FORBIDDEN,
            ApiError::NotFound(_) => StatusCode::NOT_FOUND,
            ApiError::Internal(_) => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    fn message(&self) -> &str {
        match self {
            ApiError::BadRequest(error)
            | ApiError::Conflict(error)
            | ApiError::Unauthorized(error)
            | ApiError::Forbidden(error)
            | ApiError::NotFound(error)
            | ApiError::Internal(error) => error,
        }
    }
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
            NodeError::InvalidBlockValidator { expected, actual } => ApiError::Internal(format!(
                "block validator mismatch: expected {expected}, got {actual}"
            )),
            NodeError::UnknownFinalityValidator(validator) => ApiError::Internal(format!(
                "block finality vote from inactive or unknown validator {validator}"
            )),
            NodeError::DuplicateFinalityVote(validator) => ApiError::Internal(format!(
                "duplicate block finality vote from validator {validator}"
            )),
            NodeError::MissingProducerFinalityVote(validator) => ApiError::Internal(format!(
                "block finality votes must include the block producer {validator}"
            )),
            NodeError::InvalidBlockHash { expected, actual } => ApiError::Internal(format!(
                "block hash mismatch: expected {expected}, got {actual}"
            )),
            NodeError::InvalidBlockSignature { validator, hash } => ApiError::Internal(format!(
                "block signature mismatch for validator {validator} and hash {hash}"
            )),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status = self.status_code();
        let error = self.message().to_string();

        (status, Json(ErrorResponse { error })).into_response()
    }
}

pub fn build_router(node: KaniNode) -> Router {
    build_router_with_auth(node, SandboxAuthConfig::sandbox_defaults())
}

pub fn build_router_with_auth(node: KaniNode, auth: SandboxAuthConfig) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/openapi.json", get(openapi_json))
        .route("/v1/payments", post(create_payment))
        .route("/v1/payments/:id", get(get_payment))
        .route("/v1/accounts", get(get_accounts))
        .route("/v1/transactions/pending", get(get_pending_transactions))
        .route("/v1/accounts/:account_id/balances/:asset", get(get_balance))
        .route("/v1/assets/:asset/issued", get(get_issued))
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

async fn openapi_json() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "application/json")], OPENAPI_JSON)
}

async fn create_payment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<CreatePaymentRequest>,
) -> Result<(StatusCode, Json<PaymentResponse>), ApiError> {
    let request = request.validate()?;
    let resource = format!("account:{}", request.from);
    let auth = authenticate_request(&state, &headers, "create_payment", &resource).await?;
    if let Err(error) = authorize_account_control(&state.node, &auth, &request.from).await {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "create_payment",
            &resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "create_payment", &resource).await?;
    ensure_account_exists(&state.node, &request.to).await?;

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

fn normalize_required_field(name: &str, value: String) -> Result<String, ApiError> {
    let value = value.trim().to_string();
    if value.is_empty() {
        return Err(ApiError::BadRequest(format!("{name} is required")));
    }

    Ok(value)
}

fn normalize_asset_code(value: String) -> Result<String, ApiError> {
    let asset = normalize_required_field("asset", value)?;
    if asset.len() < 3 {
        return Err(ApiError::BadRequest(
            "asset must be at least 3 characters".to_string(),
        ));
    }

    if asset.len() > 32 {
        return Err(ApiError::BadRequest(
            "asset must be 32 characters or fewer".to_string(),
        ));
    }

    if !asset.chars().all(|character| {
        character.is_ascii_uppercase() || character.is_ascii_digit() || character == '_'
    }) {
        return Err(ApiError::BadRequest(
            "asset must contain only uppercase letters, digits, or underscores".to_string(),
        ));
    }

    Ok(asset)
}

fn validate_positive_amount(amount: i128) -> Result<i128, ApiError> {
    if amount <= 0 {
        return Err(ApiError::BadRequest("amount must be positive".to_string()));
    }

    Ok(amount)
}

async fn authorize_account_control(
    node: &KaniNode,
    auth: &AuthenticatedInstitution,
    account_id: &str,
) -> Result<Account, ApiError> {
    authorize_account_access(node, auth, account_id, "debit").await
}

async fn authorize_account_read(
    node: &KaniNode,
    auth: &AuthenticatedInstitution,
    account_id: &str,
) -> Result<Account, ApiError> {
    authorize_account_access(node, auth, account_id, "read").await
}

async fn authorize_account_access(
    node: &KaniNode,
    auth: &AuthenticatedInstitution,
    account_id: &str,
    action: &str,
) -> Result<Account, ApiError> {
    let account = ensure_account_exists(node, account_id).await?;

    if account.institution_id.as_deref() == Some(auth.institution_id.as_str()) {
        return Ok(account);
    }

    Err(ApiError::Forbidden(format!(
        "institution is not authorized to {action} account {account_id}"
    )))
}

async fn ensure_account_exists(node: &KaniNode, account_id: &str) -> Result<Account, ApiError> {
    node.accounts()
        .await?
        .into_iter()
        .find(|account| account.id == account_id)
        .ok_or_else(|| ApiError::BadRequest(format!("account {account_id} does not exist")))
}

async fn authorize_payment_read(
    node: &KaniNode,
    auth: &AuthenticatedInstitution,
    payment: &PaymentRecord,
) -> Result<(), ApiError> {
    let accounts = node.accounts().await?;
    let can_read_payment =
        account_belongs_to_institution(&accounts, &payment.transaction.from, &auth.institution_id)
            || account_belongs_to_institution(
                &accounts,
                &payment.transaction.to,
                &auth.institution_id,
            );

    if can_read_payment {
        return Ok(());
    }

    Err(ApiError::Forbidden(format!(
        "institution is not authorized to read payment {}",
        payment.transaction.id
    )))
}

fn account_belongs_to_institution(
    accounts: &[Account],
    account_id: &str,
    institution_id: &str,
) -> bool {
    accounts.iter().any(|account| {
        account.id == account_id && account.institution_id.as_deref() == Some(institution_id)
    })
}

fn authorize_admin(auth: &AuthenticatedInstitution) -> Result<(), ApiError> {
    if auth.is_admin {
        return Ok(());
    }

    Err(ApiError::Forbidden(
        "admin credentials are required for network-wide reads".to_string(),
    ))
}

async fn authenticate_request(
    state: &AppState,
    headers: &HeaderMap,
    action: &str,
    resource: &str,
) -> Result<AuthenticatedInstitution, ApiError> {
    match state.auth.authenticate(headers) {
        Ok(auth) => Ok(auth),
        Err(error) => {
            audit_authorization_denied(state, headers, None, action, resource, &error).await?;
            Err(error)
        }
    }
}

async fn audit_authorization_allowed(
    state: &AppState,
    headers: &HeaderMap,
    auth: &AuthenticatedInstitution,
    action: &str,
    resource: &str,
) -> Result<(), ApiError> {
    audit_authorization_decision(
        state,
        headers,
        Some(auth),
        action,
        resource,
        "ALLOWED",
        "authorized",
        StatusCode::OK,
    )
    .await
}

async fn audit_authorization_denied(
    state: &AppState,
    headers: &HeaderMap,
    auth: Option<&AuthenticatedInstitution>,
    action: &str,
    resource: &str,
    error: &ApiError,
) -> Result<(), ApiError> {
    audit_authorization_decision(
        state,
        headers,
        auth,
        action,
        resource,
        "DENIED",
        error.message(),
        error.status_code(),
    )
    .await
}

#[allow(clippy::too_many_arguments)]
async fn audit_authorization_decision(
    state: &AppState,
    headers: &HeaderMap,
    auth: Option<&AuthenticatedInstitution>,
    action: &str,
    resource: &str,
    decision: &str,
    reason: &str,
    status_code: StatusCode,
) -> Result<(), ApiError> {
    let institution_id = auth
        .map(|auth| auth.institution_id.clone())
        .or_else(|| institution_hint(headers))
        .unwrap_or_else(|| "UNKNOWN".to_string());
    let role = auth.map(auth_role).unwrap_or("UNKNOWN");
    let mut metadata = BTreeMap::new();
    metadata.insert("action".to_string(), action.to_string());
    metadata.insert("decision".to_string(), decision.to_string());
    metadata.insert("institution_id".to_string(), institution_id.clone());
    metadata.insert("reason".to_string(), reason.to_string());
    metadata.insert("resource".to_string(), resource.to_string());
    metadata.insert("role".to_string(), role.to_string());
    metadata.insert("status_code".to_string(), status_code.as_u16().to_string());

    let event = AuditEvent::new(
        "API_AUTHORIZATION_DECISION",
        format!(
            "api authorization decision decision={decision} action={action} resource={resource} institution_id={institution_id} status_code={}",
            status_code.as_u16()
        ),
        None,
        None,
    )
    .with_metadata(metadata);

    state.node.record_audit_event(event).await?;
    Ok(())
}

fn institution_hint(headers: &HeaderMap) -> Option<String> {
    headers
        .get(INSTITUTION_ID_HEADER)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
}

fn auth_role(auth: &AuthenticatedInstitution) -> &'static str {
    if auth.is_admin {
        "ADMIN"
    } else {
        "INSTITUTION"
    }
}

#[derive(Clone, Debug, Default)]
struct BlockFilter {
    limit: i64,
    offset: i64,
}

impl BlockFilter {
    fn try_from_query(query: BlockQuery) -> Result<Self, ApiError> {
        let (limit, offset) = validated_page(
            query.limit,
            query.offset,
            DEFAULT_BLOCK_LIMIT,
            MAX_BLOCK_LIMIT,
        )?;

        Ok(Self { limit, offset })
    }

    fn into_search_with_limit(self, limit: i64) -> BlockSearch {
        BlockSearch {
            limit,
            offset: self.offset,
        }
    }
}

#[derive(Clone, Debug, Default)]
struct AuditEventFilter {
    event_type: Option<String>,
    decision: Option<String>,
    institution_id: Option<String>,
    created_from: Option<DateTime<Utc>>,
    created_to: Option<DateTime<Utc>>,
    limit: i64,
    offset: i64,
}

impl AuditEventFilter {
    fn try_from_query(query: AuditEventQuery) -> Result<Self, ApiError> {
        let created_from = parse_optional_rfc3339("created_from", query.created_from)?;
        let created_to = parse_optional_rfc3339("created_to", query.created_to)?;
        if let (Some(created_from), Some(created_to)) = (created_from.as_ref(), created_to.as_ref())
        {
            if created_from > created_to {
                return Err(ApiError::BadRequest(
                    "created_from must be before or equal to created_to".to_string(),
                ));
            }
        }

        let (limit, offset) = validated_page(
            query.limit,
            query.offset,
            DEFAULT_AUDIT_EVENT_LIMIT,
            MAX_AUDIT_EVENT_LIMIT,
        )?;

        Ok(Self {
            event_type: normalize_optional_filter(query.event_type),
            decision: normalize_optional_filter(query.decision),
            institution_id: normalize_optional_filter(query.institution_id),
            created_from,
            created_to,
            limit,
            offset,
        })
    }

    fn into_search_with_limit(self, limit: i64) -> AuditEventSearch {
        AuditEventSearch {
            event_type: self.event_type,
            decision: self.decision,
            institution_id: self.institution_id,
            created_from: self.created_from,
            created_to: self.created_to,
            limit,
            offset: self.offset,
        }
    }
}

fn validated_page(
    limit: Option<i64>,
    offset: Option<i64>,
    default_limit: i64,
    max_limit: i64,
) -> Result<(i64, i64), ApiError> {
    let limit = limit.unwrap_or(default_limit);
    if limit <= 0 || limit > max_limit {
        return Err(ApiError::BadRequest(format!(
            "limit must be between 1 and {max_limit}"
        )));
    }

    let offset = offset.unwrap_or(0);
    if offset < 0 {
        return Err(ApiError::BadRequest(
            "offset must be greater than or equal to 0".to_string(),
        ));
    }

    Ok((limit, offset))
}

fn parse_optional_rfc3339(
    field_name: &str,
    value: Option<String>,
) -> Result<Option<DateTime<Utc>>, ApiError> {
    let Some(value) = normalize_optional_filter(value) else {
        return Ok(None);
    };

    DateTime::parse_from_rfc3339(&value)
        .map(|value| Some(value.with_timezone(&Utc)))
        .map_err(|_| ApiError::BadRequest(format!("{field_name} must be an RFC3339 timestamp")))
}

fn normalize_optional_filter(value: Option<String>) -> Option<String> {
    value
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
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
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<PaymentResponse>, ApiError> {
    let resource = format!("payment:{id}");
    let auth = authenticate_request(&state, &headers, "read_payment", &resource).await?;
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
    if let Err(error) = authorize_payment_read(&state.node, &auth, &record).await {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_payment",
            &resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_payment", &resource).await?;

    Ok(Json(record.into()))
}

async fn get_accounts(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<Account>>, ApiError> {
    let resource = "network:accounts";
    let auth = authenticate_request(&state, &headers, "read_accounts", resource).await?;
    if let Err(error) = authorize_admin(&auth) {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_accounts",
            resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_accounts", resource).await?;

    Ok(Json(state.node.accounts().await?))
}

async fn get_balance(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((account_id, asset)): Path<(String, String)>,
) -> Result<Json<BalanceResponse>, ApiError> {
    let asset = normalize_asset_code(asset)?;
    let resource = format!("account:{account_id}:balance:{asset}");
    let auth = authenticate_request(&state, &headers, "read_balance", &resource).await?;
    if let Err(error) = authorize_account_read(&state.node, &auth, &account_id).await {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_balance",
            &resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_balance", &resource).await?;
    let amount = state.node.balance(&account_id, &asset).await?;
    Ok(Json(BalanceResponse {
        account_id,
        asset,
        amount,
    }))
}

async fn get_issued(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(asset): Path<String>,
) -> Result<Json<IssuedResponse>, ApiError> {
    let asset = normalize_asset_code(asset)?;
    let resource = format!("asset:{asset}:issued");
    let auth = authenticate_request(&state, &headers, "read_issued_supply", &resource).await?;
    if let Err(error) = authorize_admin(&auth) {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_issued_supply",
            &resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_issued_supply", &resource).await?;

    let amount = state.node.issued(&asset).await?;
    Ok(Json(IssuedResponse { asset, amount }))
}

async fn get_pending_transactions(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<BlockQuery>,
) -> Result<Json<PaginatedResponse<Transaction>>, ApiError> {
    let resource = "network:pending_transactions";
    let auth =
        authenticate_request(&state, &headers, "read_pending_transactions", resource).await?;
    if let Err(error) = authorize_admin(&auth) {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_pending_transactions",
            resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(
        &state,
        &headers,
        &auth,
        "read_pending_transactions",
        resource,
    )
    .await?;
    let filter = BlockFilter::try_from_query(query)?;
    let limit = filter.limit;
    let offset = filter.offset;
    let items = state.node.pending_transactions(limit + 1, offset).await?;
    Ok(Json(PaginatedResponse::from_limit_plus_one(
        items, limit, offset,
    )))
}

async fn get_latest_block(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Block>, ApiError> {
    let resource = "network:latest_block";
    let auth = authenticate_request(&state, &headers, "read_latest_block", resource).await?;
    if let Err(error) = authorize_admin(&auth) {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_latest_block",
            resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_latest_block", resource).await?;
    state
        .node
        .latest_block()
        .await?
        .map(Json)
        .ok_or_else(|| ApiError::NotFound("no finalized blocks yet".to_string()))
}

async fn get_blocks(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<BlockQuery>,
) -> Result<Json<PaginatedResponse<Block>>, ApiError> {
    let resource = "network:blocks";
    let auth = authenticate_request(&state, &headers, "read_blocks", resource).await?;
    if let Err(error) = authorize_admin(&auth) {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_blocks",
            resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_blocks", resource).await?;
    let filter = BlockFilter::try_from_query(query)?;
    let limit = filter.limit;
    let offset = filter.offset;
    let search = filter.into_search_with_limit(limit + 1);
    let items = state.node.blocks(search).await?;
    Ok(Json(PaginatedResponse::from_limit_plus_one(
        items, limit, offset,
    )))
}

async fn get_audit_events(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<AuditEventQuery>,
) -> Result<Json<PaginatedResponse<AuditEvent>>, ApiError> {
    let resource = "network:audit_events";
    let auth = authenticate_request(&state, &headers, "read_audit_events", resource).await?;
    if let Err(error) = authorize_admin(&auth) {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_audit_events",
            resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_audit_events", resource).await?;
    let filter = AuditEventFilter::try_from_query(query)?;
    let limit = filter.limit;
    let offset = filter.offset;
    let search = filter.into_search_with_limit(limit + 1);
    let items = state.node.audit_events(search).await?;
    Ok(Json(PaginatedResponse::from_limit_plus_one(
        items, limit, offset,
    )))
}

async fn get_validators(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<ValidatorResponse>>, ApiError> {
    let resource = "network:validators";
    let auth = authenticate_request(&state, &headers, "read_validators", resource).await?;
    if let Err(error) = authorize_admin(&auth) {
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "read_validators",
            resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "read_validators", resource).await?;
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
    let request = request.validate()?;
    let resource = format!("account:{}", request.treasury);
    let auth = authenticate_request(&state, &headers, "sandbox_mint", &resource).await?;
    let treasury_account =
        match authorize_account_control(&state.node, &auth, &request.treasury).await {
            Ok(account) => account,
            Err(error) => {
                audit_authorization_denied(
                    &state,
                    &headers,
                    Some(&auth),
                    "sandbox_mint",
                    &resource,
                    &error,
                )
                .await?;
                return Err(error);
            }
        };
    if treasury_account.account_type != AccountType::Treasury {
        let error = ApiError::BadRequest(format!(
            "account {} is not a treasury account",
            request.treasury
        ));
        audit_authorization_denied(
            &state,
            &headers,
            Some(&auth),
            "sandbox_mint",
            &resource,
            &error,
        )
        .await?;
        return Err(error);
    }
    audit_authorization_allowed(&state, &headers, &auth, "sandbox_mint", &resource).await?;
    ensure_account_exists(&state.node, &request.to).await?;

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
    use kani_types::{SANDBOX_CORP_A_ACCOUNT, SANDBOX_CORP_B_ACCOUNT, SANDBOX_TREASURY_ACCOUNT};

    #[test]
    fn sandbox_auth_accepts_matching_credentials() {
        let config = SandboxAuthConfig::new(vec![("CORP_A".to_string(), "corp-a-key".to_string())]);
        let auth = config
            .authenticate(&headers_for("CORP_A", "corp-a-key"))
            .unwrap();

        assert_eq!(auth.institution_id, "CORP_A");
        assert!(!auth.is_admin);
    }

    #[test]
    fn sandbox_auth_rejects_invalid_credentials() {
        let config = SandboxAuthConfig::new(vec![("CORP_A".to_string(), "corp-a-key".to_string())]);
        let error = config
            .authenticate(&headers_for("CORP_A", "wrong-key"))
            .unwrap_err();

        assert!(matches!(error, ApiError::Unauthorized(_)));
    }

    #[test]
    fn create_payment_request_validation_normalizes_inputs() {
        let request = CreatePaymentRequest {
            from: " CORP_A ".to_string(),
            to: " CORP_B ".to_string(),
            asset: "KCAD_TEST".to_string(),
            amount: 100,
            client_reference_id: None,
            idempotency_key: None,
        };

        let validated = request.validate().unwrap();

        assert_eq!(validated.from, "CORP_A");
        assert_eq!(validated.to, "CORP_B");
        assert_eq!(validated.asset, "KCAD_TEST");
        assert_eq!(validated.amount, 100);
    }

    #[test]
    fn payment_request_validation_rejects_invalid_inputs() {
        let missing_from = CreatePaymentRequest {
            from: " ".to_string(),
            to: "CORP_B".to_string(),
            asset: "KCAD_TEST".to_string(),
            amount: 100,
            client_reference_id: None,
            idempotency_key: None,
        }
        .validate();
        assert!(matches!(missing_from, Err(ApiError::BadRequest(_))));

        let invalid_asset = CreatePaymentRequest {
            from: "CORP_A".to_string(),
            to: "CORP_B".to_string(),
            asset: "kcad-test".to_string(),
            amount: 100,
            client_reference_id: None,
            idempotency_key: None,
        }
        .validate();
        assert!(matches!(invalid_asset, Err(ApiError::BadRequest(_))));

        let short_asset = CreatePaymentRequest {
            from: "CORP_A".to_string(),
            to: "CORP_B".to_string(),
            asset: "KC".to_string(),
            amount: 100,
            client_reference_id: None,
            idempotency_key: None,
        }
        .validate();
        assert!(matches!(short_asset, Err(ApiError::BadRequest(_))));

        let invalid_amount = CreatePaymentRequest {
            from: "CORP_A".to_string(),
            to: "CORP_B".to_string(),
            asset: "KCAD_TEST".to_string(),
            amount: 0,
            client_reference_id: None,
            idempotency_key: None,
        }
        .validate();
        assert!(matches!(invalid_amount, Err(ApiError::BadRequest(_))));
    }

    #[tokio::test]
    async fn institution_can_authorize_own_account() {
        let node = KaniNode::sandbox_default();
        let auth = AuthenticatedInstitution {
            institution_id: "CORP_A".to_string(),
            is_admin: false,
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
            is_admin: false,
        };

        let error = authorize_account_control(&node, &auth, SANDBOX_CORP_A_ACCOUNT)
            .await
            .unwrap_err();

        assert!(matches!(error, ApiError::Forbidden(_)));
    }

    #[tokio::test]
    async fn institution_can_read_own_account() {
        let node = KaniNode::sandbox_default();
        let auth = AuthenticatedInstitution {
            institution_id: "CORP_A".to_string(),
            is_admin: false,
        };

        let account = authorize_account_read(&node, &auth, SANDBOX_CORP_A_ACCOUNT)
            .await
            .unwrap();

        assert_eq!(account.id, SANDBOX_CORP_A_ACCOUNT);
    }

    #[tokio::test]
    async fn institution_cannot_read_another_institutions_account() {
        let node = KaniNode::sandbox_default();
        let auth = AuthenticatedInstitution {
            institution_id: "CORP_B".to_string(),
            is_admin: false,
        };

        let error = authorize_account_read(&node, &auth, SANDBOX_CORP_A_ACCOUNT)
            .await
            .unwrap_err();

        assert!(matches!(error, ApiError::Forbidden(_)));
    }

    #[tokio::test]
    async fn payment_read_allows_participating_institutions() {
        let node = KaniNode::sandbox_default();
        let payment = PaymentRecord::pending(kani_types::Transaction::new_transfer(
            SANDBOX_CORP_A_ACCOUNT,
            SANDBOX_CORP_B_ACCOUNT,
            "KCAD_TEST",
            100,
            1,
        ));
        let corp_a = AuthenticatedInstitution {
            institution_id: "CORP_A".to_string(),
            is_admin: false,
        };
        let corp_b = AuthenticatedInstitution {
            institution_id: "CORP_B".to_string(),
            is_admin: false,
        };

        authorize_payment_read(&node, &corp_a, &payment)
            .await
            .unwrap();
        authorize_payment_read(&node, &corp_b, &payment)
            .await
            .unwrap();
    }

    #[tokio::test]
    async fn payment_read_rejects_uninvolved_institution() {
        let node = KaniNode::sandbox_default();
        let payment = PaymentRecord::pending(kani_types::Transaction::new_transfer(
            SANDBOX_CORP_A_ACCOUNT,
            SANDBOX_CORP_B_ACCOUNT,
            "KCAD_TEST",
            100,
            1,
        ));
        let treasury = AuthenticatedInstitution {
            institution_id: SANDBOX_TREASURY_INSTITUTION_ID.to_string(),
            is_admin: false,
        };

        let error = authorize_payment_read(&node, &treasury, &payment)
            .await
            .unwrap_err();

        assert!(matches!(error, ApiError::Forbidden(_)));
    }

    #[tokio::test]
    async fn treasury_account_is_controlled_by_treasury_institution() {
        let node = KaniNode::sandbox_default();
        let auth = AuthenticatedInstitution {
            institution_id: SANDBOX_TREASURY_INSTITUTION_ID.to_string(),
            is_admin: false,
        };

        let account = authorize_account_control(&node, &auth, SANDBOX_TREASURY_ACCOUNT)
            .await
            .unwrap();

        assert_eq!(account.account_type, AccountType::Treasury);
    }

    #[tokio::test]
    async fn account_existence_validation_rejects_unknown_destination() {
        let node = KaniNode::sandbox_default();
        let error = ensure_account_exists(&node, "UNKNOWN_ACCOUNT")
            .await
            .unwrap_err();

        assert!(matches!(error, ApiError::BadRequest(_)));
    }

    #[test]
    fn sandbox_admin_auth_accepts_admin_credentials() {
        let config = SandboxAuthConfig::new_with_admins(
            vec![("CORP_A".to_string(), "corp-a-key".to_string())],
            vec![("KANI_ADMIN".to_string(), "admin-key".to_string())],
        );
        let auth = config
            .authenticate(&headers_for("KANI_ADMIN", "admin-key"))
            .unwrap();

        assert_eq!(auth.institution_id, "KANI_ADMIN");
        assert!(auth.is_admin);
    }

    #[test]
    fn network_read_authorization_requires_admin_credentials() {
        let admin = AuthenticatedInstitution {
            institution_id: SANDBOX_ADMIN_ID.to_string(),
            is_admin: true,
        };
        let institution = AuthenticatedInstitution {
            institution_id: "CORP_A".to_string(),
            is_admin: false,
        };

        assert!(authorize_admin(&admin).is_ok());
        assert!(matches!(
            authorize_admin(&institution),
            Err(ApiError::Forbidden(_))
        ));
    }

    #[test]
    fn openapi_contract_declares_phase1_paths_and_schemas() {
        let document: serde_json::Value = serde_json::from_str(OPENAPI_JSON).unwrap();
        assert_eq!(document["openapi"], "3.1.0");

        let paths = document["paths"].as_object().unwrap();
        for path in [
            "/health",
            "/openapi.json",
            "/v1/payments",
            "/v1/payments/{id}",
            "/v1/accounts",
            "/v1/accounts/{account_id}/balances/{asset}",
            "/v1/assets/{asset}/issued",
            "/v1/transactions/pending",
            "/v1/blocks",
            "/v1/blocks/latest",
            "/v1/audit-events",
            "/v1/validators",
            "/v1/sandbox/mint",
        ] {
            assert!(paths.contains_key(path), "missing OpenAPI path {path}");
        }

        let schemas = document["components"]["schemas"].as_object().unwrap();
        for schema in [
            "CreatePaymentRequest",
            "SandboxMintRequest",
            "PaymentResponse",
            "Account",
            "BalanceResponse",
            "IssuedResponse",
            "PaginatedBlockResponse",
            "PaginatedTransactionResponse",
            "PaginatedAuditEventResponse",
            "Block",
            "Transaction",
            "AuditEvent",
            "ValidatorResponse",
            "ErrorResponse",
        ] {
            assert!(
                schemas.contains_key(schema),
                "missing OpenAPI schema {schema}"
            );
        }

        assert_eq!(
            schemas["CreatePaymentRequest"]["properties"]["amount"]["minimum"],
            1
        );
        assert_eq!(
            schemas["SandboxMintRequest"]["properties"]["asset"]["pattern"],
            "^[A-Z0-9_]{3,32}$"
        );
    }

    #[test]
    fn paginated_response_reports_next_offset_when_more_items_exist() {
        let response = PaginatedResponse::from_limit_plus_one(vec![1, 2, 3], 2, 5);

        assert_eq!(response.items, vec![1, 2]);
        assert_eq!(response.limit, 2);
        assert_eq!(response.offset, 5);
        assert_eq!(response.count, 2);
        assert_eq!(response.next_offset, Some(7));
    }

    #[test]
    fn paginated_response_omits_next_offset_on_last_page() {
        let response = PaginatedResponse::from_limit_plus_one(vec![1, 2], 2, 5);

        assert_eq!(response.items, vec![1, 2]);
        assert_eq!(response.count, 2);
        assert_eq!(response.next_offset, None);
    }

    #[test]
    fn block_filter_applies_limit_and_offset() {
        let filter = BlockFilter::try_from_query(BlockQuery {
            limit: Some(2),
            offset: Some(1),
        })
        .unwrap();
        let limit = filter.limit;
        let search = filter.into_search_with_limit(limit);

        let matched = search.apply(vec![
            block_with_height(1),
            block_with_height(2),
            block_with_height(3),
        ]);

        assert_eq!(matched.len(), 2);
        assert_eq!(matched[0].height, 2);
        assert_eq!(matched[1].height, 3);
    }

    #[test]
    fn block_filter_rejects_invalid_page_params() {
        let zero_limit = BlockFilter::try_from_query(BlockQuery {
            limit: Some(0),
            ..BlockQuery::default()
        });
        assert!(matches!(zero_limit, Err(ApiError::BadRequest(_))));

        let negative_limit = BlockFilter::try_from_query(BlockQuery {
            limit: Some(-1),
            ..BlockQuery::default()
        });
        assert!(matches!(negative_limit, Err(ApiError::BadRequest(_))));

        let oversized_limit = BlockFilter::try_from_query(BlockQuery {
            limit: Some(MAX_BLOCK_LIMIT + 1),
            ..BlockQuery::default()
        });
        assert!(matches!(oversized_limit, Err(ApiError::BadRequest(_))));

        let negative_offset = BlockFilter::try_from_query(BlockQuery {
            offset: Some(-1),
            ..BlockQuery::default()
        });
        assert!(matches!(negative_offset, Err(ApiError::BadRequest(_))));
    }

    #[test]
    fn audit_event_filter_matches_event_type_metadata_and_window() {
        let filter = AuditEventFilter::try_from_query(AuditEventQuery {
            event_type: Some("api_authorization_decision".to_string()),
            decision: Some("denied".to_string()),
            institution_id: Some("CORP_B".to_string()),
            created_from: Some("2026-01-01T00:00:00Z".to_string()),
            created_to: Some("2026-12-31T23:59:59Z".to_string()),
            ..AuditEventQuery::default()
        })
        .unwrap();
        let limit = filter.limit;
        let search = filter.into_search_with_limit(limit);

        let matched = search.apply(vec![
            audit_event_with_metadata(
                "API_AUTHORIZATION_DECISION",
                "DENIED",
                "CORP_B",
                "2026-05-02T10:00:00Z",
            ),
            audit_event_with_metadata(
                "API_AUTHORIZATION_DECISION",
                "ALLOWED",
                "CORP_B",
                "2026-05-02T10:00:00Z",
            ),
            audit_event_with_metadata(
                "BLOCK_FINALIZED",
                "DENIED",
                "CORP_B",
                "2026-05-02T10:00:00Z",
            ),
            audit_event_with_metadata(
                "API_AUTHORIZATION_DECISION",
                "DENIED",
                "CORP_A",
                "2026-05-02T10:00:00Z",
            ),
            audit_event_with_metadata(
                "API_AUTHORIZATION_DECISION",
                "DENIED",
                "CORP_B",
                "2025-12-31T23:59:59Z",
            ),
        ]);

        assert_eq!(matched.len(), 1);
        assert_eq!(matched[0].metadata.get("institution_id").unwrap(), "CORP_B");
    }

    #[test]
    fn audit_event_filter_rejects_invalid_time_windows() {
        let invalid_timestamp = AuditEventFilter::try_from_query(AuditEventQuery {
            created_from: Some("not-a-date".to_string()),
            ..AuditEventQuery::default()
        });
        assert!(matches!(invalid_timestamp, Err(ApiError::BadRequest(_))));

        let inverted_window = AuditEventFilter::try_from_query(AuditEventQuery {
            created_from: Some("2026-12-31T00:00:00Z".to_string()),
            created_to: Some("2026-01-01T00:00:00Z".to_string()),
            ..AuditEventQuery::default()
        });
        assert!(matches!(inverted_window, Err(ApiError::BadRequest(_))));
    }

    #[test]
    fn audit_event_filter_applies_limit_and_offset() {
        let filter = AuditEventFilter::try_from_query(AuditEventQuery {
            limit: Some(2),
            offset: Some(1),
            ..AuditEventQuery::default()
        })
        .unwrap();
        let limit = filter.limit;
        let search = filter.into_search_with_limit(limit);

        let matched = search.apply(vec![
            audit_event_with_metadata(
                "API_AUTHORIZATION_DECISION",
                "DENIED",
                "CORP_A",
                "2026-05-02T10:00:00Z",
            ),
            audit_event_with_metadata(
                "API_AUTHORIZATION_DECISION",
                "DENIED",
                "CORP_B",
                "2026-05-02T10:00:01Z",
            ),
            audit_event_with_metadata(
                "API_AUTHORIZATION_DECISION",
                "DENIED",
                "KANI_TREASURY",
                "2026-05-02T10:00:02Z",
            ),
        ]);

        assert_eq!(matched.len(), 2);
        assert_eq!(matched[0].metadata.get("institution_id").unwrap(), "CORP_B");
        assert_eq!(
            matched[1].metadata.get("institution_id").unwrap(),
            "KANI_TREASURY"
        );
    }

    #[test]
    fn audit_event_filter_rejects_invalid_limits() {
        let zero_limit = AuditEventFilter::try_from_query(AuditEventQuery {
            limit: Some(0),
            ..AuditEventQuery::default()
        });
        assert!(matches!(zero_limit, Err(ApiError::BadRequest(_))));

        let negative_limit = AuditEventFilter::try_from_query(AuditEventQuery {
            limit: Some(-1),
            ..AuditEventQuery::default()
        });
        assert!(matches!(negative_limit, Err(ApiError::BadRequest(_))));

        let oversized_limit = AuditEventFilter::try_from_query(AuditEventQuery {
            limit: Some(MAX_AUDIT_EVENT_LIMIT + 1),
            ..AuditEventQuery::default()
        });
        assert!(matches!(oversized_limit, Err(ApiError::BadRequest(_))));

        let negative_offset = AuditEventFilter::try_from_query(AuditEventQuery {
            offset: Some(-1),
            ..AuditEventQuery::default()
        });
        assert!(matches!(negative_offset, Err(ApiError::BadRequest(_))));
    }

    fn audit_event_with_metadata(
        event_type: &str,
        decision: &str,
        institution_id: &str,
        created_at: &str,
    ) -> AuditEvent {
        let mut metadata = BTreeMap::new();
        metadata.insert("decision".to_string(), decision.to_string());
        metadata.insert("institution_id".to_string(), institution_id.to_string());
        let mut event =
            AuditEvent::new(event_type, "test event", None, None).with_metadata(metadata);
        event.created_at = DateTime::parse_from_rfc3339(created_at)
            .unwrap()
            .with_timezone(&Utc);
        event
    }

    fn block_with_height(height: i64) -> Block {
        Block {
            height,
            prev_hash: format!("prev-{height}"),
            txs: Vec::new(),
            validator: "validator-a".to_string(),
            signature: Vec::new(),
            hash: format!("hash-{height}"),
            finalized_by: vec!["validator-a".to_string(), "validator-b".to_string()],
            created_at: Utc::now(),
        }
    }

    fn headers_for(institution_id: &str, api_key: &str) -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert(INSTITUTION_ID_HEADER, institution_id.parse().unwrap());
        headers.insert(API_KEY_HEADER, api_key.parse().unwrap());
        headers
    }
}
