locals {
  labels = merge(
    {
      app         = "kani"
      environment = "sandbox"
      phase       = "phase-5b"
    },
    var.labels
  )

  validator_service_account_email = "${var.name_prefix}-validator@${var.project_id}.iam.gserviceaccount.com"
  workload_identity_member        = "serviceAccount:${var.project_id}.svc.id.goog[${var.gke_workload_identity_namespace}/${var.gke_workload_identity_ksa}]"
}

resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "gke_node" {
  account_id   = "${var.name_prefix}-gke-node"
  display_name = "KANI sandbox GKE node"

  depends_on = [google_project_service.container]
}

resource "google_project_iam_member" "gke_node_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_service_account_iam_member" "validator_workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.validator_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_member

  depends_on = [google_container_cluster.validators]
}

resource "google_container_cluster" "validators" {
  name                     = var.gke_cluster_name
  location                 = var.gke_location
  deletion_protection      = var.deletion_protection
  enable_shielded_nodes    = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  remove_default_node_pool = true
  resource_labels          = local.labels

  addons_config {
    http_load_balancing {
      disabled = true
    }

    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  ip_allocation_policy {}

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  release_channel {
    channel = var.gke_release_channel
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "validators" {
  name       = "${var.name_prefix}-validators"
  location   = google_container_cluster.validators.location
  cluster    = google_container_cluster.validators.name
  node_count = var.gke_node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    disk_size_gb    = var.gke_node_disk_size_gb
    disk_type       = var.gke_node_disk_type
    image_type      = "COS_CONTAINERD"
    labels          = local.labels
    machine_type    = var.gke_node_machine_type
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    service_account = google_service_account.gke_node.email
    spot            = var.gke_node_spot
    tags            = ["kani-sandbox-validator"]

    shielded_instance_config {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  depends_on = [
    google_project_iam_member.gke_node_artifact_reader,
    google_project_iam_member.gke_node_logging_writer,
    google_project_iam_member.gke_node_monitoring_metric_writer,
    google_project_iam_member.gke_node_monitoring_viewer
  ]
}
