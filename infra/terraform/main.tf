locals {
  labels = merge(
    {
      app         = "kani"
      environment = "sandbox"
      phase       = "phase-2"
    },
    var.labels
  )

  cloud_build_runtime_service_account    = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
  budget_billing_account_id              = replace(trimspace(nonsensitive(var.budget_billing_account_id)), "billingAccounts/", "")
  budget_guardrail_enabled               = var.budget_guardrail_enabled && local.budget_billing_account_id != ""
  budget_brake_enabled                   = local.budget_guardrail_enabled && var.budget_brake_enabled
  budget_pubsub_topic_attachment_enabled = local.budget_brake_enabled && var.budget_pubsub_topic_attachment_enabled
  budget_alert_emails                    = toset([for email in var.budget_alert_emails : trimspace(email) if trimspace(email) != ""])
  monitoring_alert_notification_channels = distinct(concat(
    [for channel in google_monitoring_notification_channel.budget_email : channel.name],
    var.monitoring_alert_notification_channels
  ))

  required_services = toset([
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com"
  ])

  database_url = "postgres://kani:${urlencode(random_password.database_user.result)}@localhost/kani?host=/cloudsql/${google_sql_database_instance.ledger.connection_name}"

  sandbox_api_keys = {
    treasury = {
      env_name      = "KANI_SANDBOX_TREASURY_API_KEY"
      secret_suffix = "treasury-api-key"
    }
    corp_a = {
      env_name      = "KANI_SANDBOX_CORP_A_API_KEY"
      secret_suffix = "corp-a-api-key"
    }
    corp_b = {
      env_name      = "KANI_SANDBOX_CORP_B_API_KEY"
      secret_suffix = "corp-b-api-key"
    }
    admin = {
      env_name      = "KANI_SANDBOX_ADMIN_API_KEY"
      secret_suffix = "admin-api-key"
    }
  }

  monitoring_log_alerts = var.monitoring_alerts_enabled ? {
    api_error_logs = {
      display_name           = "${var.name_prefix} API error logs"
      condition_display_name = "Cloud Run API emitted errors"
      filter                 = <<-EOT
        resource.type="cloud_run_revision"
        resource.labels.service_name="${google_cloud_run_v2_service.api.name}"
        (severity>=ERROR OR httpRequest.status>=500)
      EOT
      documentation          = "Cloud Run API emitted an error log or returned a 5xx response. Check the `kani-api` revision logs and recent `/health` and payment requests."
    }

    validator_job_error_logs = {
      display_name           = "${var.name_prefix} validator job error logs"
      condition_display_name = "Validator Cloud Run Job emitted errors"
      filter                 = <<-EOT
        resource.type="cloud_run_job"
        resource.labels.job_name="${google_cloud_run_v2_job.validator.name}"
        severity>=ERROR
      EOT
      documentation          = "The validator Cloud Run Job emitted an error. Inspect the latest job execution and verify pending transactions, latest block, and finality votes."
    }

    scheduler_error_logs = {
      display_name           = "${var.name_prefix} validator scheduler error logs"
      condition_display_name = "Validator Cloud Scheduler job emitted errors"
      filter                 = <<-EOT
        resource.type="cloud_scheduler_job"
        resource.labels.job_id="${try(google_cloud_scheduler_job.validator[0].name, "${var.name_prefix}-validator-schedule")}"
        severity>=ERROR
      EOT
      documentation          = "The validator Scheduler job emitted an error. Confirm the schedule is enabled, the target Cloud Run Job exists, and scheduler IAM can invoke it."
    }

    cloud_sql_error_logs = {
      display_name           = "${var.name_prefix} Cloud SQL error logs"
      condition_display_name = "Cloud SQL ledger emitted errors"
      filter                 = <<-EOT
        resource.type="cloudsql_database"
        (resource.labels.database_id="${google_sql_database_instance.ledger.name}" OR resource.labels.database_id="${var.project_id}:${google_sql_database_instance.ledger.name}")
        severity>=ERROR
      EOT
      documentation          = "Cloud SQL emitted an error for the sandbox ledger. Check instance health, storage, connections, backups, and recent restore activity."
    }

    budget_brake_activity_logs = {
      display_name           = "${var.name_prefix} budget brake activity"
      condition_display_name = "Budget brake emitted warning or error activity"
      filter                 = <<-EOT
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.name_prefix}-cost-guard"
        severity>=WARNING
        ("budget brake threshold crossed" OR "paused validator scheduler after budget brake threshold was crossed" OR "failed to process budget event")
      EOT
      documentation          = "The budget brake crossed its threshold, paused the validator schedule, or failed while processing a budget event. Inspect cost-guard logs and the Cloud Scheduler job state."
    }
  } : {}
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "kani" {
  location      = var.region
  repository_id = "kani"
  description   = "KANI sandbox container images"
  format        = "DOCKER"
  labels        = local.labels

  depends_on = [google_project_service.required]
}

