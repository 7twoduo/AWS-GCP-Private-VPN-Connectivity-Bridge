#####################################################################################################################################
#                                               VPN CONNECTION TO GCP FROM GCP
#####################################################################################################################################

# provider "google" {
#   project = var.gcp_project
#   region  = var.gcp_region
# }
# The way this works, i can't do that so it is best to just use the var.region2 to change the region of everything.

module "standard-gcp-gcp-2" {
  source = "./Modules/Standard-VPC-GCP"

  gcp_project   = var.gcp_project
  gcp_region    = var.gcp_region
  gcp_vpc_cidrs = var.gcp_vpc_cidrs
  project_name  = "${var.project_name}-2" # Second GCP VPC

  gcp_subnet_1_cidr = local.public_subnet_1_gcp2
  gcp_subnet_2_cidr = local.public_subnet_2_gcp2
  gcp_subnet_3_cidr = local.private_subnet_1_gcp2
  gcp_subnet_4_cidr = local.private_subnet_2_gcp2
}


resource "google_compute_router" "vpn-router-2" {
  name                          = "vpn-router-2"
  region                        = var.gcp_region
  network                       = module.standard-gcp-gcp-2.vpc_name
  encrypted_interconnect_router = false # It doesn't work with VPN Tunnels
  bgp {
    asn            = 65005
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_ha_vpn_gateway" "ha_gateway2" {
  region  = var.gcp_region
  name    = "${var.project_name}-ha-vpn-2"
  network = module.standard-gcp-gcp-2.vpc_id
}



###                          PEER VPN GATEWAY GCP TO GCP


###########   PSK Generator

resource "random_password" "gcp_tunnel_1_psk1" {
  length  = 31
  special = false
}

resource "random_password" "gcp_tunnel_1_psk2" {
  length  = 31
  special = false
}


##########                    TUNNELS CONFIGURATION

# Tunnel 0
resource "google_compute_vpn_tunnel" "gcp_tunnel-2_1" {
  name   = "gcp-to-gcp-tunnel-3-1"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway2.id
  vpn_gateway_interface = 0

  peer_gcp_gateway = google_compute_ha_vpn_gateway.ha_gateway1.id

  shared_secret = random_password.gcp_tunnel_1_psk1.result
  ike_version   = 2

  router = google_compute_router.vpn-router-2.self_link
}

# Tunnel 1
resource "google_compute_vpn_tunnel" "gcp_tunnel2_2" {
  name   = "gcp-to-gcp-tunnel-3-2"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway2.id
  vpn_gateway_interface = 1

  peer_gcp_gateway = google_compute_ha_vpn_gateway.ha_gateway1.id

  shared_secret = random_password.gcp_tunnel_1_psk2.result
  ike_version   = 2

  router = google_compute_router.vpn-router-2.self_link
}


#  BGP BGP BGP BGP
##########################################################################################################
##########                    GCP Router Interface and Peer Connection        
##########################################################################################################
variable "tunnel3_ip_1" {
  type        = string
  description = "IP address for first tunnel"
  default     = "169.254.50.2/30"
}

variable "tunnel3_ip_2" {
  type        = string
  description = "IP address for second tunnel"
  default     = "169.254.50.6/30"
}

# This is a component for making BGP Connections to GCP
# This is my ip inside the tunnel for bgp
# The IP range is representing my communication ip for the BGP connection.
resource "google_compute_router_interface" "aws_tunnel3_1" {
  name   = "aws-tunnel-3-1-interface"
  router = google_compute_router.vpn-router-2.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel-2_1.name

  ip_range = var.tunnel3_ip_1
}


resource "google_compute_router_interface" "aws_tunnel3_2" {
  name   = "aws-tunnel-3-2-interface"
  router = google_compute_router.vpn-router-2.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel2_2.name

  ip_range = var.tunnel3_ip_2
}

variable "peer3_ip_1" {
  type        = string
  description = "IP address for first tunnel"
  default     = "169.254.50.1"
}

variable "peer3_ip_2" {
  type        = string
  description = "IP address for second tunnel"
  default     = "169.254.50.5"
}


resource "google_compute_router_peer" "aws_tunnel3_1" {
  name                      = "aws-tunnel3-1-peer"
  router                    = google_compute_router.vpn-router-2.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel3_1.name
  peer_ip_address           = var.peer3_ip_1
  peer_asn                  = google_compute_router.vpn-router.bgp[0].asn
  advertised_route_priority = 100

}

resource "google_compute_router_peer" "aws_tunnel3_2" {
  name                      = "aws-tunnel3-2-peer"
  router                    = google_compute_router.vpn-router-2.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel3_2.name
  peer_ip_address           = var.peer3_ip_2
  peer_asn                  = google_compute_router.vpn-router.bgp[0].asn
  advertised_route_priority = 100

}









##################################################################################################
#                            Virtual Machine for VPN Test
##################################################################################################

module "gcp_vm-2" {
  source = "./Modules/GCP-VM"

  name        = "gcp-test-vm-2"
  gcp_project = var.gcp_project
  gcp_zone    = "us-central1-b"

  network    = module.standard-gcp-vpc.vpc_name
  subnetwork = module.standard-gcp-vpc.public_subnetwork_1_name

  machine_type      = var.gcp_machine_type
  assign_public_ip  = true
  tags              = ["gcp-test-vm-2"]
  ssh_source_ranges = ["0.0.0.0/0"]
  network_tags = [
    "allow-ssh",
    "allow-web"
  ]

  labels = {
    project = var.project_name
  }
}