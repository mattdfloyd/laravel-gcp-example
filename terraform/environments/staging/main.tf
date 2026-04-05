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
    prefix = "staging"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" { type = string }
variable "region" { type = string; default = "us-east1" }
variable "image" { type = string }

module "environment" {
  source = "../../modules/environment"

  project_id  = var.project_id
  region      = var.region
  app_name    = "my-app"
  environment = "staging"
  image       = var.image

  # Cloud SQL — small, no HA, no backups
  db_tier                = "db-f1-micro"
  db_availability_type   = "ZONAL"
  db_backup_enabled      = false
  db_deletion_protection = false

  # Redis
  redis_size_gb = 1
  redis_tier    = "BASIC"

  # Web — scales to zero
  web_min_instances = 0
  web_max_instances = 3

  # Worker
  worker_min_instances = 1
  worker_max_instances = 1

  # Networking — different CIDR
  vpc_connector_cidr = "10.8.1.0/28"

  # Storage — destroyable
  storage_force_destroy = true

  extra_env_vars = {
    APP_URL = "https://staging.example.com"
  }
}

output "web_url"          { value = module.environment.web_url }
output "db_connection"     { value = module.environment.db_connection_name }
output "db_instance_name"  { value = module.environment.db_instance_name }
output "redis_host"        { value = module.environment.redis_host }
output "uploads_bucket"    { value = module.environment.uploads_bucket }
