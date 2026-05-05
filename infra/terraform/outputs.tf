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

output "gke_cluster_name" {
  description = "GKE cluster for validator nodes."
  value       = google_container_cluster.validators.name
}

output "validator_service_account" {
  description = "Google service account intended for validator Workload Identity."
  value       = google_service_account.validator.email
}

output "block_archive_bucket" {
  description = "Cloud Storage bucket for future block archive writes."
  value       = google_storage_bucket.block_archive.name
}
