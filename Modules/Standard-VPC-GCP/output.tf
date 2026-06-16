# ------------------------------------------------------------
# VPC Outputs
# ------------------------------------------------------------

output "vpc_id" {
  description = "ID of the GCP VPC network"
  value       = google_compute_network.vpc_network.id
}

output "vpc_name" {
  description = "Name of the GCP VPC network"
  value       = google_compute_network.vpc_network.name
}

output "vpc_self_link" {
  description = "Self link of the GCP VPC network"
  value       = google_compute_network.vpc_network.self_link
}

output "vpc_project" {
  description = "Project where the GCP VPC network was created"
  value       = google_compute_network.vpc_network.project
}

output "vpc_mtu" {
  description = "MTU of the GCP VPC network"
  value       = google_compute_network.vpc_network.mtu
}

output "vpc_auto_create_subnetworks" {
  description = "Whether auto subnet creation is enabled"
  value       = google_compute_network.vpc_network.auto_create_subnetworks
}

# ------------------------------------------------------------
# Public Subnetwork 1 Outputs
# ------------------------------------------------------------

output "public_subnetwork_1_id" {
  description = "ID of public subnetwork 1"
  value       = google_compute_subnetwork.public-subnetwork-1.id
}

output "public_subnetwork_1_name" {
  description = "Name of public subnetwork 1"
  value       = google_compute_subnetwork.public-subnetwork-1.name
}

output "public_subnetwork_1_self_link" {
  description = "Self link of public subnetwork 1"
  value       = google_compute_subnetwork.public-subnetwork-1.self_link
}

output "public_subnetwork_1_cidr" {
  description = "CIDR range of public subnetwork 1"
  value       = google_compute_subnetwork.public-subnetwork-1.ip_cidr_range
}

output "public_subnetwork_1_region" {
  description = "Region of public subnetwork 1"
  value       = google_compute_subnetwork.public-subnetwork-1.region
}

output "public_subnetwork_1_gateway_address" {
  description = "Gateway address of public subnetwork 1"
  value       = google_compute_subnetwork.public-subnetwork-1.gateway_address
}

# ------------------------------------------------------------
# Public Subnetwork 2 Outputs
# ------------------------------------------------------------

output "public_subnetwork_2_id" {
  description = "ID of public subnetwork 2"
  value       = google_compute_subnetwork.public-subnetwork-2.id
}

output "public_subnetwork_2_name" {
  description = "Name of public subnetwork 2"
  value       = google_compute_subnetwork.public-subnetwork-2.name
}

output "public_subnetwork_2_self_link" {
  description = "Self link of public subnetwork 2"
  value       = google_compute_subnetwork.public-subnetwork-2.self_link
}

output "public_subnetwork_2_cidr" {
  description = "CIDR range of public subnetwork 2"
  value       = google_compute_subnetwork.public-subnetwork-2.ip_cidr_range
}

output "public_subnetwork_2_region" {
  description = "Region of public subnetwork 2"
  value       = google_compute_subnetwork.public-subnetwork-2.region
}

output "public_subnetwork_2_gateway_address" {
  description = "Gateway address of public subnetwork 2"
  value       = google_compute_subnetwork.public-subnetwork-2.gateway_address
}

# ------------------------------------------------------------
# Private Subnetwork 1 Outputs
# ------------------------------------------------------------

output "private_subnetwork_1_id" {
  description = "ID of private subnetwork 1"
  value       = google_compute_subnetwork.private-subnetwork-1.id
}

output "private_subnetwork_1_name" {
  description = "Name of private subnetwork 1"
  value       = google_compute_subnetwork.private-subnetwork-1.name
}

output "private_subnetwork_1_self_link" {
  description = "Self link of private subnetwork 1"
  value       = google_compute_subnetwork.private-subnetwork-1.self_link
}

output "private_subnetwork_1_cidr" {
  description = "CIDR range of private subnetwork 1"
  value       = google_compute_subnetwork.private-subnetwork-1.ip_cidr_range
}

output "private_subnetwork_1_region" {
  description = "Region of private subnetwork 1"
  value       = google_compute_subnetwork.private-subnetwork-1.region
}

output "private_subnetwork_1_gateway_address" {
  description = "Gateway address of private subnetwork 1"
  value       = google_compute_subnetwork.private-subnetwork-1.gateway_address
}

output "private_subnetwork_1_private_ip_google_access" {
  description = "Whether Private Google Access is enabled on private subnetwork 1"
  value       = google_compute_subnetwork.private-subnetwork-1.private_ip_google_access
}

# ------------------------------------------------------------
# Private Subnetwork 2 Outputs
# ------------------------------------------------------------

output "private_subnetwork_2_id" {
  description = "ID of private subnetwork 2"
  value       = google_compute_subnetwork.private-subnetwork-2.id
}

output "private_subnetwork_2_name" {
  description = "Name of private subnetwork 2"
  value       = google_compute_subnetwork.private-subnetwork-2.name
}

output "private_subnetwork_2_self_link" {
  description = "Self link of private subnetwork 2"
  value       = google_compute_subnetwork.private-subnetwork-2.self_link
}

output "private_subnetwork_2_cidr" {
  description = "CIDR range of private subnetwork 2"
  value       = google_compute_subnetwork.private-subnetwork-2.ip_cidr_range
}

output "private_subnetwork_2_region" {
  description = "Region of private subnetwork 2"
  value       = google_compute_subnetwork.private-subnetwork-2.region
}

output "private_subnetwork_2_gateway_address" {
  description = "Gateway address of private subnetwork 2"
  value       = google_compute_subnetwork.private-subnetwork-2.gateway_address
}

output "private_subnetwork_2_private_ip_google_access" {
  description = "Whether Private Google Access is enabled on private subnetwork 2"
  value       = google_compute_subnetwork.private-subnetwork-2.private_ip_google_access
}