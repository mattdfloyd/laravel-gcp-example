# ── Web Service ──────────────────────────────────

resource "google_cloud_run_v2_service" "web" {
  name     = "${local.prefix}-web"
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = var.web_min_instances
      max_instance_count = var.web_max_instances
    }

    max_instance_request_concurrency = var.web_concurrency

    vpc_access {
      network_interfaces {
        network    = "default"
        subnetwork = google_compute_subnetwork.run.name
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [local.db_connection]
      }
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.web_cpu
          memory = var.web_memory
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      dynamic "env" {
        for_each = local.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_version.app_key,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.app_key,
    google_secret_manager_secret_iam_member.db_password,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "web_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.web.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Worker Service ───────────────────────────────

resource "google_cloud_run_v2_service" "worker" {
  name     = "${local.prefix}-worker"
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    scaling {
      min_instance_count = var.worker_min_instances
      max_instance_count = var.worker_max_instances
    }

    # CPU is always allocated so the worker can poll Redis
    # (without this, Cloud Run throttles CPU between requests)
    service_account = null

    vpc_access {
      network_interfaces {
        network    = "default"
        subnetwork = google_compute_subnetwork.run.name
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [local.db_connection]
      }
    }

    containers {
      image   = var.image
      command = ["/app/worker-entrypoint.sh"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.worker_cpu
          memory = var.worker_memory
        }
        cpu_idle = false # Keep CPU allocated even without requests
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      dynamic "env" {
        for_each = local.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_version.app_key,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.app_key,
    google_secret_manager_secret_iam_member.db_password,
  ]
}

# ── Migration Job ────────────────────────────────

resource "google_cloud_run_v2_job" "migrate" {
  name     = "${local.prefix}-migrate"
  project  = var.project_id
  location = var.region

  template {
    template {
      vpc_access {
        network_interfaces {
          network    = "default"
          subnetwork = google_compute_subnetwork.run.name
        }
        egress = "PRIVATE_RANGES_ONLY"
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [local.db_connection]
        }
      }

      containers {
        image   = var.image
        command = ["php"]
        args    = ["artisan", "migrate", "--force"]

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }

        dynamic "env" {
          for_each = local.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.secret_vars
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }

      max_retries = 1
      timeout     = "300s"
    }
  }

  depends_on = [
    google_secret_manager_secret_version.app_key,
    google_secret_manager_secret_version.db_password,
  ]
}

# ── Scheduler Job ────────────────────────────────

resource "google_cloud_run_v2_job" "scheduler" {
  name     = "${local.prefix}-scheduler"
  project  = var.project_id
  location = var.region

  template {
    template {
      vpc_access {
        network_interfaces {
          network    = "default"
          subnetwork = google_compute_subnetwork.run.name
        }
        egress = "PRIVATE_RANGES_ONLY"
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [local.db_connection]
        }
      }

      containers {
        image   = var.image
        command = ["php"]
        args    = ["artisan", "schedule:run"]

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }

        dynamic "env" {
          for_each = local.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.secret_vars
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }

      max_retries = 0
      timeout     = "120s"
    }
  }

  depends_on = [
    google_secret_manager_secret_version.app_key,
    google_secret_manager_secret_version.db_password,
  ]
}

# ── Cloud Scheduler (triggers schedule:run every minute) ──

resource "google_service_account" "scheduler" {
  account_id   = "${local.sa_prefix}-sched"
  display_name = "Cloud Scheduler for ${local.prefix}"
  project      = var.project_id
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoke" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.scheduler.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "cron" {
  name      = "${local.prefix}-cron"
  project   = var.project_id
  region    = var.region
  schedule  = "* * * * *"
  time_zone = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.scheduler.name}:run"
    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# ── Custom Domain (simple mapping) ───────────────
# Cloud Run handles HTTPS and managed certs automatically.
# Upgrade to a Global HTTPS Load Balancer later if you
# need CDN or Cloud Armor.

resource "google_cloud_run_domain_mapping" "web" {
  count    = var.domain != "" ? 1 : 0
  name     = var.domain
  location = var.region
  project  = var.project_id

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.web.name
  }
}
