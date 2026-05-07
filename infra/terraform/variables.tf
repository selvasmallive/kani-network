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
  description = "Zonal location for the lean validator GKE cluster. Use a regional location only when you intentionally accept higher cost."
  type        = string
  default     = "northamerica-northeast1-a"
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
  default     = "db-f1-micro"
}

variable "cloud_sql_disk_size_gb" {
  description = "Cloud SQL data disk size in GiB."
  type        = number
  default     = 10
}

variable "cloud_sql_disk_type" {
  description = "Cloud SQL data disk type."
  type        = string
  default     = "PD_HDD"

  validation {
    condition     = contains(["PD_HDD", "PD_SSD"], var.cloud_sql_disk_type)
    error_message = "cloud_sql_disk_type must be PD_HDD or PD_SSD."
  }
}

variable "cloud_sql_backups_enabled" {
  description = "Enable Cloud SQL automated backups. Disabled by default in the lean free-trial sandbox."
  type        = bool
  default     = false
}

variable "cloud_sql_point_in_time_recovery_enabled" {
  description = "Enable Cloud SQL point-in-time recovery. Requires backups and adds storage cost."
  type        = bool
  default     = false
}

variable "gke_node_count" {
  description = "Number of nodes for the validator pool."
  type        = number
  default     = 1
}

variable "gke_machine_type" {
  description = "Machine type for validator nodes."
  type        = string
  default     = "e2-small"
}

variable "gke_disk_size_gb" {
  description = "Boot disk size in GiB for validator nodes."
  type        = number
  default     = 20
}

variable "gke_disk_type" {
  description = "Boot disk type for validator nodes."
  type        = string
  default     = "pd-standard"
}

variable "cloud_run_max_instances" {
  description = "Maximum Cloud Run instances for kani-api in the lean sandbox."
  type        = number
  default     = 1
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
