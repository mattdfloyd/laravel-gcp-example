output "web_url" {
  value = google_cloud_run_v2_service.web.uri
}

output "db_connection_name" {
  value = local.db_connection
}

output "db_instance_name" {
  description = "Cloud SQL instance name (for sharing with preview envs)"
  value       = local.db_instance_name
}

output "redis_host" {
  description = "Redis IP (for sharing with preview envs)"
  value       = local.redis_host
}

output "uploads_bucket" {
  value = google_storage_bucket.uploads.name
}

output "web_service_name" {
  value = google_cloud_run_v2_service.web.name
}

output "worker_service_name" {
  value = google_cloud_run_v2_service.worker.name
}

output "migrate_job_name" {
  value = google_cloud_run_v2_job.migrate.name
}

output "domain_records" {
  description = "DNS records to create (only if domain is set)"
  value       = var.domain != "" ? google_cloud_run_domain_mapping.web[0].status[0].resource_records : []
}
