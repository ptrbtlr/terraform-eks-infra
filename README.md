# terraform-eks-infra

Terraform configuration for my AWS infrastructure lab.

## Phase 1 – Network Foundation

This repo currently provisions:

- A dedicated VPC in `us-east-2`
- Public and private subnets across multiple AZs
- Internet Gateway and NAT Gateway
- Route tables wired for public + private traffic

The VPC is defined via a reusable module in `modules/vpc`, following a structure similar to real-world infrastructure repos.

## Usage

```bash
terraform init
terraform plan
terraform apply
