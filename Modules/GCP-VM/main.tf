resource "google_compute_firewall" "allow_ingress" {
  name    = "${var.name}-allow-ingress"
  network = var.network
  project = var.gcp_project

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
  allow {
    protocol = "icmp"
  }


  source_ranges = var.ssh_source_ranges
  target_tags   = var.network_tags
}

resource "google_compute_firewall" "allow_egress" {
  name      = "${var.name}-allow-egress"
  network   = var.network
  project   = var.gcp_project
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = var.network_tags
}

resource "google_compute_instance" "vm" {
  name         = var.name
  project      = var.gcp_project
  zone         = var.gcp_zone
  machine_type = var.machine_type

  tags   = var.network_tags
  labels = var.labels

  boot_disk {
    initialize_params {
      image = var.boot_image
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []

      content {}
    }
  }
}