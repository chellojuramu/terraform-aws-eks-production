module "vpc" {
  source = "git::https://github.com/chellojuramu/terraform-aws-eks-production.git//modules/terraform-aws-vpc?ref=main"

  project             = var.project
  environment         = var.environment
  is_peering_required = true
}
