# Instance — only created if not sharing
resource "google_sql_database_instance" "main" {
  count = local.owns_db ? 1 : 0

  name                = "${local.prefix}-db"
  project             = var.project_id
  region              = var.region
  database_version    = var.db_version
  deletion_protection = var.db_deletion_protection

  settings {
    tier              = var.db_tier
    availability_type = var.db_availability_type
    edition           = "ENTERPRISE"
    disk_autoresize   = true
    disk_size         = var.db_storage_gb
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled = false
    }

    dynamic "backup_configuration" {
      for_each = var.db_backup_enabled ? [1] : []
      content {
        enabled                        = true
        start_time                     = "03:00"
        point_in_time_recovery_enabled = true
        transaction_log_retention_days = 7
        backup_retention_settings {
          retained_backups = 14
        }
      }
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }

    database_flags {
      name  = "max_connections"
      value = var.db_tier == "db-f1-micro" ? "50" : "200"
    }
  }
}

# Database — always created (own instance or shared)
# Each env gets its own database for isolation
resource "google_sql_database" "main" {
  name     = local.owns_db ? "laravel" : "${var.environment}-laravel"
  instance = local.db_instance_name
  project  = var.project_id
}

# User — always created with a unique password
resource "google_sql_user" "main" {
  name     = local.owns_db ? "laravel" : "${var.environment}-laravel"
  instance = local.db_instance_name
  password = random_password.db.result
  project  = var.project_id
}
