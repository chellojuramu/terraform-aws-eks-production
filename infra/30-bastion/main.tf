resource "aws_instance" "bastion" {
  ami                    = local.ami.id
  instance_type          = "t3.micro"
  subnet_id              = local.public_subnet_id
  vpc_security_group_ids = [local.bastion_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name
  user_data              = file("bastion.sh")

  root_block_device {
    volume_size = 50
    volume_type = "gp3"

    tags = merge(
      {
        Name = "${var.project}-${var.environment}-bastion"
      },
      local.common_tags
    )
  }

  tags = merge(
    {
      Name = "${var.project}-${var.environment}-bastion"
    },
    local.common_tags
  )

}

resource "aws_iam_role" "bastion" {
  name = "RoboShopDevBastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "RoboShopDevBastion"
    },
    local.common_tags
  )
}
resource "aws_iam_role_policy_attachment" "bastion" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project}-${var.environment}-bastion"
  role = aws_iam_role.bastion.name

}
