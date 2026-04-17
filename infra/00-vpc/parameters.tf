resource "aws_ssm_parameter" "parameters" {
  for_each = local.ssm_parameters
  name     = each.value.name
  type     = each.value.type
  value    = each.value.value
}
