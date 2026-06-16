variable "name" {
  type        = string
  description = "Name of the GCP VM instance."
}

variable "gcp_project" {
  type        = string
  description = "GCP project ID."
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone for the VM."
}

variable "machine_type" {
  type        = string
  description = "Machine type for the GCP VM."
  default     = "e2-micro"
}

variable "network" {
  type        = string
  description = "VPC network name or self_link."
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork name or self_link."
}

variable "boot_image" {
  type        = string
  description = "Boot image for the VM."
  default     = "debian-cloud/debian-12"
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether to assign an external public IP."
  default     = true
}

variable "ssh_source_ranges" {
  type        = list(string)
  description = "CIDR ranges allowed to SSH into the VM."
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type        = list(string)
  description = "Network tags for the VM."
}

variable "labels" {
  type        = map(string)
  description = "Labels for the VM."
  default     = {}
}

variable "network_tags" {
  type        = list(string)
  description = "Network tags for the VM."
}