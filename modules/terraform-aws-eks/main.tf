resource "aws_eks_cluster" "main" {
  name     = local.resource_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = var.cluster_security_group_ids
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  tags = merge(
    local.common_tags,
    { Name = local.resource_name },
    var.cluster_tags
  )
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

}
resource "aws_launch_template" "node" {
  for_each = local.active_node_groups

  name                   = "${local.resource_name}-${each.key}-lt"
  vpc_security_group_ids = var.node_security_group_ids

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name      = "${local.resource_name}-${each.key}-node"
        NodeGroup = each.key
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name      = "${local.resource_name}-${each.key}-volume"
        NodeGroup = each.key
      }
    )
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.resource_name}-${each.key}-lt" }
  )

}
