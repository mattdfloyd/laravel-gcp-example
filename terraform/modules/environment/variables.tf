# ── Required ─────────────────────────────────────

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "app_name" {
  type = string
}

variable "environment" {
  description = "Environment name (production, staging, pr-42)"
  type        = string
}

variable "image" {
  description = "Container image with tag — set by CI/CD"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

# ── Cloud SQL ────────────────────────────────────

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "db_version" {
  type    = string
  default = "POSTGRES_16"
}

variable "db_storage_gb" {
  type    = number
  default = 10
}

variable "db_availability_type" {
  type    = string
  default = "ZONAL"
}

variable "db_backup_enabled" {
  type    = bool
  default = false
}

variable "db_deletion_protection" {
  type    = bool
  default = true
}

# ── Redis ────────────────────────────────────────

variable "redis_size_gb" {
  type    = number
  default = 1
}

variable "redis_tier" {
  type    = string
  default = "BASIC"
}

# ── Cloud Run: Web ───────────────────────────────

variable "web_cpu" {
  type    = string
  default = "1"
}

variable "web_memory" {
  type    = string
  default = "512Mi"
}

variable "web_min_instances" {
  type    = number
  default = 0
}

variable "web_max_instances" {
  type    = number
  default = 10
}

variable "web_concurrency" {
  type    = number
  default = 250
}

# ── Cloud Run: Worker ────────────────────────────

variable "worker_cpu" {
  type    = string
  default = "1"
}

variable "worker_memory" {
  type    = string
  default = "512Mi"
}

variable "worker_min_instances" {
  type    = number
  default = 1
}

variable "worker_max_instances" {
  type    = number
  default = 3
}

# ── Networking ───────────────────────────────────

variable "vpc_connector_cidr" {
  description = "Unique /28 CIDR per environment"
  type        = string
  default     = "10.8.0.0/28"
}

# ── Domain ───────────────────────────────────────

variable "domain" {
  description = "Custom domain (empty = Cloud Run default URL)"
  type        = string
  default     = ""
}

# ── Storage ──────────────────────────────────────

variable "storage_force_destroy" {
  type    = bool
  default = false
}

variable "storage_versioning" {
  type    = bool
  default = false
}

variable "storage_lifecycle_age" {
  description = "Auto-delete objects after N days (0 = disabled)"
  type        = number
  default     = 0
}

# ── Shared Infrastructure (for preview envs) ────
# Set these to reuse staging's Cloud SQL and Redis
# instead of creating new instances per environment.

variable "shared_db_instance" {
  description = "Existing Cloud SQL instance name to share (null = create new)"
  type        = string
  default     = null
}

variable "shared_redis_host" {
  description = "Existing Redis IP to share (null = create new)"
  type        = string
  default     = null
}

# ── Extra env vars ───────────────────────────────

variable "extra_env_vars" {
  description = "Additional env vars merged into all services"
  type        = map(string)
  default     = {}
}
