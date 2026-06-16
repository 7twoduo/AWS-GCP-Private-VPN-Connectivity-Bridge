
variable "aws_region" {
  description = "AWS region for resources"
  type        = string

}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string

}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string

}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string

}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string

}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string

}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string

}
