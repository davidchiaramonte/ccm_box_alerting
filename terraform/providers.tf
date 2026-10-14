###########################
# PROVIDER CONFIGURATIONS #
###########################

terraform {
  # Using local state on Cloudtop
  # backend "gcs" {
  #   bucket  = "ccm-toolkit-terraform-state"
  #   prefix  = "terraform/state-alert-test"
  # }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.22.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.22.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
