terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  required_version = ">= 1.2"
}

provider "aws" {
  region = "eu-west-3"
}

# --------------------------------------------------------
# 1. AMI DYNAMIQUE (Ubuntu 24.04 LTS)
# --------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# --------------------------------------------------------
# 2. CLE SSH GENEREE A LA VOLEE
# --------------------------------------------------------
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "app-deployer-key"
  public_key = tls_private_key.deployer.public_key_openssh
}

# --------------------------------------------------------
# 3. SECURITY GROUP
# --------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Security group pour application"

  # SSH (Ansible uniquement)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend (public)
  ingress {
    description = "Frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API (public)
  ingress {
    description = "Backend API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Adminer (administration DB)
  ingress {
    description = "Adminer"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sortie libre
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------------------------------------------
# 4. INSTANCE EC2
# --------------------------------------------------------
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "App-Production-Server"
  }
}

# --------------------------------------------------------
# 5. OUTPUTS (pour le Bridge CI/CD)
# --------------------------------------------------------
output "instance_ip" {
  description = "IP publique du serveur applicatif"
  value       = aws_instance.app_server.public_ip
}

output "private_key_pem" {
  description = "Cle privee SSH pour Ansible"
  value       = tls_private_key.deployer.private_key_pem
  sensitive   = true
}
