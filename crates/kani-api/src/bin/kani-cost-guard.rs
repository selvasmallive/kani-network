use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use base64::{engine::general_purpose::STANDARD, Engine as _};
use kani_node::SandboxRuntimeConfig;
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, env, net::SocketAddr, sync::Arc};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Clone)]
struct AppState {
    client: reqwest::Client,
    config: Arc<CostGuardConfig>,
}

#[derive(Clone, Debug)]
struct CostGuardConfig {
    project_id: String,
    region: String,
    scheduler_job: String,
    budget_id: Option<String>,
    brake_threshold: f64,
    dry_run: bool,
}

#[derive(Clone, Debug, Deserialize)]
struct PubSubPushEnvelope {
    message: PubSubMessage,
    subscription: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
struct PubSubMessage {
    data: Option<String>,
    #[serde(default)]
    attributes: BTreeMap<String, String>,
    #[serde(default, rename = "messageId")]
    message_id: Option<String>,
    #[serde(default, rename = "message_id")]
    legacy_message_id: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BudgetNotification {
    budget_display_name: Option<String>,
    cost_amount: Option<f64>,
    budget_amount: Option<f64>,
    alert_threshold_exceeded: Option<f64>,
    forecast_threshold_exceeded: Option<f64>,
    currency_code: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
struct MetadataTokenResponse {
    access_token: String,
}

#[derive(Debug, Serialize)]
struct HealthResponse {
    service: &'static str,
    status: &'static str,
    environment: &'static str,
    real_value: bool,
    redeemable: bool,
}

#[derive(Debug, Serialize)]
struct BudgetGuardResponse {
    action: &'static str,
    reason: String,
    threshold: f64,
    alert_threshold_exceeded: Option<f64>,
    forecast_threshold_exceeded: Option<f64>,
    cost_amount: Option<f64>,
    budget_amount: Option<f64>,
    currency_code: Option<String>,
    budget_display_name: Option<String>,
    subscription: Option<String>,
    message_id: Option<String>,
    dry_run: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "kani_cost_guard=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let sandbox_runtime = SandboxRuntimeConfig::from_env()?;
    tracing::info!(
        environment = %sandbox_runtime.environment(),
        real_value = sandbox_runtime.real_value(),
        redeemable = sandbox_runtime.redeemable(),
        "validated sandbox runtime flags"
    );

    let config = Arc::new(CostGuardConfig::from_env()?);
    let addr: SocketAddr = env::var("KANI_COST_GUARD_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8080".to_string())
        .parse()?;

    let app = Router::new()
        .route("/health", get(health))
        .route("/v1/budget-events", post(budget_events))
        .with_state(AppState {
            client: reqwest::Client::new(),
            config,
        });
    let listener = tokio::net::TcpListener::bind(addr).await?;

    tracing::info!(%addr, "starting KANI budget cost guard");
    axum::serve(listener, app).await?;

    Ok(())
}

impl CostGuardConfig {
    fn from_env() -> anyhow::Result<Self> {
        let brake_threshold = env::var("KANI_BUDGET_BRAKE_THRESHOLD")
            .unwrap_or_else(|_| "0.8".to_string())
            .parse::<f64>()?;
        if !(0.0..=10.0).contains(&brake_threshold) || brake_threshold == 0.0 {
            anyhow::bail!("KANI_BUDGET_BRAKE_THRESHOLD must be greater than 0 and no more than 10");
        }

        Ok(Self {
            project_id: required_env("KANI_SCHEDULER_PROJECT")?,
            region: required_env("KANI_SCHEDULER_REGION")?,
            scheduler_job: required_env("KANI_SCHEDULER_JOB")?,
            budget_id: optional_env("KANI_BUDGET_ID"),
            brake_threshold,
            dry_run: env::var("KANI_COST_GUARD_DRY_RUN")
                .map(|value| value.eq_ignore_ascii_case("true"))
                .unwrap_or(false),
        })
    }
}

impl PubSubMessage {
    fn data(&self) -> Result<&str, String> {
        self.data
            .as_deref()
            .ok_or_else(|| "Pub/Sub push message missing data field".to_string())
    }

    fn id(&self) -> Option<&str> {
        self.message_id
            .as_deref()
            .or(self.legacy_message_id.as_deref())
    }
}

fn required_env(name: &str) -> anyhow::Result<String> {
    let value = env::var(name)?;
    let value = value.trim().to_string();
    if value.is_empty() {
        anyhow::bail!("{name} must not be empty");
    }
    Ok(value)
}

fn optional_env(name: &str) -> Option<String> {
    env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        service: "kani-cost-guard",
        status: "ok",
        environment: "SANDBOX",
        real_value: false,
        redeemable: false,
    })
}

async fn budget_events(
    State(state): State<AppState>,
    Json(envelope): Json<PubSubPushEnvelope>,
) -> Response {
    match handle_budget_event(&state, envelope).await {
        Ok((status, response)) => (status, Json(response)).into_response(),
        Err(error) => {
            tracing::error!(%error, "failed to process budget event");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": error })),
            )
                .into_response()
        }
    }
}

