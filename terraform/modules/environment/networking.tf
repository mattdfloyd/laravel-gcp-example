# Cloud Run needs this to reach Memorystore Redis
resource "google_vpc_access_connector" "main" {
  name          = "${local.vpc_prefix}-conn"
  project       = var.project_id
  region        = var.region
  ip_cidr_range = var.vpc_connector_cidr
  network       = "default"
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}
