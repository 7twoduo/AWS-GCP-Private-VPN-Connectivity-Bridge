# ========================================
# VPC Outputs
# ========================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "VPC ARN"
  value       = aws_vpc.main.arn
}


# ========================================
# Internet Gateway Outputs
# ========================================

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "internet_gateway_arn" {
  description = "Internet Gateway ARN"
  value       = aws_internet_gateway.main.arn
}


# ========================================
# Public Subnet Outputs
# ========================================

output "public_subnet_1_id" {
  description = "Public Subnet 1 ID"
  value       = aws_subnet.public_1.id
}

output "public_subnet_1_cidr" {
  description = "Public Subnet 1 CIDR block"
  value       = aws_subnet.public_1.cidr_block
}

output "public_subnet_1_arn" {
  description = "Public Subnet 1 ARN"
  value       = aws_subnet.public_1.arn
}

output "public_subnet_1_availability_zone" {
  description = "Public Subnet 1 Availability Zone"
  value       = aws_subnet.public_1.availability_zone
}

output "public_subnet_2_id" {
  description = "Public Subnet 2 ID"
  value       = aws_subnet.public_2.id
}

output "public_subnet_2_cidr" {
  description = "Public Subnet 2 CIDR block"
  value       = aws_subnet.public_2.cidr_block
}

output "public_subnet_2_arn" {
  description = "Public Subnet 2 ARN"
  value       = aws_subnet.public_2.arn
}

output "public_subnet_2_availability_zone" {
  description = "Public Subnet 2 Availability Zone"
  value       = aws_subnet.public_2.availability_zone
}

output "public_subnets_ids" {
  description = "List of all public subnet IDs"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "public_subnets_cidrs" {
  description = "List of all public subnet CIDR blocks"
  value       = [aws_subnet.public_1.cidr_block, aws_subnet.public_2.cidr_block]
}


# ========================================
# Private Subnet Outputs
# ========================================

output "private_subnet_1_id" {
  description = "Private Subnet 1 ID"
  value       = aws_subnet.private_1.id
}

output "private_subnet_1_cidr" {
  description = "Private Subnet 1 CIDR block"
  value       = aws_subnet.private_1.cidr_block
}

output "private_subnet_1_arn" {
  description = "Private Subnet 1 ARN"
  value       = aws_subnet.private_1.arn
}

output "private_subnet_1_availability_zone" {
  description = "Private Subnet 1 Availability Zone"
  value       = aws_subnet.private_1.availability_zone
}

output "private_subnet_2_id" {
  description = "Private Subnet 2 ID"
  value       = aws_subnet.private_2.id
}

output "private_subnet_2_cidr" {
  description = "Private Subnet 2 CIDR block"
  value       = aws_subnet.private_2.cidr_block
}

output "private_subnet_2_arn" {
  description = "Private Subnet 2 ARN"
  value       = aws_subnet.private_2.arn
}

output "private_subnet_2_availability_zone" {
  description = "Private Subnet 2 Availability Zone"
  value       = aws_subnet.private_2.availability_zone
}

output "private_subnets_ids" {
  description = "List of all private subnet IDs"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "private_subnets_cidrs" {
  description = "List of all private subnet CIDR blocks"
  value       = [aws_subnet.private_1.cidr_block, aws_subnet.private_2.cidr_block]
}


# ========================================
# Public Route Table Outputs
# ========================================

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "public_route_table_arn" {
  description = "Public Route Table ARN"
  value       = aws_route_table.public.arn
}

output "public_route_table_association_1_id" {
  description = "Public Subnet 1 Route Table Association ID"
  value       = aws_route_table_association.public_1.id
}

output "public_route_table_association_2_id" {
  description = "Public Subnet 2 Route Table Association ID"
  value       = aws_route_table_association.public_2.id
}


# ========================================
# Private Route Table Outputs
# ========================================

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = aws_route_table.private.id
}

output "private_route_table_arn" {
  description = "Private Route Table ARN"
  value       = aws_route_table.private.arn
}

output "private_route_table_association_1_id" {
  description = "Private Subnet 1 Route Table Association ID"
  value       = aws_route_table_association.private_1.id
}

output "private_route_table_association_2_id" {
  description = "Private Subnet 2 Route Table Association ID"
  value       = aws_route_table_association.private_2.id
}


# ========================================
# Summary Outputs
# ========================================

output "network_summary" {
  description = "Network infrastructure summary"
  value = {
    vpc_id              = aws_vpc.main.id
    vpc_cidr            = aws_vpc.main.cidr_block
    public_subnets      = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    private_subnets     = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    internet_gateway_id = aws_internet_gateway.main.id
    public_route_table  = aws_route_table.public.id
    private_route_table = aws_route_table.private.id
  }
}