async fn handle_budget_event(
    state: &AppState,
    envelope: PubSubPushEnvelope,
) -> Result<(StatusCode, BudgetGuardResponse), String> {
    let message_id = envelope.message.id().map(str::to_string);
    let data = match envelope.message.data() {
        Ok(data) => data,
        Err(error) => {
            tracing::warn!(?message_id, %error, "ignoring malformed Pub/Sub push message");
            return Ok((
                StatusCode::OK,
                response_for_invalid(&state.config, &envelope, error),
            ));
        }
    };
    let notification = match decode_budget_notification(data) {
        Ok(notification) => notification,
        Err(error) => {
            tracing::warn!(?message_id, %error, "ignoring invalid budget notification payload");
            return Ok((
                StatusCode::OK,
                response_for_invalid(&state.config, &envelope, error),
            ));
        }
    };
    let response = response_for(&state.config, &envelope, &notification);

    if !budget_id_matches(
        &envelope.message.attributes,
        state.config.budget_id.as_deref(),
    ) {
        tracing::info!(
            ?message_id,
            expected_budget_id = ?state.config.budget_id,
            attributes = ?envelope.message.attributes,
            "ignoring budget notification for a different budget"
        );
        return Ok((StatusCode::OK, response.with_action("ignored")));
    }

    if !should_pause_scheduler(&notification, state.config.brake_threshold) {
        tracing::info!(
            ?message_id,
            threshold = state.config.brake_threshold,
            alert_threshold_exceeded = ?notification.alert_threshold_exceeded,
            cost_amount = ?notification.cost_amount,
            budget_amount = ?notification.budget_amount,
            "budget notification below brake threshold"
        );
        return Ok((StatusCode::OK, response.with_action("ignored")));
    }

    if state.config.dry_run {
        tracing::warn!(
            ?message_id,
            threshold = state.config.brake_threshold,
            "budget brake threshold crossed; dry run enabled"
        );
        return Ok((StatusCode::ACCEPTED, response.with_action("dry_run")));
    }

    pause_scheduler_job(&state.client, &state.config).await?;
    tracing::warn!(
        ?message_id,
        scheduler_job = %state.config.scheduler_job,
        threshold = state.config.brake_threshold,
        "paused validator scheduler after budget brake threshold was crossed"
    );

    Ok((
        StatusCode::ACCEPTED,
        response.with_action("paused_scheduler"),
    ))
}

impl BudgetGuardResponse {
    fn with_action(mut self, action: &'static str) -> Self {
        self.action = action;
        self
    }
}

fn response_for(
    config: &CostGuardConfig,
    envelope: &PubSubPushEnvelope,
    notification: &BudgetNotification,
) -> BudgetGuardResponse {
    BudgetGuardResponse {
        action: "received",
        reason: brake_reason(notification, config.brake_threshold),
        threshold: config.brake_threshold,
        alert_threshold_exceeded: notification.alert_threshold_exceeded,
        forecast_threshold_exceeded: notification.forecast_threshold_exceeded,
        cost_amount: notification.cost_amount,
        budget_amount: notification.budget_amount,
        currency_code: notification.currency_code.clone(),
        budget_display_name: notification.budget_display_name.clone(),
        subscription: envelope.subscription.clone(),
        message_id: envelope.message.id().map(str::to_string),
        dry_run: config.dry_run,
    }
}

