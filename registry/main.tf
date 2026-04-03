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
resource "tls_private_key" "registry" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "registry" {
  key_name   = "registry-deployer-key"
  public_key = tls_private_key.registry.public_key_openssh
}

# --------------------------------------------------------
# 3. SECURITY GROUP
# --------------------------------------------------------
resource "aws_security_group" "registry_sg" {
  name        = "registry-sg"
  description = "Security group pour le registre Docker"

  # SSH (Ansible uniquement)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (registre Docker)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
resource "aws_instance" "registry_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.registry.key_name

  vpc_security_group_ids = [aws_security_group.registry_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Docker-Registry-Server"
  }
}

# --------------------------------------------------------
# 5. OUTPUTS
# --------------------------------------------------------
output "registry_ip" {
  description = "IP publique du serveur de registre"
  value       = aws_instance.registry_server.public_ip
}

output "private_key_pem" {
  description = "Cle privee SSH pour Ansible"
  value       = tls_private_key.registry.private_key_pem
  sensitive   = true
}
