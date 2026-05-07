terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "main" {
  name                    = "ls-platform-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "ls-platform-subnet"
  ip_cidr_range = "10.10.0.0/20"
  region        = var.region
  network       = google_compute_network.main.id
}

resource "google_container_cluster" "main" {
  name     = "ls-platform-gke"
  location = var.zone

  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.main.name

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  logging_service    = "none"
  monitoring_service = "none"

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "main" {
  name     = "primary-node-pool"
  cluster  = google_container_cluster.main.name
  location = var.zone

  initial_node_count = 2

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 40
    disk_type    = "pd-balanced"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = "prod"
      platform    = "ls-platform"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
resource "random_password" "academy_db_password" {
  length  = 24
  special = false
}

resource "google_sql_database_instance" "academy" {
  name             = "academy-postgres"
  database_version = "POSTGRES_16"
  region           = var.region

  deletion_protection = true

  settings {
    tier              = "db-f1-micro"
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = 10
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "07:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }
}

resource "google_sql_database" "academy" {
  name     = "academy"
  instance = google_sql_database_instance.academy.name
}

resource "google_sql_user" "academy" {
  name     = "academy_user"
  instance = google_sql_database_instance.academy.name
  password = random_password.academy_db_password.result
}
resource "google_compute_address" "traefik" {
  name   = "traefik-ip"
  region = var.region
}

resource "google_service_account" "academy_app" {
  account_id   = "academy-app"
  display_name = "Academy App"
}

resource "google_project_iam_member" "academy_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.academy_app.email}"
}

resource "google_service_account_iam_member" "academy_workload_identity" {
  service_account_id = google_service_account.academy_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[academy/academy-app]"
}

resource "google_service_account" "external_secrets" {
  account_id   = "external-secrets"
  display_name = "External Secrets Operator for LS-Platform"
}

resource "google_project_iam_member" "external_secrets_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

resource "google_service_account_iam_member" "external_secrets_workload_identity" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

resource "google_secret_manager_secret" "academy_db_password" {
  secret_id = "academy-db-password"

  replication {
    auto {}
  }
}