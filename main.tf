provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "raosecops_vpc_core" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "raosecops-vpc-core"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.raosecops_vpc_core.id

  ingress = []
  egress  = []
}

# KMS Key for CloudWatch Log Group Encryption
resource "aws_kms_key" "logs_key" {
  description             = "KMS key for VPC flow logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# Remediated: Explicit KMS Key Policy (CKV2_AWS_64)
resource "aws_kms_key_policy" "logs_key_policy" {
  key_id = aws_kms_key.logs_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.us-east-1.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  name              = "/aws/vpc/raosecops-flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs_key.arn
}

resource "aws_flow_log" "raosecops_flow_log" {
  vpc_id          = aws_vpc.raosecops_vpc_core.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.flow_log_group.arn
}

resource "aws_iam_role" "flow_log_role" {
  name = "raosecops-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "raosecops-vpc-flow-log-policy"
  role = aws_iam_role.flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.flow_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_subnet" "raosecops_subnet_public" {
  vpc_id                  = aws_vpc.raosecops_vpc_core.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name        = "raosecops-subnet-public"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "raosecops_sg_secure" {
  name        = "raosecops-sg-secure"
  description = "Security group with restricted SSH access"
  vpc_id      = aws_vpc.raosecops_vpc_core.id

  ingress {
    description = "Allow SSH from internal corporate CIDR only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name        = "raosecops-sg-secure"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_network_interface" "raosecops_nic" {
  subnet_id       = aws_subnet.raosecops_subnet_public.id
  security_groups = [aws_security_group.raosecops_sg_secure.id]

  tags = {
    Name = "raosecops-nic"
  }
}
