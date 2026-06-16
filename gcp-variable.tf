variable "gcp_region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}
variable "gcp_region2" {
  description = "GCP region for resources"
  type        = string
  default     = "me-central1"
}

variable "gcp_project" {
  description = "GCP project for resources"
  type        = string
  default     = "gcp-mastery-495919"
}

variable "gcp_vpc_cidrs" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.120.0.0/16"
}
variable "gcp_machine_type" {
  description = "GCP machine type for resources"
  type        = string
  default     = "e2-standard-2"
}


locals {
  # Easiest way to make many subnets easily
  public_subnet_1_gcp = cidrsubnet(var.gcp_vpc_cidrs, 8, 1)
  public_subnet_2_gcp = cidrsubnet(var.gcp_vpc_cidrs, 8, 2)

  private_subnet_1_gcp = cidrsubnet(var.gcp_vpc_cidrs, 8, 10)
  private_subnet_2_gcp = cidrsubnet(var.gcp_vpc_cidrs, 8, 11)
  # Second VPC Subnets 
  public_subnet_1_gcp2 = cidrsubnet(var.gcp_vpc_cidrs, 8, 3)
  public_subnet_2_gcp2 = cidrsubnet(var.gcp_vpc_cidrs, 8, 4)

  private_subnet_1_gcp2 = cidrsubnet(var.gcp_vpc_cidrs, 8, 12)
  private_subnet_2_gcp2 = cidrsubnet(var.gcp_vpc_cidrs, 8, 13)
}
