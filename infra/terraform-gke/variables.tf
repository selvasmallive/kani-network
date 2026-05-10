variable "project_id" {
  description = "Google Cloud project ID for the Phase 5B GKE sandbox pilot."
  type        = string
}

variable "region" {
  description = "Primary Google Cloud region."
  type        = string
  default     = "northamerica-northeast1"
}

variable "name_prefix" {
  description = "Prefix used for sandbox resources shared with Phase 2."
  type        = string
  default     = "kani-sandbox"
}

variable "gke_cluster_name" {
  description = "Name of the Phase 5B sandbox GKE validator cluster."
  type        = string
  default     = "kani-sandbox-validators"
}

variable "gke_location" {
  description = "Zonal location for the Phase 5B sandbox GKE validator cluster."
  type        = string
  default     = "northamerica-northeast1-a"
}

variable "gke_release_channel" {
  description = "GKE release channel for the sandbox validator cluster."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.gke_release_channel)
    error_message = "gke_release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "gke_node_machine_type" {
  description = "Machine type for the Phase 5B sandbox GKE validator node pool."
  type        = string
  default     = "e2-medium"
}

variable "gke_node_count" {
  description = "Node count for the Phase 5B sandbox GKE validator node pool."
  type        = number
  default     = 1

  validation {
    condition     = var.gke_node_count >= 1 && var.gke_node_count <= 3 && floor(var.gke_node_count) == var.gke_node_count
    error_message = "gke_node_count must be a whole number between 1 and 3."
  }
}

variable "gke_node_disk_size_gb" {
  description = "Boot disk size for GKE validator nodes."
  type        = number
  default     = 20

  validation {
    condition     = var.gke_node_disk_size_gb >= 20 && var.gke_node_disk_size_gb <= 100 && floor(var.gke_node_disk_size_gb) == var.gke_node_disk_size_gb
    error_message = "gke_node_disk_size_gb must be a whole number between 20 and 100."
  }
}

variable "gke_node_disk_type" {
  description = "Boot disk type for GKE validator nodes."
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.gke_node_disk_type)
    error_message = "gke_node_disk_type must be pd-standard, pd-balanced, or pd-ssd."
  }
}

variable "gke_node_spot" {
  description = "Use Spot VMs for the Phase 5B sandbox GKE node pool. Keep false for steadier sandbox validation."
  type        = bool
  default     = false
}

variable "gke_workload_identity_namespace" {
  description = "Kubernetes namespace used by the validator service account."
  type        = string
  default     = "kani-system"
}

variable "gke_workload_identity_ksa" {
  description = "Kubernetes service account bound to the validator Google service account."
  type        = string
  default     = "kani-validator"
}

variable "deletion_protection" {
  description = "Enable deletion protection on GKE resources."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Additional labels applied to supported resources."
  type        = map(string)
  default     = {}
}
