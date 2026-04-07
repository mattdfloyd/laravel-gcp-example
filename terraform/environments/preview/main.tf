terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "laravel-gcp-example-tf-state"
    prefix = "preview"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "image" {
  type = string
}

variable "env_name" {
  type = string
}

variable "vpc_connector_cidr" {
  type    = string
  default = "10.8.100.0/28"
}

# Pull staging's DB and Redis info from its state
data "terraform_remote_state" "staging" {
  backend = "gcs"
  config = {
    bucket = "laravel-gcp-example-tf-state"
    prefix = "staging"
  }
}

module "environment" {
  source = "../../modules/environment"

  project_id  = var.project_id
  region      = var.region
  app_name    = "laravel-gcp-example"
  environment = var.env_name
  image       = var.image

  # Share staging's Cloud SQL and Redis — no new instances
  shared_db_instance = data.terraform_remote_state.staging.outputs.db_instance_name
  shared_redis_host  = data.terraform_remote_state.staging.outputs.redis_host

  # Cloud Run — bare minimum, scales to zero
  web_min_instances = 0
  web_max_instances = 1

  worker_min_instances = 0
  worker_max_instances = 1

  vpc_connector_cidr = var.vpc_connector_cidr

  # Ephemeral storage
  storage_force_destroy = true
  storage_lifecycle_age = 7
}

output "web_url" { value = module.environment.web_url }
