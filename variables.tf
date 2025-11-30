# ===== Global / Provider =====
variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, stage, prod)"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Project or application name"
  default     = "eks-devops-platform"
}


# ===== VPC =====
variable "vpc_name" {
  type        = string
  description = "Name for the VPC"
  default     = "devops-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC"
  default     = "10.0.0.0/16"
}

# If null, main.tf will auto-pick the first 2 AZs in the region
variable "azs" {
  type        = list(string)
  description = "Availability Zones to use"
  default     = null
}

# If null, main.tf will auto-generate two /24 public subnets from vpc_cidr
variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDRs"
  default     = null
}

# If null, main.tf will auto-generate two /24 private subnets from vpc_cidr
variable "private_subnets" {
  type        = list(string)
  description = "Private subnet CIDRs"
  default     = null
}

# ===== EKS =====
variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "devops-eks"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version (e.g., 1.30)"
  default     = "1.30"
}

# ===== Node group sizing =====
variable "node_instance_type" {
  type        = string
  description = "Instance type for the managed node group"
  default     = "t3.small" # use t3.micro if you want the tiniest node
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 1
}