resource "google_service_account" "api" {
  account_id   = "${var.name_prefix}-api"
  display_name = "KANI sandbox API"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "validator" {
  account_id   = "${var.name_prefix}-validator"
  display_name = "KANI sandbox validator"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "scheduler" {
  count = var.validator_scheduler_enabled ? 1 : 0

  account_id   = "${var.name_prefix}-scheduler"
  display_name = "KANI sandbox validator scheduler"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "cost_guard" {
  count = local.budget_brake_enabled ? 1 : 0

  account_id   = "${var.name_prefix}-cost-guard"
  display_name = "KANI sandbox cost guard"

  depends_on = [google_project_service.required]
}

resource "google_sql_database_instance" "ledger" {
  name                = "${var.name_prefix}-ledger"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.database_tier
    availability_type = "ZONAL"
    disk_autoresize   = true
    disk_size         = var.cloud_sql_disk_size_gb
    disk_type         = var.cloud_sql_disk_type
    edition           = "ENTERPRISE"

    backup_configuration {
      enabled                        = var.cloud_sql_backups_enabled
      start_time                     = var.cloud_sql_backups_enabled ? var.cloud_sql_backup_start_time : null
      point_in_time_recovery_enabled = var.cloud_sql_backups_enabled && var.cloud_sql_point_in_time_recovery_enabled
      transaction_log_retention_days = var.cloud_sql_backups_enabled && var.cloud_sql_point_in_time_recovery_enabled ? var.cloud_sql_transaction_log_retention_days : null

      dynamic "backup_retention_settings" {
        for_each = var.cloud_sql_backups_enabled ? [1] : []

        content {
          retained_backups = var.cloud_sql_backup_retained_count
          retention_unit   = "COUNT"
        }
      }
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }

  lifecycle {
    precondition {
      condition     = !var.cloud_sql_point_in_time_recovery_enabled || var.cloud_sql_backups_enabled
      error_message = "cloud_sql_point_in_time_recovery_enabled requires cloud_sql_backups_enabled."
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_sql_database" "ledger" {
  name     = "kani"
  instance = google_sql_database_instance.ledger.name
}

resource "random_password" "database_user" {
  length  = 32
  special = false
}

resource "google_sql_user" "ledger" {
  name     = "kani"
  instance = google_sql_database_instance.ledger.name
  password = random_password.database_user.result
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "${var.name_prefix}-database-url"
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = local.database_url

  depends_on = [google_sql_user.ledger]
}

resource "random_password" "sandbox_api_key" {
  for_each = local.sandbox_api_keys

  length  = 40
  special = false
}

resource "google_secret_manager_secret" "sandbox_api_key" {
  for_each = local.sandbox_api_keys

  secret_id = "${var.name_prefix}-${each.value.secret_suffix}"
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "sandbox_api_key" {
  for_each = local.sandbox_api_keys

  secret      = google_secret_manager_secret.sandbox_api_key[each.key].id
  secret_data = random_password.sandbox_api_key[each.key].result
}

resource "google_secret_manager_secret_iam_member" "api_database_url" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_sandbox_api_key" {
  for_each = local.sandbox_api_keys

  secret_id = google_secret_manager_secret.sandbox_api_key[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "validator_database_url" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.validator.email}"
}

resource "google_project_iam_member" "api_cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_project_iam_member" "validator_cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.validator.email}"
}

resource "google_project_iam_member" "cloud_build_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.cloud_build_runtime_service_account}"
}

resource "google_project_iam_member" "cloud_build_source_reader" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.cloud_build_runtime_service_account}"
}

resource "google_project_iam_member" "cloud_build_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.cloud_build_runtime_service_account}"
}

