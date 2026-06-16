variable "gcp_project" {
  description = "GCP project for resources"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for resources"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "gcp_vpc_cidrs" {
  description = "CIDR block for VPC"
  type        = string
}

variable "gcp_subnet_1_cidr" {
  description = "CIDR block for the first subnet"
  type        = string
}

variable "gcp_subnet_2_cidr" {
  description = "CIDR block for the second subnet"
  type        = string
}

variable "gcp_subnet_3_cidr" {
  description = "CIDR block for the third subnet"
  type        = string
}

variable "gcp_subnet_4_cidr" {
  description = "CIDR block for the fourth subnet"
  type        = string
}