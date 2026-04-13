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
    prefix = "production"
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

module "environment" {
  source = "../../modules/environment"

  project_id  = var.project_id
  region      = var.region
  app_name    = "laravel-gcp-example"
  environment = "production"
  image       = var.image

  # Cloud SQL — HA, backups, protected
  db_tier                = "db-custom-2-8192"
  db_storage_gb          = 20
  db_availability_type   = "REGIONAL"
  db_backup_enabled      = true
  db_deletion_protection = true

  # Redis — HA
  redis_size_gb = 2
  redis_tier    = "STANDARD_HA"

  # Web — always warm
  web_cpu           = "2"
  web_memory        = "1Gi"
  web_min_instances = 1
  web_max_instances = 20

  # Worker
  worker_memory        = "1Gi"
  worker_min_instances = 1
  worker_max_instances = 5

  # Networking
  vpc_connector_cidr = "10.8.2.0/24"

  # Domain
  domain = "app.mattdfloyd.com"

  # Storage
  storage_versioning = true

  extra_env_vars = {
    APP_URL = "https://app.mattdfloyd.com"
  }
}

output "web_url"       { value = module.environment.web_url }
output "db_connection"  { value = module.environment.db_connection_name }
output "uploads_bucket" { value = module.environment.uploads_bucket }
output "dns_records"    { value = module.environment.domain_records }
