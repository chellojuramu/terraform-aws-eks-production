# ────────────────────────────────────────────────────────────
# EKS Cluster Module
# Source: Git repository (your published module)
# ────────────────────────────────────────────────────────────

module "eks" {
  # Git source with subdirectory and branch reference
  source = "git::https://github.com/chellojuramu/terraform-aws-eks-production.git//modules/terraform-aws-eks?ref=main"

  # ── Basic Configuration ─────────────────────────────────
  project     = var.project     # "roboshop"
  environment = var.environment # "dev"

  # ── Cluster Configuration ───────────────────────────────
  cluster_version = var.eks_version # "1.31"

  # ── Networking (from 00-vpc via SSM) ────────────────────
  vpc_id             = local.vpc_id             # vpc-0abc123
  private_subnet_ids = local.private_subnet_ids # [subnet-0abc, subnet-0def]

  # ── Security Groups (from 10-sg via SSM) ────────────────
  cluster_security_group_ids = [local.eks_control_plane_sg_id] # [sg-0xyz]
  node_security_group_ids    = [local.eks_node_sg_id]          # [sg-0uvw]

  # ── Node Groups (Blue-Green Pattern) ────────────────────
  eks_managed_node_groups = {

    # Blue Node Group (Primary)
    blue = {
      create             = var.enable_blue                # true (default)
      kubernetes_version = var.eks_nodegroup_blue_version # "" (follows cluster)

      # Multiple instance types for SPOT diversity
      instance_types = [
        "c3.large",  # 2 vCPU, 3.75 GB RAM
        "c4.large",  # 2 vCPU, 3.75 GB RAM
        "c5.large",  # 2 vCPU, 4 GB RAM
        "c5d.large", # 2 vCPU, 4 GB RAM (local NVMe)
        "c5n.large", # 2 vCPU, 5.25 GB RAM (enhanced networking)
        "c5a.large"  # 2 vCPU, 4 GB RAM (AMD)
      ]

      capacity_type = "SPOT" # ~70% cheaper than ON_DEMAND
      min_size      = 2      # Minimum nodes (HA)
      max_size      = 10     # Maximum nodes (autoscaling limit)
      desired_size  = 2      # Starting node count

      labels = { nodegroup = "blue" } # Kubernetes node labels

      # IAM policies for persistent storage
      iam_role_additional_policies = [
        amazonEBS = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        amazonEFS = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
      ]
    }

    # Green Node Group (For Upgrades)
    green = {
      create             = var.enable_green                # false (default)
      kubernetes_version = var.eks_nodegroup_green_version # "" (or "1.32" during upgrade)

      # Same configuration as blue
      instance_types = [
        "c3.large", "c4.large", "c5.large",
        "c5d.large", "c5n.large", "c5a.large"
      ]
      capacity_type = "SPOT"
      min_size      = 2
      max_size      = 10
      desired_size  = 2

      labels = { nodegroup = "green" }

      iam_role_additional_policies = [
        amazonEBS = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        amazonEFS = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
      ]
    }
  }

  # ── Tagging ─────────────────────────────────────────────
  cluster_tags = local.common_tags
}
