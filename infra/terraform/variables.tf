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
  description = "Enable Cloud SQL automated backups for the sandbox ledger."
  type        = bool
  default     = true
}

variable "cloud_sql_point_in_time_recovery_enabled" {
  description = "Enable Cloud SQL point-in-time recovery. Requires backups and adds transaction log storage cost."
  type        = bool
  default     = true
}

variable "cloud_sql_backup_start_time" {
  description = "UTC start time for Cloud SQL automated backups, in HH:MM format."
  type        = string
  default     = "07:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.cloud_sql_backup_start_time))
    error_message = "cloud_sql_backup_start_time must use HH:MM in UTC, for example 07:00."
  }
}

variable "cloud_sql_backup_retained_count" {
  description = "Number of automated Cloud SQL backups to retain."
  type        = number
  default     = 7

  validation {
    condition     = var.cloud_sql_backup_retained_count >= 1 && var.cloud_sql_backup_retained_count <= 365 && floor(var.cloud_sql_backup_retained_count) == var.cloud_sql_backup_retained_count
    error_message = "cloud_sql_backup_retained_count must be a whole number between 1 and 365."
  }
}

variable "cloud_sql_transaction_log_retention_days" {
  description = "Number of days of Cloud SQL transaction logs retained for point-in-time recovery."
  type        = number
  default     = 7

  validation {
    condition     = var.cloud_sql_transaction_log_retention_days >= 1 && var.cloud_sql_transaction_log_retention_days <= 7 && floor(var.cloud_sql_transaction_log_retention_days) == var.cloud_sql_transaction_log_retention_days
    error_message = "cloud_sql_transaction_log_retention_days must be a whole number between 1 and 7 for Enterprise edition."
  }
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

variable "budget_alert_emails" {
  description = "Explicit email recipients for Cloud Billing budget alerts, in addition to default IAM recipients. Google allows up to five email notification channels per budget."
  type        = list(string)
  default     = []

  validation {
    condition = length(var.budget_alert_emails) <= 5 && alltrue([
      for email in var.budget_alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", trimspace(email)))
    ])
    error_message = "budget_alert_emails must contain at most five valid email addresses."
  }
}

variable "budget_brake_enabled" {
  description = "Create Pub/Sub and Cloud Run resources that pause the validator Scheduler job when budget spend crosses the brake threshold."
  type        = bool
  default     = true
}

variable "budget_pubsub_topic_attachment_enabled" {
  description = "Attach the Cloud Billing budget to the Pub/Sub budget notification topic. Set false if domain-restricted sharing blocks the attachment; the topic, subscription, and cost guard service are still created."
  type        = bool
  default     = true
}

variable "budget_brake_threshold" {
  description = "Decimal budget threshold that triggers the automated brake. For example, 0.8 pauses the validator schedule at 80 percent of budget."
  type        = number
  default     = 0.8

  validation {
    condition     = var.budget_brake_threshold > 0 && var.budget_brake_threshold <= 10
    error_message = "budget_brake_threshold must be greater than 0 and no more than 10."
  }
}

variable "budget_brake_dry_run" {
  description = "When true, budget brake events are acknowledged and logged without pausing the validator Scheduler job."
  type        = bool
  default     = false
}

variable "monitoring_alerts_enabled" {
  description = "Create Phase 2 sandbox Cloud Monitoring alert policies for API, validator, Scheduler, Cloud SQL, and budget brake signals."
  type        = bool
  default     = true
}

variable "monitoring_alert_notification_channels" {
  description = "Additional Cloud Monitoring notification channel resource names for Phase 2 alert policies. Budget email channels are included automatically."
  type        = list(string)
  default     = []
}

variable "monitoring_alert_log_notification_rate_limit" {
  description = "Minimum time between notifications for log-match alert policies."
  type        = string
  default     = "900s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.monitoring_alert_log_notification_rate_limit))
    error_message = "monitoring_alert_log_notification_rate_limit must be a duration in seconds, for example 900s."
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