fn response_for_invalid(
    config: &CostGuardConfig,
    envelope: &PubSubPushEnvelope,
    reason: String,
) -> BudgetGuardResponse {
    BudgetGuardResponse {
        action: "ignored",
        reason,
        threshold: config.brake_threshold,
        alert_threshold_exceeded: None,
        forecast_threshold_exceeded: None,
        cost_amount: None,
        budget_amount: None,
        currency_code: None,
        budget_display_name: None,
        subscription: envelope.subscription.clone(),
        message_id: envelope.message.id().map(str::to_string),
        dry_run: config.dry_run,
    }
}

fn decode_budget_notification(encoded: &str) -> Result<BudgetNotification, String> {
    let decoded = STANDARD
        .decode(encoded)
        .map_err(|error| format!("invalid Pub/Sub base64 payload: {error}"))?;
    serde_json::from_slice(&decoded)
        .map_err(|error| format!("invalid Cloud Billing budget notification JSON: {error}"))
}

fn budget_id_matches(
    attributes: &BTreeMap<String, String>,
    expected_budget_id: Option<&str>,
) -> bool {
    let Some(expected_budget_id) = expected_budget_id else {
        return true;
    };

    attributes
        .get("budgetId")
        .map(|actual| actual == expected_budget_id)
        .unwrap_or(false)
}

fn should_pause_scheduler(notification: &BudgetNotification, brake_threshold: f64) -> bool {
    if notification
        .alert_threshold_exceeded
        .is_some_and(|threshold| threshold >= brake_threshold)
    {
        return true;
    }

    notification
        .cost_amount
        .zip(notification.budget_amount)
        .is_some_and(|(cost_amount, budget_amount)| {
            budget_amount > 0.0 && cost_amount / budget_amount >= brake_threshold
        })
}

fn brake_reason(notification: &BudgetNotification, brake_threshold: f64) -> String {
    if let Some(alert_threshold) = notification.alert_threshold_exceeded {
        if alert_threshold >= brake_threshold {
            return format!(
                "actual spend alert threshold {alert_threshold:.2} crossed brake threshold {brake_threshold:.2}"
            );
        }
    }

    if let Some((cost_amount, budget_amount)) =
        notification.cost_amount.zip(notification.budget_amount)
    {
        if budget_amount > 0.0 {
            let ratio = cost_amount / budget_amount;
            if ratio >= brake_threshold {
                return format!(
                    "cost ratio {ratio:.2} crossed brake threshold {brake_threshold:.2}"
                );
            }
        }
    }

    "budget notification did not cross brake threshold".to_string()
}

async fn pause_scheduler_job(
    client: &reqwest::Client,
    config: &CostGuardConfig,
) -> Result<(), String> {
    let token = metadata_access_token(client).await?;
    let url = format!(
        "https://cloudscheduler.googleapis.com/v1/projects/{}/locations/{}/jobs/{}:pause",
        config.project_id, config.region, config.scheduler_job
    );
    let response = client
        .post(url)
        .bearer_auth(token)
        .json(&serde_json::json!({}))
        .send()
        .await
        .map_err(|error| format!("failed to call Cloud Scheduler pause API: {error}"))?;

    if response.status().is_success() {
        return Ok(());
    }

    let status = response.status();
    let body = response.text().await.unwrap_or_default();
    Err(format!(
        "Cloud Scheduler pause API returned {status}: {body}"
    ))
}

