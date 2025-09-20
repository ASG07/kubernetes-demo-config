# =============================================================================
# TERRAFORM CONFIGURATION FOR PRODUCTION GKE CLUSTER
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.84"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "laravel-production"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "prod"
}

# =============================================================================
# PROVIDER CONFIGURATION
# =============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "google_client_config" "default" {}

data "google_container_engine_versions" "gke_version" {
  location = var.region
  version_prefix = "1.27."
}

# =============================================================================
# VPC AND NETWORKING
# =============================================================================

resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  description             = "VPC for ${var.cluster_name} cluster"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.11.0.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "10.12.0.0/16"
  }
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.cluster_name}-nat"
  router = google_compute_router.router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# =============================================================================
# GKE CLUSTER
# =============================================================================

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  # Networking configuration
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-ranges"
    services_secondary_range_name = "services-range"
  }

  # Security and access configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Master authorized networks (restrict access to cluster API server)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"  # Replace with your office/VPN IPs
      display_name = "All"
    }
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Add-ons and features
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Security
  enable_shielded_nodes = true
  network_policy {
    enabled = true
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"  # 3 AM
    }
  }

  # Resource labels
  resource_labels = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

# =============================================================================
# NODE POOLS
# =============================================================================

# Primary node pool for application workloads
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 2

  # Auto-scaling configuration
  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }

  # Node configuration
  node_config {
    preemptible  = false
    machine_type = "e2-standard-4"  # 4 vCPU, 16 GB RAM
    disk_type    = "pd-standard"
    disk_size_gb = 100

    # Google recommends custom service accounts with minimal permissions
    service_account = google_service_account.gke_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded VM features
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Labels and tags
    labels = {
      environment = var.environment
      node-pool   = "primary"
    }

    tags = ["${var.cluster_name}-node"]
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Spot instance node pool for non-critical workloads
resource "google_container_node_pool" "spot_nodes" {
  name       = "${var.cluster_name}-spot-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count = 0
    max_node_count = 5
  }

  node_config {
    preemptible  = true
    machine_type = "e2-standard-2"
    disk_type    = "pd-standard"
    disk_size_gb = 50

    service_account = google_service_account.gke_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      environment = var.environment
      node-pool   = "spot"
    }

    taint {
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    tags = ["${var.cluster_name}-spot-node"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# =============================================================================
# IAM AND SERVICE ACCOUNTS
# =============================================================================

resource "google_service_account" "gke_service_account" {
  account_id   = "${var.cluster_name}-gke-sa"
  display_name = "GKE Service Account for ${var.cluster_name}"
  description  = "Service account for GKE nodes"
}

resource "google_project_iam_member" "gke_service_account_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.objectViewer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

# =============================================================================
# CLOUD SQL (MySQL) FOR PRODUCTION DATABASE
# =============================================================================

resource "google_sql_database_instance" "mysql" {
  name             = "${var.cluster_name}-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region

  deletion_protection = true

  settings {
    tier              = "db-n1-standard-2"
    availability_type = "REGIONAL"  # High availability
    disk_type         = "PD_SSD"
    disk_size         = 20
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      location                       = var.region
      binary_log_enabled             = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      require_ssl     = true
    }

    database_flags {
      name  = "slow_query_log"
      value = "on"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "laravel" {
  name     = "laravel"
  instance = google_sql_database_instance.mysql.name
}

resource "google_sql_user" "laravel" {
  name     = "laravel"
  instance = google_sql_database_instance.mysql.name
  password = "your-secure-password-here"  # Use Google Secret Manager in production
}

# =============================================================================
# PRIVATE SERVICE NETWORKING FOR CLOUD SQL
# =============================================================================

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.cluster_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# =============================================================================
# REDIS INSTANCE (MEMORYSTORE)
# =============================================================================

resource "google_redis_instance" "redis" {
  name           = "${var.cluster_name}-redis"
  memory_size_gb = 1
  region         = var.region

  authorized_network = google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  redis_version = "REDIS_6_X"
  display_name  = "Laravel Redis Cache"

  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 3
        minutes = 0
      }
    }
  }

  labels = {
    environment = var.environment
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "mysql_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.mysql.connection_name
}

output "mysql_private_ip" {
  description = "Cloud SQL private IP"
  value       = google_sql_database_instance.mysql.private_ip_address
}

output "redis_host" {
  description = "Redis host"
  value       = google_redis_instance.redis.host
}

output "redis_port" {
  description = "Redis port"
  value       = google_redis_instance.redis.port
}
