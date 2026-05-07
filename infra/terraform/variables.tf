variable "project_id" {
  description = "Google Cloud project ID for the Phase 2 sandbox."
  type        = string
}

variable "region" {
  description = "Primary Google Cloud region."
  type        = string
  default     = "northamerica-northeast1"
}

variable "name_prefix" {
  description = "Prefix used for Phase 2 sandbox resources."
  type        = string
  default     = "kani-sandbox"
}

variable "api_image" {
  description = "Artifact Registry image for kani-api and the Cloud Run validator job."
  type        = string
}

variable "database_tier" {
  description = "Cloud SQL machine tier for the sandbox ledger."
  type        = string
  default     = "db-g1-small"
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

variable "cloud_run_max_instances" {
  description = "Maximum Cloud Run instances for kani-api in the lean sandbox."
  type        = number
  default     = 1
}

variable "validator_ids" {
  description = "Sandbox validator identities swept by the Cloud Run validator job."
  type        = list(string)
  default     = ["validator-a", "validator-b", "validator-c"]
}

variable "validator_job_max_transactions_per_block" {
  description = "Maximum pending transactions the validator job will include in one block."
  type        = number
  default     = 25
}

variable "validator_job_timeout_seconds" {
  description = "Cloud Run validator job task timeout in seconds."
  type        = number
  default     = 300
}

variable "validator_scheduler_enabled" {
  description = "Create a Cloud Scheduler job that periodically executes the sandbox validator Cloud Run job."
  type        = bool
  default     = true
}

variable "validator_schedule" {
  description = "Cron schedule for the sandbox validator Cloud Scheduler job."
  type        = string
  default     = "*/15 * * * *"
}

variable "validator_scheduler_time_zone" {
  description = "Time zone used to interpret the validator Cloud Scheduler cron expression."
  type        = string
  default     = "America/Toronto"
}

variable "validator_scheduler_attempt_deadline_seconds" {
  description = "Cloud Scheduler attempt deadline for invoking the validator job."
  type        = number
  default     = 180

  validation {
    condition     = var.validator_scheduler_attempt_deadline_seconds >= 15 && var.validator_scheduler_attempt_deadline_seconds <= 1800
    error_message = "validator_scheduler_attempt_deadline_seconds must be between 15 and 1800 seconds."
  }
}

variable "validator_scheduler_paused" {
  description = "Create the validator Cloud Scheduler job in a paused state."
  type        = bool
  default     = false
}

variable "budget_guardrail_enabled" {
  description = "Create a project-scoped monthly Cloud Billing budget alert when budget_billing_account_id is set."
  type        = bool
  default     = true
}

variable "budget_billing_account_id" {
  description = "Cloud Billing account ID for the sandbox budget. Accepts either 000000-000000-000000 or billingAccounts/000000-000000-000000."
  type        = string
  default     = ""
  sensitive   = true
}

variable "budget_amount_units" {
  description = "Monthly sandbox budget amount in the billing account currency. This is an alert budget, not a hard spend cap."
  type        = number
  default     = 50

  validation {
    condition     = var.budget_amount_units >= 1 && floor(var.budget_amount_units) == var.budget_amount_units
    error_message = "budget_amount_units must be a whole number greater than or equal to 1."
  }
}

variable "budget_alert_thresholds" {
  description = "Budget alert thresholds as decimal percentages, for example 0.5 for 50 percent."
  type        = list(number)
  default     = [0.5, 0.8, 1.0]

  validation {
    condition     = length(var.budget_alert_thresholds) > 0 && alltrue([for threshold in var.budget_alert_thresholds : threshold > 0 && threshold <= 10])
    error_message = "budget_alert_thresholds must contain positive decimal percentages no greater than 10."
  }
}

variable "cloud_run_ingress" {
  description = "Cloud Run ingress setting for kani-api."
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    ], var.cloud_run_ingress)
    error_message = "cloud_run_ingress must be a supported Cloud Run v2 ingress value."
  }
}

variable "deletion_protection" {
  description = "Enable deletion protection on stateful or expensive cloud resources."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Additional labels applied to supported resources."
  type        = map(string)
  default     = {}
}
