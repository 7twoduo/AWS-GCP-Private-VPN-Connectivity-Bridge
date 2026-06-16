#####################################################################################################################################
#####################################################################################################################################
#                                               VPN CONNECTIONS TO GCP
#####################################################################################################################################
#####################################################################################################################################

###############################################                    First Workflow
# The first Workflow

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
}

module "standard-vpc" {
  source = "./Modules/Standard-VPC-AWS"

  aws_region   = var.aws_region
  project_name = "${var.project_name}-1"

  vpc_cidr = var.workspace_vpc_cidrs

  public_subnet_1_cidr  = local.public_subnet_1_cidr
  public_subnet_2_cidr  = local.public_subnet_2_cidr
  private_subnet_1_cidr = local.private_subnet_1_cidr
  private_subnet_2_cidr = local.private_subnet_2_cidr
}

resource "aws_customer_gateway" "router_ip_1" {
  bgp_asn    = google_compute_router.vpn-router.bgp[0].asn
  ip_address = google_compute_ha_vpn_gateway.ha_gateway1.vpn_interfaces[0].ip_address
  type       = "ipsec.1"

  tags = {
    Name = "main-customer-gateway"
  }
}

resource "aws_customer_gateway" "router_ip_2" {
  bgp_asn    = google_compute_router.vpn-router.bgp[0].asn
  ip_address = google_compute_ha_vpn_gateway.ha_gateway1.vpn_interfaces[1].ip_address
  type       = "ipsec.1"

  tags = {
    Name = "main-customer-gateway"
  }
  #depends_on = [google_compute_ha_vpn_gateway.vpn-router]
}

resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = module.standard-vpc.vpc_id

  amazon_side_asn = 65000
}
###########   PSK Generator

resource "random_password" "vpn_tunnel_1_psk1" {
  length  = 31
  special = false
}

resource "random_password" "vpn_tunnel_1_psk2" {
  length  = 31
  special = false
}

# Create the VPN connections which is 1 IP


resource "aws_vpn_connection" "tunnel_1" {
  customer_gateway_id = aws_customer_gateway.router_ip_1.id
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  type                = "ipsec.1"

  static_routes_only = false

  tunnel1_inside_cidr = var.tunnel1_inside_cidr1
  tunnel2_inside_cidr = var.tunnel1_inside_cidr2

  tunnel1_preshared_key = random_password.vpn_tunnel_1_psk1.result
  tunnel2_preshared_key = random_password.vpn_tunnel_1_psk2.result

  # Optional but cleaner: force IKEv2 only
  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tags = {
    Name = "1-main-site-to-site-vpn"
  }
}

###########   PSK Generator

resource "random_password" "vpn_tunnel_2_psk1" {
  length  = 31
  special = false
}

resource "random_password" "vpn_tunnel_2_psk2" {
  length  = 31
  special = false
}


# Create the second VPN connection with 1 IP


resource "aws_vpn_connection" "tunnel_2" {
  customer_gateway_id = aws_customer_gateway.router_ip_2.id
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  type                = "ipsec.1"

  static_routes_only = false

  tunnel1_inside_cidr = var.tunnel2_inside_cidr1
  tunnel2_inside_cidr = var.tunnel2_inside_cidr2

  tunnel1_preshared_key = random_password.vpn_tunnel_2_psk1.result
  tunnel2_preshared_key = random_password.vpn_tunnel_2_psk2.result

  # Optional but cleaner: force IKEv2 only
  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tags = {
    Name = "2-main-site-to-site-vpn"
  }
}

## Route Propagation
resource "aws_vpn_gateway_route_propagation" "public" {
  vpn_gateway_id = aws_vpn_gateway.vpn_gateway.id
  route_table_id = module.standard-vpc.public_route_table_id
}

resource "aws_vpn_gateway_route_propagation" "private" {
  vpn_gateway_id = aws_vpn_gateway.vpn_gateway.id
  route_table_id = module.standard-vpc.private_route_table_id
}
















##################################################################################################
#                            Virtual Machine for VPN Test
##################################################################################################

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

module "aws_vm" {
  source = "./Modules/AWS-VM"

  name          = "aws-test-vm-1"
  ami_id        = data.aws_ami.amazon_linux_2.id
  instance_type = var.aws_machine_type
  subnet_id     = module.standard-vpc.public_subnet_1_id
  vpc_id        = module.standard-vpc.vpc_id
  #key_name      = var.aws_key_name

  ssh_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Project = var.project_name
  }
}