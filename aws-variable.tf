
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "vpn-magic"
}

variable "workspace_vpc_cidrs" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.99.0.0/16"
}


locals {
  # Easiest way to make many subnets easily
  public_subnet_1_cidr = cidrsubnet(var.workspace_vpc_cidrs, 8, 1)
  public_subnet_2_cidr = cidrsubnet(var.workspace_vpc_cidrs, 8, 2)

  private_subnet_1_cidr = cidrsubnet(var.workspace_vpc_cidrs, 8, 10)
  private_subnet_2_cidr = cidrsubnet(var.workspace_vpc_cidrs, 8, 11)
}



#                          FOR BGP Inside the tunnel
variable "tunnel1_inside_cidr1" {
  description = "Inside IPv4 CIDR for AWS VPN tunnel 1. Must be a /30 from 169.254.0.0/16 and unique on this VGW."
  type        = string
  default     = "169.254.21.0/30"
}

variable "tunnel1_inside_cidr2" {
  description = "Inside IPv4 CIDR for AWS VPN tunnel 2. Must be a /30 from 169.254.0.0/16 and unique on this VGW."
  type        = string
  default     = "169.254.21.4/30"
}



variable "tunnel2_inside_cidr1" {
  description = "Inside IPv4 CIDR for AWS VPN tunnel 1. Must be a /30 from 169.254.0.0/16 and unique on this VGW."
  type        = string
  default     = "169.254.23.0/30"
}

variable "tunnel2_inside_cidr2" {
  description = "Inside IPv4 CIDR for AWS VPN tunnel 2. Must be a /30 from 169.254.0.0/16 and unique on this VGW."
  type        = string
  default     = "169.254.23.4/30"
}
variable "aws_machine_type" {
  description = "AWS machine type for resources"
  type        = string
  default     = "t3.micro"
}



locals {
  aws_tunnel_1_inside_cidr = aws_vpn_connection.tunnel_1.tunnel1_inside_cidr
  aws_tunnel_2_inside_cidr = aws_vpn_connection.tunnel_1.tunnel2_inside_cidr
  aws_tunnel_3_inside_cidr = aws_vpn_connection.tunnel_2.tunnel1_inside_cidr
  aws_tunnel_4_inside_cidr = aws_vpn_connection.tunnel_2.tunnel2_inside_cidr

  # GCP router interface IPs
  gcp_tunnel_1_ip_range = "${cidrhost(local.aws_tunnel_1_inside_cidr, 2)}/30"
  gcp_tunnel_2_ip_range = "${cidrhost(local.aws_tunnel_2_inside_cidr, 2)}/30"
  gcp_tunnel_3_ip_range = "${cidrhost(local.aws_tunnel_3_inside_cidr, 2)}/30"
  gcp_tunnel_4_ip_range = "${cidrhost(local.aws_tunnel_4_inside_cidr, 2)}/30"

  # AWS BGP peer IPs
  aws_tunnel_1_peer_ip = cidrhost(local.aws_tunnel_1_inside_cidr, 1)
  aws_tunnel_2_peer_ip = cidrhost(local.aws_tunnel_2_inside_cidr, 1)
  aws_tunnel_3_peer_ip = cidrhost(local.aws_tunnel_3_inside_cidr, 1)
  aws_tunnel_4_peer_ip = cidrhost(local.aws_tunnel_4_inside_cidr, 1)
}