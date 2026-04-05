resource "google_storage_bucket" "uploads" {
  name     = "${local.prefix}-uploads"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  force_destroy               = var.storage_force_destroy

  versioning {
    enabled = var.storage_versioning
  }

  dynamic "lifecycle_rule" {
    for_each = var.storage_lifecycle_age > 0 ? [1] : []
    content {
      condition { age = var.storage_lifecycle_age }
      action { type = "Delete" }
    }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "PUT", "POST"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_iam_member" "uploads_writer" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}
