# Cloud Run uses Direct VPC Egress to reach Memorystore Redis.
# This creates a subnet instead of a VPC Access Connector —
# no extra VMs to provision, cheaper, and more reliable.
resource "google_compute_subnetwork" "run" {
  name          = "${local.prefix}-run"
  project       = var.project_id
  region        = var.region
  network       = "projects/${var.project_id}/global/networks/default"
  ip_cidr_range = var.vpc_connector_cidr
}
