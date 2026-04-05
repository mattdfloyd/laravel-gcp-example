# Only created if not sharing
resource "google_redis_instance" "main" {
  count = local.owns_redis ? 1 : 0

  name           = "${local.prefix}-redis"
  project        = var.project_id
  region         = var.region
  tier           = var.redis_tier
  memory_size_gb = var.redis_size_gb
  redis_version  = "REDIS_7_2"

  authorized_network = "projects/${var.project_id}/global/networks/default"

  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 5
        minutes = 0
      }
    }
  }
}
