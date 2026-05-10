variable "phase5b_gke_terraform_design_enabled" {
  description = "Design-only guard for Phase 5B GKE Terraform planning. This must remain false in phase5b-gke-terraform-design-plan-rc1."
  type        = bool
  default     = false

  validation {
    condition     = var.phase5b_gke_terraform_design_enabled == false
    error_message = "phase5b-gke-terraform-design-plan-rc1 is design-only. Keep phase5b_gke_terraform_design_enabled=false until a later approved apply slice."
  }
}

variable "phase5b_gke_selected_profile" {
  description = "Future GKE resource profile selection for planning only. No GKE resources are created by this slice."
  type        = string
  default     = "lean_sandbox_standard_zonal"

  validation {
    condition = contains([
      "lean_sandbox_standard_zonal",
      "validator_ops_standard_multizone",
      "autopilot_small_pod_request"
    ], var.phase5b_gke_selected_profile)
    error_message = "phase5b_gke_selected_profile must be lean_sandbox_standard_zonal, validator_ops_standard_multizone, or autopilot_small_pod_request."
  }
}

variable "phase5b_gke_design_zones" {
  description = "Future GKE zones for planning only. No cluster, node pool, or subnet resources are created by this slice."
  type        = list(string)
  default     = ["northamerica-northeast1-a"]

  validation {
    condition     = length(var.phase5b_gke_design_zones) >= 1 && alltrue([for zone in var.phase5b_gke_design_zones : trimspace(zone) != ""])
    error_message = "phase5b_gke_design_zones must contain at least one non-empty zone."
  }
}

variable "phase5b_gke_design_node_machine_type" {
  description = "Future GKE Standard node machine type for planning only."
  type        = string
  default     = "e2-small"
}

variable "phase5b_gke_design_node_min_count" {
  description = "Future GKE Standard node-pool minimum size for planning only."
  type        = number
  default     = 1

  validation {
    condition     = var.phase5b_gke_design_node_min_count >= 0 && floor(var.phase5b_gke_design_node_min_count) == var.phase5b_gke_design_node_min_count
    error_message = "phase5b_gke_design_node_min_count must be a whole number greater than or equal to 0."
  }
}

variable "phase5b_gke_design_node_max_count" {
  description = "Future GKE Standard node-pool maximum size for planning only."
  type        = number
  default     = 3

  validation {
    condition     = var.phase5b_gke_design_node_max_count >= var.phase5b_gke_design_node_min_count && floor(var.phase5b_gke_design_node_max_count) == var.phase5b_gke_design_node_max_count
    error_message = "phase5b_gke_design_node_max_count must be a whole number greater than or equal to phase5b_gke_design_node_min_count."
  }
}

variable "phase5b_gke_design_validator_replicas" {
  description = "Future validator replica count for GKE planning only."
  type        = number
  default     = 3

  validation {
    condition     = var.phase5b_gke_design_validator_replicas == 3
    error_message = "Phase 5B GKE validator planning keeps exactly three sandbox validator replicas."
  }
}

locals {
  phase5b_gke_deferred_google_resource_families = [
    "google_container_cluster",
    "google_container_node_pool",
    "google_service_account",
    "google_project_iam_member",
    "google_service_account_iam_member",
    "google_artifact_registry_repository_iam_member",
    "google_secret_manager_secret_iam_member",
    "google_monitoring_alert_policy",
    "google_logging_metric",
    "google_billing_budget"
  ]

  phase5b_gke_deferred_kubernetes_resource_families = [
    "Namespace",
    "ServiceAccount",
    "ConfigMap",
    "SecretProviderClass",
    "Deployment",
    "StatefulSet",
    "PodDisruptionBudget",
    "NetworkPolicy",
    "Service",
    "CronJob"
  ]

  phase5b_gke_terraform_design_plan = {
    release_candidate              = "phase5b-gke-terraform-design-plan-rc1"
    status                         = "design-only"
    enabled                        = var.phase5b_gke_terraform_design_enabled
    active_runtime_baseline        = "phase2-lean-no-gke"
    selected_profile               = var.phase5b_gke_selected_profile
    region                         = var.region
    zones                          = var.phase5b_gke_design_zones
    node_machine_type              = var.phase5b_gke_design_node_machine_type
    node_min_count                 = var.phase5b_gke_design_node_min_count
    node_max_count                 = var.phase5b_gke_design_node_max_count
    validator_replicas             = var.phase5b_gke_design_validator_replicas
    validator_namespace            = "kani-validator"
    validator_service_account      = "kani-gke-validator"
    workload_identity_model        = "gke_workload_identity_federation"
    secret_access_model            = "secret_manager_read_only_via_workload_identity"
    database_access_model          = "cloud_sql_connector_or_private_ip_design_pending"
    networking_model               = "no_public_production_ingress"
    observability_model            = "cloud_logging_monitoring_alerts"
    budget_guardrail_model         = "reuse_phase2_budget_guardrails_or_new_gke_budget_after_approval"
    teardown_model                 = "destroy_or_scale_down_after_approved_test_window"
    creates_paid_resources         = false
    changes_google_cloud_resources = false
    terraform_apply_allowed        = false
    gke_cluster_enabled            = false
    gke_node_pool_creation_enabled = false
    live_validator_operations      = false
    deferred_google_resources      = local.phase5b_gke_deferred_google_resource_families
    deferred_kubernetes_resources  = local.phase5b_gke_deferred_kubernetes_resource_families

    implementation_stages = [
      "stage_0_design_only",
      "stage_1_cost_estimate_attached",
      "stage_2_terraform_plan_draft",
      "stage_3_security_review",
      "stage_4_apply_candidate",
      "stage_5_sandbox_gke_pilot",
      "stage_6_validator_operations_rehearsal",
      "stage_7_teardown_or_pause"
    ]

    required_gates_before_apply = [
      "cost_estimate_attached",
      "selected_profile_approved",
      "terraform_design_reviewed",
      "terraform_plan_reviewed",
      "security_architecture_reviewed",
      "iam_boundary_reviewed",
      "workload_identity_reviewed",
      "networking_reviewed",
      "secret_access_reviewed",
      "database_access_reviewed",
      "observability_reviewed",
      "budget_guardrail_reviewed",
      "quota_review_completed",
      "teardown_plan_approved",
      "rollback_plan_approved",
      "operator_assigned",
      "reviewer_assigned",
      "no_real_value_capability_enabled"
    ]
  }
}

output "phase5b_gke_terraform_design_plan" {
  description = "Design-only Phase 5B GKE Terraform plan. This output creates no Google Cloud or Kubernetes resources."
  value       = local.phase5b_gke_terraform_design_plan
}
