output "gke_cluster_name" {
  description = "Phase 5B sandbox GKE validator cluster name."
  value       = google_container_cluster.validators.name
}

output "gke_cluster_location" {
  description = "Phase 5B sandbox GKE validator cluster location."
  value       = google_container_cluster.validators.location
}

output "gke_node_service_account" {
  description = "Google service account used by GKE validator nodes."
  value       = google_service_account.gke_node.email
}

output "validator_service_account" {
  description = "Google service account bound to the Kubernetes validator service account through Workload Identity."
  value       = local.validator_service_account_email
}

output "gke_validator_workload_identity_member" {
  description = "Kubernetes service account member bound to the validator Google service account."
  value       = local.workload_identity_member
}
