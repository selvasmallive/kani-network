variable "phase4_dr_readiness_enabled" {
  description = "Design-only guard for Phase 4 disaster recovery readiness planning. This must remain false in phase4-dr-readiness-rc1."
  type        = bool
  default     = false

  validation {
    condition     = var.phase4_dr_readiness_enabled == false
    error_message = "phase4-dr-readiness-rc1 is design-only. Keep phase4_dr_readiness_enabled=false until a later approved drill or apply slice."
  }
}

variable "phase4_dr_sandbox_target_rto" {
  description = "Planning-only sandbox no-GKE recovery time objective. This is not a production SLA."
  type        = string
  default     = "4h"
}

variable "phase4_dr_sandbox_target_rpo" {
  description = "Planning-only sandbox no-GKE recovery point objective. This is not a production SLA."
  type        = string
  default     = "15m"
}

variable "phase4_dr_preprod_target_rto" {
  description = "Planning-only preproduction no-GKE recovery time objective. This is not a production SLA."
  type        = string
  default     = "2h"
}

variable "phase4_dr_preprod_target_rpo" {
  description = "Planning-only preproduction no-GKE recovery point objective. This is not a production SLA."
  type        = string
  default     = "15m"
}

locals {
  phase4_dr_recovery_domains = [
    "ledger_database",
    "ledger_integrity",
    "api_runtime",
    "validator_runtime",
    "secrets_and_credentials",
    "artifact_and_config",
    "audit_and_reporting",
    "operator_runbooks"
  ]

  phase4_dr_evidence_drills = [
    "backup_configuration_inventory",
    "backup_list_capture",
    "pitr_restore_to_separate_instance",
    "migration_and_startup_check",
    "ledger_reconciliation_check",
    "validator_recovery_check",
    "secret_recovery_check",
    "reporting_recovery_check",
    "abandon_or_cutover_decision",
    "post_drill_report"
  ]

  phase4_dr_readiness = {
    release_candidate              = "phase4-dr-readiness-rc1"
    status                         = "design-only"
    enabled                        = var.phase4_dr_readiness_enabled
    active_runtime_baseline        = "phase2-lean-no-gke"
    creates_paid_resources         = false
    changes_google_cloud_resources = false
    creates_real_value_capability  = false
    restore_drill_executed         = false
    restore_instance_created       = false
    production_recovery_enabled    = false
    recovery_domains               = local.phase4_dr_recovery_domains
    evidence_drills                = local.phase4_dr_evidence_drills

    target_rto_rpo = {
      sandbox_no_gke = {
        target_rto     = var.phase4_dr_sandbox_target_rto
        target_rpo     = var.phase4_dr_sandbox_target_rpo
        restore_source = "cloud_sql_backup_or_pitr"
        production_sla = false
      }
      preprod_no_gke_candidate = {
        target_rto     = var.phase4_dr_preprod_target_rto
        target_rpo     = var.phase4_dr_preprod_target_rpo
        restore_source = "cloud_sql_backup_or_pitr"
        production_sla = false
      }
      production_candidate = {
        target_rto     = "blocked_until_production_service_model_approved"
        target_rpo     = "blocked_until_production_service_model_approved"
        restore_source = "blocked"
        production_sla = false
      }
    }

    required_gates_before_drill_execution = [
      "cost_estimate_reviewed_and_approved",
      "drill_owner_and_reviewer_assigned",
      "maintenance_window_or_sandbox_isolation_approved",
      "terraform_plan_reviewed_if_temporary_resources_are_needed",
      "cloud_sql_restore_target_named_and_approved",
      "secret_access_and_rotation_plan_reviewed",
      "reconciliation_checklist_approved",
      "incident_response_and_communication_plan_approved",
      "data_retention_and_privacy_review_completed",
      "regulatory_readiness_non_override_confirmed"
    ]

    deferred_resources = [
      "google_sql_database_instance_restore_target",
      "google_sql_backup_restore",
      "google_sql_database_instance_cross_region_replica",
      "google_storage_bucket_archive",
      "cloud_scheduler_pause_or_resume_change"
    ]
  }
}

output "phase4_dr_readiness" {
  description = "Design-only Phase 4 disaster recovery readiness plan. This output creates no Google Cloud resources."
  value       = local.phase4_dr_readiness
}
