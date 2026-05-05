locals {
  labels = merge(
    {
      app         = "kani"
      environment = "sandbox"
      phase       = "phase-2"
    },
    var.labels
  )

  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com"
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "kani" {
  name                    = "${var.name_prefix}-network"
  auto_create_subnetworks = false

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "kani" {
  name                     = "${var.name_prefix}-subnet"
  ip_cidr_range            = var.network_cidr
  region                   = var.region
  network                  = google_compute_network.kani.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_artifact_registry_repository" "kani" {
  location      = var.region
  repository_id = "kani"
  description   = "KANI sandbox container images"
  format        = "DOCKER"
  labels        = local.labels

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket" "block_archive" {
  name                        = "${var.project_id}-${var.name_prefix}-block-archive"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required]
}

resource "google_kms_key_ring" "kani" {
  name     = var.name_prefix
  location = var.region

  depends_on = [google_project_service.required]
}

resource "google_kms_crypto_key" "validator_signing" {
  name            = "validator-signing-sandbox"
  key_ring        = google_kms_key_ring.kani.id
  rotation_period = "7776000s"

  labels = local.labels
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

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
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
  special = true
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
  secret_data = var.database_url
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

resource "google_project_iam_member" "validator_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.validator.email}"
}

resource "google_service_account_iam_member" "validator_workload_identity" {
  service_account_id = google_service_account.validator.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kani-system/kani-validator]"
}

resource "google_cloud_run_v2_service" "api" {
  name     = "${var.name_prefix}-api"
  location = var.region
  ingress  = var.cloud_run_ingress
  labels   = local.labels

  template {
    service_account = google_service_account.api.email

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
            version = "latest"
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

resource "google_container_cluster" "validators" {
  name                     = "${var.name_prefix}-validators"
  location                 = var.gke_location
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection
  network                  = google_compute_network.kani.id
  subnetwork               = google_compute_subnetwork.kani.id
  networking_mode          = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [google_project_service.required]
}

resource "google_container_node_pool" "validators" {
  name       = "validators"
  location   = google_container_cluster.validators.location
  cluster    = google_container_cluster.validators.name
  node_count = var.gke_node_count

  node_config {
    machine_type    = var.gke_machine_type
    service_account = google_service_account.validator.email
    labels          = local.labels

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
