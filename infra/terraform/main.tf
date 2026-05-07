locals {
  labels = merge(
    {
      app         = "kani"
      environment = "sandbox"
      phase       = "phase-2"
    },
    var.labels
  )

  cloud_build_runtime_service_account = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
  budget_billing_account_id           = replace(trimspace(nonsensitive(var.budget_billing_account_id)), "billingAccounts/", "")
  budget_guardrail_enabled            = var.budget_guardrail_enabled && local.budget_billing_account_id != ""
  budget_alert_emails                 = toset([for email in var.budget_alert_emails : trimspace(email) if trimspace(email) != ""])

  required_services = toset([
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com"
  ])

  database_url = "postgres://kani:${urlencode(random_password.database_user.result)}@localhost/kani?host=/cloudsql/${google_sql_database_instance.ledger.connection_name}"
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
      point_in_time_recovery_enabled = var.cloud_sql_point_in_time_recovery_enabled
    }

    ip_configuration {
      ipv4_enabled = true
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

resource "google_secret_manager_secret_iam_member" "api_database_url" {
  secret_id = google_secret_manager_secret.database_url.id
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
    google_secret_manager_secret_iam_member.api_database_url
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
    for_each = length(google_monitoring_notification_channel.budget_email) > 0 ? [1] : []

    content {
      monitoring_notification_channels = [
        for channel in google_monitoring_notification_channel.budget_email : channel.name
      ]
      disable_default_iam_recipients  = false
      enable_project_level_recipients = true
    }
  }
}
