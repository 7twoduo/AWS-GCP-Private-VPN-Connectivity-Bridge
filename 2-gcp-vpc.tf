#####################################################################################################################################
#                                               VPN CONNECTION TO AWS
#####################################################################################################################################

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

module "standard-gcp-vpc" {
  source = "./Modules/Standard-VPC-GCP"

  gcp_project   = var.gcp_project
  gcp_region    = var.gcp_region
  gcp_vpc_cidrs = var.gcp_vpc_cidrs
  project_name  = var.project_name

  gcp_subnet_1_cidr = local.public_subnet_1_gcp
  gcp_subnet_2_cidr = local.public_subnet_2_gcp
  gcp_subnet_3_cidr = local.private_subnet_1_gcp
  gcp_subnet_4_cidr = local.private_subnet_2_gcp
}


resource "google_compute_router" "vpn-router" {
  name                          = "vpn-router"
  region                        = var.gcp_region
  network                       = module.standard-gcp-vpc.vpc_name
  encrypted_interconnect_router = false # It doesn't work with VPN Tunnels
  bgp {
    asn            = 65003
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_ha_vpn_gateway" "ha_gateway1" {
  region  = var.gcp_region
  name    = "${var.project_name}-ha-vpn-1"
  network = module.standard-gcp-vpc.vpc_id
}




###                          PEER VPN GATEWAY 
# Terraform calls it something else
# Think of it like a Customer Gateway in AWS

resource "google_compute_external_vpn_gateway" "gcp-to-aws-vpn-gw" {
  #count           = var.second_workflow_enabled ? 1 : 0
  name            = "gcp-to-aws-vpn-gw"
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.tunnel_1.tunnel1_address
  }

  interface {
    id         = 1
    ip_address = aws_vpn_connection.tunnel_1.tunnel2_address
  }

  interface {
    id         = 2
    ip_address = aws_vpn_connection.tunnel_2.tunnel1_address
  }

  interface {
    id         = 3
    ip_address = aws_vpn_connection.tunnel_2.tunnel2_address
  }
}

##########                    TUNNELS CONFIGURATION

# Tunnel 0
resource "google_compute_vpn_tunnel" "aws_tunnel_1" {
  name   = "gcp-to-aws-tunnel-1"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway1.id
  vpn_gateway_interface = 0

  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw.id
  peer_external_gateway_interface = 0

  shared_secret = random_password.vpn_tunnel_1_psk1.result
  ike_version   = 2

  router = google_compute_router.vpn-router.self_link
}

# Tunnel 1
resource "google_compute_vpn_tunnel" "aws_tunnel_2" {
  name   = "gcp-to-aws-tunnel-2"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway1.id
  vpn_gateway_interface = 0

  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw.id
  peer_external_gateway_interface = 1

  shared_secret = random_password.vpn_tunnel_1_psk2.result
  ike_version   = 2

  router = google_compute_router.vpn-router.self_link
}

# Tunnel 2
resource "google_compute_vpn_tunnel" "aws_tunnel_3" {
  name   = "gcp-to-aws-tunnel-3"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway1.id
  vpn_gateway_interface = 1

  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw.id
  peer_external_gateway_interface = 2

  shared_secret = random_password.vpn_tunnel_2_psk1.result
  ike_version   = 2

  router = google_compute_router.vpn-router.self_link
}

# Tunnel 3
resource "google_compute_vpn_tunnel" "aws_tunnel_4" {
  name   = "gcp-to-aws-tunnel-4"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway1.id
  vpn_gateway_interface = 1

  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw.id
  peer_external_gateway_interface = 3

  shared_secret = random_password.vpn_tunnel_2_psk2.result
  ike_version   = 2

  router = google_compute_router.vpn-router.self_link
}

#  BGP BGP BGP BGP
##########################################################################################################
##########                    GCP Router Interface and Peer Connection        
##########################################################################################################


