module "vpc" {
  source = "./modules/vpc"

  name            = var.vpc_name
  cidr            = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  tags = {
    Project     = "eks-devops-pipeline"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
