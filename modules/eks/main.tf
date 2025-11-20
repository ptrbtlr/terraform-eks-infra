module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  enabled_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  tags = var.tags
}
