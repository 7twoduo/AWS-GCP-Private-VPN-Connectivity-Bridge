variable "name" {
  type        = string
  description = "Name for the EC2 instance and security group."
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t2.micro"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the EC2 instance will be deployed."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the security group will be created."
}

variable "key_name" {
  type        = string
  description = "Optional EC2 key pair name."
  default     = null
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP address."
  default     = true
}

variable "ssh_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH into the instance."
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to AWS resources."
  default     = {}
}