# This is a component for making BGP Connections to GCP
# This is my ip inside the tunnel for bgp
# The IP range is representing my communication ip for the BGP connection.
resource "google_compute_router_interface" "aws_tunnel_1" {
  name   = "aws-tunnel-1-interface"
  router = google_compute_router.vpn-router.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.aws_tunnel_1.name

  ip_range = local.gcp_tunnel_1_ip_range
}


resource "google_compute_router_interface" "aws_tunnel_2" {
  name   = "aws-tunnel-2-interface"
  router = google_compute_router.vpn-router.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.aws_tunnel_2.name

  ip_range = local.gcp_tunnel_2_ip_range
}


resource "google_compute_router_interface" "aws_tunnel_3" {
  name   = "aws-tunnel-3-interface"
  router = google_compute_router.vpn-router.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.aws_tunnel_3.name

  ip_range = local.gcp_tunnel_3_ip_range
}


resource "google_compute_router_interface" "aws_tunnel_4" {
  name   = "aws-tunnel-4-interface"
  router = google_compute_router.vpn-router.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.aws_tunnel_4.name

  ip_range = local.gcp_tunnel_4_ip_range
}

#  BGP BGP BGP BGP
#########################################################################
#                               BGP PEER
#########################################################################
# This is the final piece to finalizing BGP Connections
# This IP represents the ip address for the peer in the BGP connection.
# This is aws bgp ip internally
resource "google_compute_router_peer" "aws_tunnel_1" {
  name                      = "aws-tunnel-1-peer"
  router                    = google_compute_router.vpn-router.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel_1.name
  peer_ip_address           = local.aws_tunnel_1_peer_ip
  peer_asn                  = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  advertised_route_priority = 100
}

resource "google_compute_router_peer" "aws_tunnel_2" {
  name                      = "aws-tunnel-2-peer"
  router                    = google_compute_router.vpn-router.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel_2.name
  peer_ip_address           = local.aws_tunnel_2_peer_ip
  peer_asn                  = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  advertised_route_priority = 100

}

resource "google_compute_router_peer" "aws_tunnel_3" {
  name                      = "aws-tunnel-3-peer"
  router                    = google_compute_router.vpn-router.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel_3.name
  peer_ip_address           = local.aws_tunnel_3_peer_ip
  peer_asn                  = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  advertised_route_priority = 100

}

resource "google_compute_router_peer" "aws_tunnel_4" {
  name                      = "aws-tunnel-4-peer"
  router                    = google_compute_router.vpn-router.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel_4.name
  peer_ip_address           = local.aws_tunnel_4_peer_ip
  peer_asn                  = aws_vpn_gateway.vpn_gateway.amazon_side_asn
  advertised_route_priority = 100

}

# To make a big story short
#  0   Network IP 
#  1   AWS BGP IP 
#  2   GCP BGP IP 
#  3   Broadcast IP 


# That is the internals as to how a bgp connection works within a vpn
# The VPN connection itself is pretty easy, it is the BGP configuration that is complex.
# That is the basic concept of a BGP connection within a VPN.






#########################################################################################################################################
#                                                   GCP To GCP VPN TUNNEL
#########################################################################################################################################


###                          PEER VPN GATEWAY GCP TO GCP


##########                    TUNNELS CONFIGURATION

# Tunnel 0
resource "google_compute_vpn_tunnel" "gcp_tunnel2__1" {
  name   = "gcp-to-gcp-tunnel-2-1"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway1.id
  vpn_gateway_interface = 0

  peer_gcp_gateway = google_compute_ha_vpn_gateway.ha_gateway2.id

  shared_secret = random_password.gcp_tunnel_1_psk1.result
  ike_version   = 2

  router = google_compute_router.vpn-router.self_link
}

