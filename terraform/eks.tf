module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.34"

  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = ["68.104.92.33/32"]

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    coredns = {}

    kube-proxy = {}

    vpc-cni = {
      before_compute = true
    }

    eks-pod-identity-agent = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    application = {
      name = "tech-challenge-2-nodes"

      instance_types = [
        var.node_instance_type
      ]

      ami_type      = "AL2023_x86_64_STANDARD"
      capacity_type = "ON_DEMAND"

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      disk_size = 30

      labels = {
        role = "application"
      }

      tags = {
        Name = "tech-challenge-2-worker"
      }
    }
  }

  tags = {
    Environment = "challenge"
    Project     = "tech-challenge-2"
  }
}