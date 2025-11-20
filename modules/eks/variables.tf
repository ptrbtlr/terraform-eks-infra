# modules/eks/variables.tf

variable "name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "partition" {
  type = string
}

variable "account_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_instance_type" {
  type    = string
  default = "t3.small"
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

# Pre-created node role (best practice)
variable "node_role_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
