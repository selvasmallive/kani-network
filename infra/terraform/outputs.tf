output "artifact_registry_repository" {
  description = "Artifact Registry repository for KANI images."
  value       = google_artifact_registry_repository.kani.name
}

output "api_service_name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.api.name
}

output "api_service_uri" {
  description = "Cloud Run service URI."
  value       = google_cloud_run_v2_service.api.uri
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name for the sandbox ledger."
  value       = google_sql_database_instance.ledger.connection_name
}

output "cloud_sql_recovery_settings" {
  description = "Cloud SQL backup and point-in-time recovery settings for the sandbox ledger."
  value = {
    backups_enabled                = var.cloud_sql_backups_enabled
    backup_start_time_utc          = var.cloud_sql_backups_enabled ? var.cloud_sql_backup_start_time : null
    retained_backups               = var.cloud_sql_backups_enabled ? var.cloud_sql_backup_retained_count : 0
    point_in_time_recovery         = var.cloud_sql_backups_enabled && var.cloud_sql_point_in_time_recovery_enabled
    transaction_log_retention_days = var.cloud_sql_backups_enabled && var.cloud_sql_point_in_time_recovery_enabled ? var.cloud_sql_transaction_log_retention_days : 0
  }
}

output "database_url_secret_id" {
  description = "Secret Manager secret containing DATABASE_URL."
  value       = google_secret_manager_secret.database_url.secret_id
}

output "sandbox_api_key_secret_ids" {
  description = "Secret Manager secret IDs containing sandbox API keys for the Cloud Run API."
  value = {
    for key, secret in google_secret_manager_secret.sandbox_api_key : key => secret.secret_id
  }
}

output "validator_service_account" {
  description = "Google service account used by the Cloud Run validator job."
  value       = google_service_account.validator.email
}

output "validator_job_name" {
  description = "Cloud Run job that sweeps sandbox validator identities and finalizes pending transactions."
  value       = google_cloud_run_v2_job.validator.name
}

output "validator_scheduler_job_name" {
  description = "Cloud Scheduler job that periodically executes the sandbox validator job."
  value       = try(google_cloud_scheduler_job.validator[0].name, null)
}

output "budget_guardrail_name" {
  description = "Cloud Billing budget resource name for the sandbox project guardrail."
  value       = try(google_billing_budget.sandbox[0].name, null)
}

output "budget_notification_channel_names" {
  description = "Cloud Monitoring email notification channels linked to the sandbox budget."
  value       = [for channel in google_monitoring_notification_channel.budget_email : channel.name]
}

output "phase2_alert_policy_names" {
  description = "Cloud Monitoring alert policy names for Phase 2 sandbox operations."
  value       = [for policy in google_monitoring_alert_policy.phase2_log_alert : policy.name]
}

output "budget_notification_topic" {
  description = "Pub/Sub topic receiving programmatic Cloud Billing budget updates."
  value       = try(google_pubsub_topic.budget_notifications[0].id, null)
}

output "budget_pubsub_topic_attachment_enabled" {
  description = "Whether Terraform is attaching the Cloud Billing budget to the Pub/Sub notification topic."
  value       = local.budget_pubsub_topic_attachment_enabled
}

output "cost_guard_service_name" {
  description = "Cloud Run service that applies the automated budget brake."
  value       = try(google_cloud_run_v2_service.cost_guard[0].name, null)
}

output "cost_guard_service_uri" {
  description = "Cloud Run URI for the automated budget brake service."
  value       = try(google_cloud_run_v2_service.cost_guard[0].uri, null)
}
