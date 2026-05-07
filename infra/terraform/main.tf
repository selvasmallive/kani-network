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

  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
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