resource "google_cloud_run_v2_service" "api" {
  name                = "${var.name_prefix}-api"
  location            = var.region
  ingress             = var.cloud_run_ingress
  deletion_protection = var.deletion_protection
  labels              = local.labels

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.cloud_run_max_instances
    }

    volumes {
      name = "cloudsql"

      cloud_sql_instance {
        instances = [google_sql_database_instance.ledger.connection_name]
      }
    }

    containers {
      image = var.api_image

      ports {
        container_port = 8080
      }

      env {
        name  = "KANI_API_ADDR"
        value = "0.0.0.0:8080"
      }

      env {
        name  = "KANI_LEDGER_MODE"
        value = "postgres"
      }

      env {
        name  = "ENV"
        value = "SANDBOX"
      }

      env {
        name  = "REAL_VALUE"
        value = "FALSE"
      }

      env {
        name  = "REDEEMABLE"
        value = "FALSE"
      }

      env {
        name  = "KANI_REQUIRE_CONFIGURED_SANDBOX_API_KEYS"
        value = "TRUE"
      }

      env {
        name = "DATABASE_URL"

        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = google_secret_manager_secret_version.database_url.version
          }
        }
      }

      dynamic "env" {
        for_each = local.sandbox_api_keys

        content {
          name = env.value.env_name

          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.sandbox_api_key[env.key].secret_id
              version = google_secret_manager_secret_version.sandbox_api_key[env.key].version
            }
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 12

        http_get {
          path = "/health"
          port = 8080
        }
      }
    }
  }

  depends_on = [
    google_project_service.required,
    google_secret_manager_secret_iam_member.api_database_url,
    google_secret_manager_secret_iam_member.api_sandbox_api_key
  ]
}

resource "google_cloud_run_v2_job" "validator" {
  name                = "${var.name_prefix}-validator"
  location            = var.region
  deletion_protection = var.deletion_protection
  labels              = local.labels

  template {
    task_count  = 1
    parallelism = 1

    template {
      service_account = google_service_account.validator.email
      max_retries     = 0
      timeout         = "${var.validator_job_timeout_seconds}s"

      volumes {
        name = "cloudsql"

        cloud_sql_instance {
          instances = [google_sql_database_instance.ledger.connection_name]
        }
      }

      containers {
        image   = var.api_image
        command = ["kani-node"]

        env {
          name  = "KANI_VALIDATOR_RUN_MODE"
          value = "sweep"
        }

        env {
          name  = "KANI_VALIDATOR_IDS"
          value = join(",", var.validator_ids)
        }

        env {
          name  = "KANI_MAX_TXS_PER_BLOCK"
          value = tostring(var.validator_job_max_transactions_per_block)
        }

        env {
          name  = "ENV"
          value = "SANDBOX"
        }

        env {
          name  = "REAL_VALUE"
          value = "FALSE"
        }

        env {
          name  = "REDEEMABLE"
          value = "FALSE"
        }

        env {
          name = "DATABASE_URL"

          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.database_url.secret_id
              version = google_secret_manager_secret_version.database_url.version
            }
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.required,
    google_secret_manager_secret_iam_member.validator_database_url
  ]
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_run_validator" {
  count = var.validator_scheduler_enabled ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.validator.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler[0].email}"
}

resource "google_service_account_iam_member" "scheduler_can_act_as_validator" {
  count = var.validator_scheduler_enabled ? 1 : 0

  service_account_id = google_service_account.validator.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.scheduler[0].email}"
}

resource "google_cloud_scheduler_job" "validator" {
  count = var.validator_scheduler_enabled ? 1 : 0

  project          = var.project_id
  region           = var.region
  name             = "${var.name_prefix}-validator-schedule"
  description      = "Runs the KANI sandbox validator sweep job on a lean no-GKE cadence."
  schedule         = var.validator_schedule
  time_zone        = var.validator_scheduler_time_zone
  attempt_deadline = "${var.validator_scheduler_attempt_deadline_seconds}s"
  paused           = var.validator_scheduler_paused

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.validator.name}:run"
    body        = base64encode("{}")

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.scheduler[0].email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  retry_config {
    retry_count          = 1
    min_backoff_duration = "30s"
    max_backoff_duration = "300s"
    max_retry_duration   = "300s"
    max_doublings        = 1
  }

  depends_on = [
    google_project_service.required,
    google_cloud_run_v2_job_iam_member.scheduler_run_validator,
    google_service_account_iam_member.scheduler_can_act_as_validator
  ]
}

resource "google_pubsub_topic" "budget_notifications" {
  count = local.budget_brake_enabled ? 1 : 0

  project = var.project_id
  name    = "${var.name_prefix}-budget-notifications"
  labels  = local.labels

  depends_on = [google_project_service.required]
}

