resource "google_compute_network" "vpc_network" {
  project                 = var.gcp_project
  name                    = var.project_name
  auto_create_subnetworks = false
  mtu                     = 1460
}
########         Public Subnetworks
resource "google_compute_subnetwork" "public-subnetwork-1" {
  name          = "${var.project_name}-public-subnetwork-1"
  region        = var.gcp_region
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = var.gcp_subnet_1_cidr
}
resource "google_compute_subnetwork" "public-subnetwork-2" {
  name          = "${var.project_name}-public-subnetwork-2"
  region        = var.gcp_region
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = var.gcp_subnet_2_cidr
}

########         Private Subnetworks
resource "google_compute_subnetwork" "private-subnetwork-1" {
  name                     = "${var.project_name}-private-subnetwork-1"
  region                   = var.gcp_region
  network                  = google_compute_network.vpc_network.id
  ip_cidr_range            = var.gcp_subnet_3_cidr
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private-subnetwork-2" {
  name                     = "${var.project_name}-private-subnetwork-2"
  region                   = var.gcp_region
  network                  = google_compute_network.vpc_network.id
  ip_cidr_range            = var.gcp_subnet_4_cidr
  private_ip_google_access = true
}