output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnets" { value = module.vpc.public_subnets }
output "private_subnets" { value = module.vpc.private_subnets }
output "cluster_name" { value = module.eks.cluster_name }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }
