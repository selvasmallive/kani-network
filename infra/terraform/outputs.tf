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

output "database_url_secret_id" {
  description = "Secret Manager secret containing DATABASE_URL."
  value       = google_secret_manager_secret.database_url.secret_id
}

output "validator_service_account" {
  description = "Google service account used by the Cloud Run validator job."
  value       = google_service_account.validator.email
}

output "validator_job_name" {
  description = "Cloud Run job that sweeps sandbox validator identities and finalizes pending transactions."
  value       = google_cloud_run_v2_job.validator.name
}
