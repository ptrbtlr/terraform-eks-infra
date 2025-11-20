##############################################
# main.tf  (provider "aws" lives in provider.tf)
##############################################

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# --- Discover AZs in the selected region
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Defaults when user doesn't provide AZs/subnets
locals {
  # First 2 AZs in the region if none provided
  azs_effective = var.azs != null ? var.azs : slice(data.aws_availability_zones.available.names, 0, 2)

  # /16 -> two private /24s (10.0.1.0/24, 10.0.2.0/24)
  private_subnets_effective = var.private_subnets != null ? var.private_subnets : [
    for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]

  # /16 -> two public /24s (10.0.101.0/24, 10.0.102.0/24)
  public_subnets_effective = var.public_subnets != null ? var.public_subnets : [
    for i in range(2) : cidrsubnet(var.vpc_cidr, 8, 100 + i)
  ]
}

# -----------------------------
# VPC (wrapper around official module)
# -----------------------------
module "vpc" {
  source = "./modules/vpc"

  name            = var.vpc_name
  cidr            = var.vpc_cidr
  azs             = local.azs_effective
  public_subnets  = local.public_subnets_effective  # <-- locals, not var.*
  private_subnets = local.private_subnets_effective # <-- locals, not var.*

  # Subnet tags for EKS/ALB discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Project     = "eks-devops-pipeline"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------
# IAM role for EKS managed node group (you own the policies)
# -----------------------------------
data "aws_iam_policy_document" "ng_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "nodegroup" {
  name               = "devops-eks-nodegroup"
  assume_role_policy = data.aws_iam_policy_document.ng_trust.json
  tags               = { ManagedBy = "terraform" }
}

resource "aws_iam_role_policy_attachment" "ng_worker" {
  role       = aws_iam_role.nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ng_ecr" {
  role       = aws_iam_role.nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ng_ssm" {
  role       = aws_iam_role.nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------
# EKS (your wrapper module around terraform-aws-eks v21+)
# -----------------------------
module "eks" {
  source = "./modules/eks"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # keep nodes private behind NAT

  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_desired_size  = var.node_desired_size
  node_max_size      = var.node_max_size

  # Use pre-created node role
  node_role_arn = aws_iam_role.nodegroup.arn

  tags = {
    Project     = "eks-devops-pipeline"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ng_worker,
    aws_iam_role_policy_attachment.ng_ecr,
    aws_iam_role_policy_attachment.ng_ssm
  ]

  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
}

# -----------------------------------
# IRSA for VPC CNI (aws-node)
# -----------------------------------
data "aws_iam_openid_connect_provider" "eks" {
  arn = module.eks.oidc_provider_arn
}

data "aws_iam_policy_document" "cni_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    # Only kube-system/aws-node
    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
  }
}

resource "aws_iam_role" "cni_irsa" {
  name               = "devops-eks-cni-irsa"
  assume_role_policy = data.aws_iam_policy_document.cni_trust.json
  tags               = { ManagedBy = "terraform" }
}

resource "aws_iam_role_policy_attachment" "cni_irsa_attach" {
  role       = aws_iam_role.cni_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# -----------------------------------
# Core EKS add-ons (managed by TF)
# -----------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "vpc-cni"
  service_account_role_arn = aws_iam_role.cni_irsa.arn
  depends_on               = [aws_iam_role_policy_attachment.cni_irsa_attach]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
}

# Managed node group created explicitly to avoid module plan-time count issues
resource "aws_eks_node_group" "default" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.nodegroup.arn
  subnet_ids      = module.vpc.private_subnets

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2_x86_64" # or "AL2_ARM_64" if you pick Graviton instance types
  capacity_type  = "ON_DEMAND"

  update_config {
    max_unavailable = 1
  }

  tags = {
    ManagedBy = "terraform"
  }

  # Ensure the cluster exists first (and the role + policies are attached)
  depends_on = [
    module.eks, # the cluster
    aws_iam_role_policy_attachment.ng_worker,
    aws_iam_role_policy_attachment.ng_ecr,
    aws_iam_role_policy_attachment.ng_ssm
  ]
}
