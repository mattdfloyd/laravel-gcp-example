terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  prefix        = "${var.app_name}-${var.environment}"
  sa_prefix     = substr(local.prefix, 0, min(length(local.prefix), 24))
  vpc_prefix    = substr(local.prefix, 0, min(length(local.prefix), 20))
  is_production = var.environment == "production"
  owns_db       = var.shared_db_instance == null
  owns_redis    = var.shared_redis_host == null

  # Cloud SQL connection string — own instance or shared
  db_instance_name = local.owns_db ? google_sql_database_instance.main[0].name : var.shared_db_instance
  db_connection    = "${var.project_id}:${var.region}:${local.db_instance_name}"

  # Redis host — own instance or shared
  redis_host = local.owns_redis ? google_redis_instance.main[0].host : var.shared_redis_host

  # Derive app config from environment name
  env_vars = merge({
    APP_ENV          = local.is_production ? "production" : "staging"
    APP_DEBUG        = local.is_production ? "false" : "true"
    LOG_CHANNEL      = "stderr"
    LOG_LEVEL        = local.is_production ? "error" : "debug"
    LOG_STDERR_FORMATTER = "Monolog\\Formatter\\JsonFormatter"
    DB_CONNECTION    = "pgsql"
    DB_SOCKET        = "/cloudsql/${local.db_connection}"
    DB_DATABASE      = google_sql_database.main.name
    DB_USERNAME      = google_sql_user.main.name
    REDIS_HOST       = local.redis_host
    REDIS_PORT       = "6379"
    CACHE_STORE      = "redis"
    SESSION_DRIVER   = "redis"
    QUEUE_CONNECTION = "redis"
    FILESYSTEM_DISK  = "gcs"
    GOOGLE_CLOUD_STORAGE_BUCKET = google_storage_bucket.uploads.name
  }, var.extra_env_vars)

  secret_vars = {
    APP_KEY     = google_secret_manager_secret.app_key.secret_id
    DB_PASSWORD = google_secret_manager_secret.db_password.secret_id
  }
}

# ── Secrets ──────────────────────────────────────

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "random_id" "app_key" {
  byte_length = 32
}

resource "google_secret_manager_secret" "app_key" {
  secret_id = "${local.prefix}-app-key"
  project   = var.project_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_key" {
  secret      = google_secret_manager_secret.app_key.id
  secret_data = "base64:${random_id.app_key.b64_std}"
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${local.prefix}-db-password"
  project   = var.project_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

# Grant Cloud Run's default SA access to secrets
resource "google_secret_manager_secret_iam_member" "app_key" {
  secret_id = google_secret_manager_secret.app_key.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_secret_manager_secret_iam_member" "db_password" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}
