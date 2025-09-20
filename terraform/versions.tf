# =============================================================================
# TERRAFORM VERSION CONSTRAINTS
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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Uncomment and configure for production
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "gke/terraform.tfstate"
  # }
}
