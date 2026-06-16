output "tunnel_1_1_aws_inside" {
  value = aws_vpn_connection.tunnel_1.tunnel1_vgw_inside_address
}

output "tunnel_1_1_gcp_inside" {
  value = aws_vpn_connection.tunnel_1.tunnel1_cgw_inside_address
}

output "tunnel_1_2_aws_inside" {
  value = aws_vpn_connection.tunnel_1.tunnel2_vgw_inside_address
}

output "tunnel_1_2_gcp_inside" {
  value = aws_vpn_connection.tunnel_1.tunnel2_cgw_inside_address
}

output "tunnel_2_1_aws_inside" {
  value = aws_vpn_connection.tunnel_2.tunnel1_vgw_inside_address
}

output "tunnel_2_1_gcp_inside" {
  value = aws_vpn_connection.tunnel_2.tunnel1_cgw_inside_address
}

output "tunnel_2_2_aws_inside" {
  value = aws_vpn_connection.tunnel_2.tunnel2_vgw_inside_address
}

output "tunnel_2_2_gcp_inside" {
  value = aws_vpn_connection.tunnel_2.tunnel2_cgw_inside_address
}
output "tunnel_data" {
  value = aws_vpn_connection.tunnel_2.tunnel2_cgw_inside_address
}

##  Public Instance IPs
output "vm_public_ip_aws" {
  value = module.aws_vm.public_ip
}

output "vm_public_ip_gcp" {
  value = module.gcp_vm-1.public_ip
}

output "vm_public_ip_gcp-2" {
  value = module.gcp_vm-2.public_ip
}

##  Private Instance IPs
output "vm_private_ip_aws" {
  value = module.aws_vm.private_ip
}

output "vm_private_ip_gcp" {
  value = module.gcp_vm-1.private_ip
}

output "vm_private_ip_gcp-2" {
  value = module.gcp_vm-2.private_ip
}