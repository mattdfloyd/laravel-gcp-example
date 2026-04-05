terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "my-app-terraform-state"
    prefix = "global"
  }
}

variable "project_id" {
  type    = string
  default = "my-project"
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "app_name" {
  type    = string
  default = "my-app"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Enable APIs ─────────────────────────────────

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "vpcaccess.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])

  project = var.project_id
  service = each.key

  disable_dependent_services = false
  disable_on_destroy         = false
}

# ── Artifact Registry (shared across envs) ──────

resource "google_artifact_registry_repository" "app" {
  repository_id = "${var.app_name}-repo"
  location      = var.region
  format        = "DOCKER"
  project       = var.project_id

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 20
    }
  }

  depends_on = [google_project_service.apis["artifactregistry.googleapis.com"]]
}

# ── Terraform State Bucket ──────────────────────
# Create this manually first:
#   gsutil mb -p my-project -l us-east1 gs://my-app-terraform-state
#   gsutil versioning set on gs://my-app-terraform-state

# ── Outputs ─────────────────────────────────────

output "artifact_registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}
