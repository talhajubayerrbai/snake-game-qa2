terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------------------------------------------------
# Default VPC
# -------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# -------------------------------------------------------------------
# SSH key pair — public key provided by CI (generated in UDAP vault)
# -------------------------------------------------------------------
resource "aws_key_pair" "snake" {
  key_name   = "snake-game-qa2-key"
  public_key = var.ssh_public_key
}

# -------------------------------------------------------------------
# IAM instance profile with SSM access
# -------------------------------------------------------------------
resource "aws_iam_role" "snake" {
  name = "snake-game-qa2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.snake.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "snake" {
  name = "snake-game-qa2-profile"
  role = aws_iam_role.snake.name
}

# -------------------------------------------------------------------
# Security group — 22, 80 inbound; all outbound
# -------------------------------------------------------------------
resource "aws_security_group" "snake" {
  name        = "snake-game-qa2-sg"
  description = "Snake game QA2 security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "snake-game-qa2-sg" }
}

# -------------------------------------------------------------------
# EC2 instance — Amazon Linux 2023, t3.micro
# -------------------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_instance" "snake" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.snake.key_name
  iam_instance_profile   = aws_iam_instance_profile.snake.name
  vpc_security_group_ids = [aws_security_group.snake.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = { Name = "snake-game-qa2" }
}

# -------------------------------------------------------------------
# Elastic IP
# -------------------------------------------------------------------
resource "aws_eip" "snake" {
  instance = aws_instance.snake.id
  tags     = { Name = "snake-game-qa2-eip" }
}