# Tunnel 1
resource "google_compute_vpn_tunnel" "gcp_tunnel2__2" {
  name   = "gcp-to-gcp-tunnel-2-2"
  region = var.gcp_region

  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway1.id
  vpn_gateway_interface = 1

  peer_gcp_gateway = google_compute_ha_vpn_gateway.ha_gateway2.id

  shared_secret = random_password.gcp_tunnel_1_psk2.result
  ike_version   = 2

  router = google_compute_router.vpn-router.self_link
}



#  BGP BGP BGP BGP
##########################################################################################################
##########                    GCP Router Interface and Peer Connection        
##########################################################################################################
variable "tunnel2_ip_1" {
  type        = string
  description = "IP address for first tunnel"
  default     = "169.254.50.1/30"
}

variable "tunnel2_ip_2" {
  type        = string
  description = "IP address for second tunnel"
  default     = "169.254.50.5/30"
}

# This is a component for making BGP Connections to GCP
# This is my ip inside the tunnel for bgp
# The IP range is representing my communication ip for the BGP connection.
resource "google_compute_router_interface" "aws_tunnel2_1" {
  name   = "aws-tunnel-2-1-interface"
  router = google_compute_router.vpn-router.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel2__1.name

  ip_range = var.tunnel2_ip_1
}


resource "google_compute_router_interface" "aws_tunnel2_2" {
  name   = "aws-tunnel-2-2-interface"
  router = google_compute_router.vpn-router.name
  region = var.gcp_region

  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel2__2.name

  ip_range = var.tunnel2_ip_2
}

variable "peer2_ip_1" {
  type        = string
  description = "IP address for first tunnel"
  default     = "169.254.50.2"
}

variable "peer2_ip_2" {
  type        = string
  description = "IP address for second tunnel"
  default     = "169.254.50.6"
}

resource "google_compute_router_peer" "aws_tunnel2_1" {
  name                      = "aws-tunnel2-1-peer"
  router                    = google_compute_router.vpn-router.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel2_1.name
  peer_ip_address           = var.peer2_ip_1
  peer_asn                  = google_compute_router.vpn-router-2.bgp[0].asn
  advertised_route_priority = 100

}

resource "google_compute_router_peer" "aws_tunnel2_2" {
  name                      = "aws-tunnel2-2-peer"
  router                    = google_compute_router.vpn-router.name
  region                    = var.gcp_region
  interface                 = google_compute_router_interface.aws_tunnel2_2.name
  peer_ip_address           = var.peer2_ip_2
  peer_asn                  = google_compute_router.vpn-router-2.bgp[0].asn
  advertised_route_priority = 100

}

# 169.254.50.0/30 ~ 169.254.50.3/30
# To make a big story short
#  0   Network IP  169.254.50.0/30
#  1   AWS BGP IP  169.254.50.1/30
#  2   GCP BGP IP  169.254.50.2/30
#  3   Broadcast IP  169.254.50.3/30
# [,,,]
# 169.254.50.1/30
# 

# 169.254.50.4/30 ~ 169.254.50.7/30
# To make a big story short
#  0   Network IP  169.254.50.4/30
#  1   AWS BGP IP  169.254.50.5/30
#  2   GCP BGP IP  169.254.50.6/30
#  3   Broadcast IP  169.254.50.7/30

# 
# 











##################################################################################################
#                            Virtual Machine for VPN Test
##################################################################################################

module "gcp_vm-1" {
  source = "./Modules/GCP-VM"

  name        = "gcp-test-vm-1"
  gcp_project = var.gcp_project
  gcp_zone    = "us-central1-a"

  network    = module.standard-gcp-vpc.vpc_name
  subnetwork = module.standard-gcp-vpc.public_subnetwork_1_name

  machine_type     = var.gcp_machine_type
  assign_public_ip = true

  tags = ["gcp-test-vm-1"]
  network_tags = [
    "allow-ssh",
    "allow-web"
  ]

  ssh_source_ranges = ["0.0.0.0/0"]

  labels = {
    project = var.project_name
  }
}