locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Terraform   = "true"
  }
  resource_name = "${var.project}-${var.environment}"
  active_node_groups = {
    for k, v in var.eks_managed_node_groups : k => v if v.create
  }

  node_additional_policies = {
    for arn in distinct(flatten([
      for ng in values(var.eks_managed_node_groups) : vales(ng.iam_role_additional_policies)
    ])) : arn => arn


  }
}
