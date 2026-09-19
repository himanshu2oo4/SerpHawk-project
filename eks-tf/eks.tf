module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "serphawk-eks"
  kubernetes_version = "1.36"

  endpoint_public_access  = true
  endpoint_private_access = true

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  control_plane_subnet_ids = module.vpc.private_subnets

  enable_irsa = true # IAM role for service accounts if the resources need to access something over aws 

access_entries = {
  learner = {
    principal_arn = "arn:aws:iam::815802019107:user/learner"

    policy_associations = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}

  eks_managed_node_groups = {
    serphawk_nodes = {
      name = "serphawk-node-group"

      instance_types = ["c7i-flex.large"]

      capacity_type = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      disk_size = 20

      subnet_ids = module.vpc.private_subnets


      labels = {
        Environment = "dev"
        Project     = "SerpHawk"
      }
    }
  }


   addons = {
    # provides networking to the pods 
    vpc-cni = {
      before_compute = true   # because networks should be there before getting the ec2 as nodes 
      most_recent    = true
    }

    # implements kubernetes service networking 
    kube-proxy = {
      most_recent = true
    }
    # provides dns inside k8s   frontend calls backend by its service name instead of ip address of pods -> internally it maps it with the IP 
    coredns = {
      most_recent = true
    }

  }


  tags = {
    Project     = "SerpHawk"
    Environment = "dev"
  }
}