terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
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