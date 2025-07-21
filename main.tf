provider "aws" {
  region = var.region
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_availability_zones" "available" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name = var.cluster_name
  cluster_version = "1.31"
 
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true	
  eks_managed_node_groups = {
    nodes = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "null_resource" "k8s_config" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region $REGION --name $CLUSTER"
    environment = {
        REGION = var.region
        CLUSTER = var.cluster_name
    }
  }
  depends_on = [module.eks]
}
