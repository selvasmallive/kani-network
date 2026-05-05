variable "project_id" {
  description = "Google Cloud project ID for the Phase 2 sandbox."
  type        = string
}

variable "region" {
  description = "Primary Google Cloud region."
  type        = string
  default     = "northamerica-northeast1"
}

variable "gke_location" {
  description = "Regional or zonal location for the validator GKE cluster."
  type        = string
  default     = "northamerica-northeast1"
}

variable "name_prefix" {
  description = "Prefix used for Phase 2 sandbox resources."
  type        = string
  default     = "kani-sandbox"
}

variable "api_image" {
  description = "Artifact Registry image for kani-api and kani-node."
  type        = string
}

variable "database_url" {
  description = "Sandbox PostgreSQL DATABASE_URL stored in Secret Manager. For production, populate secrets outside Terraform state."
  type        = string
  sensitive   = true
}

variable "database_tier" {
  description = "Cloud SQL machine tier for the sandbox ledger."
  type        = string
  default     = "db-custom-1-3840"
}

variable "gke_node_count" {
  description = "Number of nodes for the validator pool."
  type        = number
  default     = 3
}

variable "gke_machine_type" {
  description = "Machine type for validator nodes."
  type        = string
  default     = "e2-standard-2"
}

variable "cloud_run_ingress" {
  description = "Cloud Run ingress setting for kani-api."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    ], var.cloud_run_ingress)
    error_message = "cloud_run_ingress must be a supported Cloud Run v2 ingress value."
  }
}

variable "network_cidr" {
  description = "Primary subnet CIDR for the sandbox network."
  type        = string
  default     = "10.20.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pods."
  type        = string
  default     = "10.24.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE services."
  type        = string
  default     = "10.28.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "Private GKE control plane CIDR. Must be a /28."
  type        = string
  default     = "172.16.0.0/28"
}

variable "deletion_protection" {
  description = "Enable deletion protection on stateful or expensive cloud resources."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels applied to supported resources."
  type        = map(string)
  default     = {}
}
