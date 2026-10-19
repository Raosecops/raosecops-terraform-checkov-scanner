# Define the core Virtual Private Cloud (VPC) for our secure architecture
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


# Create a public subnet inside our core VPC
resource "aws_subnet" "raosecops_subnet_public" {
  vpc_id                  = aws_vpc.raosecops_vpc_core.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name        = "raosecops-subnet-public"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Create a security group with an INTENTIONAL security flaw for our scanner to catch
resource "aws_security_group" "raosecops_sg_flawed" {
  name        = "raosecops-sg-flawed"
  description = "Security group with intentional SSH exposure for security testing"
  vpc_id      = aws_vpc.raosecops_vpc_core.id

  # INSECURE RULE: Opening SSH (port 22) to the entire internet (0.0.0.0/0)
  ingress {
    description = "Allow SSH from anywhere - INSECURE"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  tags = {
    Name        = "raosecops-sg-flawed"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