async fn metadata_access_token(client: &reqwest::Client) -> Result<String, String> {
    let response = client
        .get("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token")
        .header("Metadata-Flavor", "Google")
        .send()
        .await
        .map_err(|error| format!("failed to query metadata server token: {error}"))?
        .error_for_status()
        .map_err(|error| format!("metadata server token request failed: {error}"))?
        .json::<MetadataTokenResponse>()
        .await
        .map_err(|error| format!("failed to decode metadata server token: {error}"))?;

    Ok(response.access_token)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_budget_notification_payload() {
        let payload = STANDARD.encode(
            r#"{"budgetDisplayName":"kani-sandbox","costAmount":41.0,"budgetAmount":50.0,"alertThresholdExceeded":0.8,"currencyCode":"CAD"}"#,
        );

        let notification = decode_budget_notification(&payload).unwrap();

        assert_eq!(
            notification.budget_display_name.as_deref(),
            Some("kani-sandbox")
        );
        assert_eq!(notification.cost_amount, Some(41.0));
        assert_eq!(notification.budget_amount, Some(50.0));
        assert_eq!(notification.alert_threshold_exceeded, Some(0.8));
        assert_eq!(notification.currency_code.as_deref(), Some("CAD"));
    }

    #[test]
    fn alert_threshold_triggers_scheduler_pause() {
        let notification = BudgetNotification {
            budget_display_name: None,
            cost_amount: Some(35.0),
            budget_amount: Some(50.0),
            alert_threshold_exceeded: Some(0.8),
            forecast_threshold_exceeded: None,
            currency_code: Some("CAD".to_string()),
        };

        assert!(should_pause_scheduler(&notification, 0.8));
    }

    #[test]
    fn cost_ratio_triggers_scheduler_pause_without_alert_field() {
        let notification = BudgetNotification {
            budget_display_name: None,
            cost_amount: Some(41.0),
            budget_amount: Some(50.0),
            alert_threshold_exceeded: None,
            forecast_threshold_exceeded: None,
            currency_code: Some("CAD".to_string()),
        };

        assert!(should_pause_scheduler(&notification, 0.8));
    }

    #[test]
    fn ignores_notifications_below_threshold() {
        let notification = BudgetNotification {
            budget_display_name: None,
            cost_amount: Some(20.0),
            budget_amount: Some(50.0),
            alert_threshold_exceeded: Some(0.5),
            forecast_threshold_exceeded: None,
            currency_code: Some("CAD".to_string()),
        };

        assert!(!should_pause_scheduler(&notification, 0.8));
    }

    #[test]
    fn requires_matching_budget_id_when_configured() {
        let attributes = BTreeMap::from([("budgetId".to_string(), "budget-1".to_string())]);

        assert!(budget_id_matches(&attributes, Some("budget-1")));
        assert!(!budget_id_matches(&attributes, Some("budget-2")));
        assert!(budget_id_matches(&attributes, None));
    }

    #[test]
    fn accepts_modern_and_legacy_pubsub_message_ids() {
        let envelope = serde_json::from_str::<PubSubPushEnvelope>(
            r#"{
                "message": {
                    "data": "e30=",
                    "messageId": "modern-id",
                    "message_id": "legacy-id",
                    "attributes": {}
                },
                "subscription": "projects/kani/subscriptions/budget"
            }"#,
        )
        .unwrap();

        assert_eq!(envelope.message.id(), Some("modern-id"));
        assert_eq!(envelope.message.data().unwrap(), "e30=");
    }

    #[test]
    fn invalid_response_is_acknowledged_as_ignored() {
        let config = CostGuardConfig {
            project_id: "kani-network-sandbox".to_string(),
            region: "northamerica-northeast1".to_string(),
            scheduler_job: "kani-sandbox-validator-schedule".to_string(),
            budget_id: Some("budget-1".to_string()),
            brake_threshold: 0.8,
            dry_run: false,
        };
        let envelope = PubSubPushEnvelope {
            message: PubSubMessage {
                data: None,
                attributes: BTreeMap::new(),
                message_id: Some("message-1".to_string()),
                legacy_message_id: None,
            },
            subscription: Some("subscription-1".to_string()),
        };

        let response = response_for_invalid(&config, &envelope, "bad payload".to_string());

        assert_eq!(response.action, "ignored");
        assert_eq!(response.reason, "bad payload");
        assert_eq!(response.message_id.as_deref(), Some("message-1"));
    }
}
