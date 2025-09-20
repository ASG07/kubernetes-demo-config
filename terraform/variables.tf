# =============================================================================
# TERRAFORM VARIABLES DEFINITIONS
# =============================================================================

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty."
  }
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
      "europe-west1", "europe-west2", "europe-west3", "europe-west4", "europe-west6",
      "asia-east1", "asia-northeast1", "asia-southeast1", "australia-southeast1"
    ], var.region)
    error_message = "Region must be a valid GCP region."
  }
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "laravel-production"
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.cluster_name))
    error_message = "Cluster name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "min_nodes" {
  description = "Minimum number of nodes in the primary node pool"
  type        = number
  default     = 1
  validation {
    condition     = var.min_nodes >= 1 && var.min_nodes <= 10
    error_message = "Minimum nodes must be between 1 and 10."
  }
}

variable "max_nodes" {
  description = "Maximum number of nodes in the primary node pool"
  type        = number
  default     = 10
  validation {
    condition     = var.max_nodes >= 1 && var.max_nodes <= 100
    error_message = "Maximum nodes must be between 1 and 100."
  }
}

variable "enable_spot_nodes" {
  description = "Whether to create a spot instance node pool"
  type        = bool
  default     = true
}

variable "mysql_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-n1-standard-2"
}

variable "mysql_disk_size" {
  description = "Cloud SQL disk size in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.mysql_disk_size >= 10 && var.mysql_disk_size <= 65536
    error_message = "MySQL disk size must be between 10 and 65536 GB."
  }
}

variable "redis_memory_size" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
  validation {
    condition     = var.redis_memory_size >= 1 && var.redis_memory_size <= 300
    error_message = "Redis memory size must be between 1 and 300 GB."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = true
}

variable "authorized_networks" {
  description = "List of CIDR blocks allowed to access the cluster API server"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  ]
}