resource "google_cloud_run_v2_service" "cost_guard" {
  count = local.budget_brake_enabled ? 1 : 0

  name                = "${var.name_prefix}-cost-guard"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection
  labels              = local.labels

  template {
    service_account = google_service_account.cost_guard[0].email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image   = var.api_image
      command = ["kani-cost-guard"]

      ports {
        container_port = 8080
      }

      env {
        name  = "ENV"
        value = "SANDBOX"
      }

      env {
        name  = "REAL_VALUE"
        value = "FALSE"
      }

      env {
        name  = "REDEEMABLE"
        value = "FALSE"
      }

      env {
        name  = "KANI_SCHEDULER_PROJECT"
        value = var.project_id
      }

      env {
        name  = "KANI_SCHEDULER_REGION"
        value = var.region
      }

      env {
        name  = "KANI_SCHEDULER_JOB"
        value = google_cloud_scheduler_job.validator[0].name
      }

      env {
        name  = "KANI_BUDGET_ID"
        value = google_billing_budget.sandbox[0].name
      }

      env {
        name  = "KANI_BUDGET_BRAKE_THRESHOLD"
        value = tostring(var.budget_brake_threshold)
      }

      env {
        name  = "KANI_COST_GUARD_DRY_RUN"
        value = tostring(var.budget_brake_dry_run)
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        initial_delay_seconds = 2
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 6

        http_get {
          path = "/health"
          port = 8080
        }
      }
    }
  }

  depends_on = [
    google_project_service.required,
    google_cloud_scheduler_job.validator,
    google_billing_budget.sandbox
  ]
}

resource "google_cloud_run_v2_service_iam_member" "cost_guard_pubsub_invoker" {
  count = local.budget_brake_enabled ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.cost_guard[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cost_guard[0].email}"
}

resource "google_project_iam_member" "cost_guard_scheduler_admin" {
  count = local.budget_brake_enabled ? 1 : 0

  project = var.project_id
  role    = "roles/cloudscheduler.admin"
  member  = "serviceAccount:${google_service_account.cost_guard[0].email}"
}

resource "google_service_account_iam_member" "pubsub_can_mint_cost_guard_token" {
  count = local.budget_brake_enabled ? 1 : 0

  service_account_id = google_service_account.cost_guard[0].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  depends_on = [google_project_service.required]
}

resource "google_pubsub_subscription" "budget_notifications_push" {
  count = local.budget_brake_enabled ? 1 : 0

  project              = var.project_id
  name                 = "${var.name_prefix}-budget-brake-push"
  topic                = google_pubsub_topic.budget_notifications[0].id
  ack_deadline_seconds = 30
  labels               = local.labels

  expiration_policy {
    ttl = ""
  }

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.cost_guard[0].uri}/v1/budget-events"

    oidc_token {
      service_account_email = google_service_account.cost_guard[0].email
      audience              = google_cloud_run_v2_service.cost_guard[0].uri
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.cost_guard_pubsub_invoker,
    google_service_account_iam_member.pubsub_can_mint_cost_guard_token
  ]
}

resource "google_monitoring_notification_channel" "budget_email" {
  for_each = local.budget_guardrail_enabled ? local.budget_alert_emails : toset([])

  project      = var.project_id
  display_name = "${var.name_prefix} budget alert ${each.value}"
  description  = "Explicit email recipient for KANI sandbox budget threshold alerts."
  type         = "email"
  enabled      = true

  labels = {
    email_address = each.value
  }

  user_labels = local.labels

  depends_on = [google_project_service.required]
}

resource "google_billing_budget" "sandbox" {
  count = local.budget_guardrail_enabled ? 1 : 0

  billing_account = local.budget_billing_account_id
  display_name    = "${var.name_prefix}-monthly-budget"

  amount {
    specified_amount {
      units = tostring(var.budget_amount_units)
    }
  }

  budget_filter {
    calendar_period        = "MONTH"
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
    projects               = ["projects/${data.google_project.current.number}"]
  }

  dynamic "threshold_rules" {
    for_each = var.budget_alert_thresholds

    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  dynamic "all_updates_rule" {
    for_each = length(google_monitoring_notification_channel.budget_email) > 0 || local.budget_pubsub_topic_attachment_enabled ? [1] : []

    content {
      pubsub_topic   = local.budget_pubsub_topic_attachment_enabled ? google_pubsub_topic.budget_notifications[0].id : null
      schema_version = local.budget_pubsub_topic_attachment_enabled ? "1.0" : null

      monitoring_notification_channels = [
        for channel in google_monitoring_notification_channel.budget_email : channel.name
      ]
      disable_default_iam_recipients  = false
      enable_project_level_recipients = true
    }
  }
}

resource "google_monitoring_alert_policy" "phase2_log_alert" {
  for_each = local.monitoring_log_alerts

  project      = var.project_id
  display_name = each.value.display_name
  combiner     = "OR"
  enabled      = true

  notification_channels = local.monitoring_alert_notification_channels

  conditions {
    display_name = each.value.condition_display_name

    condition_matched_log {
      filter = each.value.filter
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = var.monitoring_alert_log_notification_rate_limit
    }
  }

  documentation {
    content   = each.value.documentation
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.required]
}
