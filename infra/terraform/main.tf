terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------
# VPC
# ---------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "trend-vpc"
  }
}

# ---------------------------
# Public Subnet
# ---------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "trend-public-subnet"
  }
}

# ---------------------------
# Internet Gateway
# ---------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "trend-igw"
  }
}

# ---------------------------
# Route Table for Public Subnet
# ---------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "trend-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------
# Security Group for Jenkins
# ---------------------------
resource "aws_security_group" "jenkins_sg" {
  name        = "trend-jenkins-sg"
  description = "Allow SSH and Jenkins"
  vpc_id      = aws_vpc.main.id

  # Jenkins UI
  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "trend-jenkins-sg"
  }
}

# ---------------------------
# EC2 instance with Jenkins (Ubuntu)
# ---------------------------
resource "aws_instance" "jenkins" {
  ami                    = "ami-0ecb62995f68bb549"   # Your Ubuntu AMI
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = "dev-sg"                  # Your key pair name in AWS

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y git curl unzip docker.io fontconfig openjdk-17-jre

              systemctl enable docker
              systemctl start docker

              # Jenkins repo & key
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
                /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

              echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
                > /etc/apt/sources.list.d/jenkins.list

              apt-get update -y
              apt-get install -y jenkins

              systemctl enable jenkins
              systemctl start jenkins

              usermod -aG docker jenkins
              EOF

  tags = {
    Name = "trend-jenkins-server"
  }
}

# ---------------------------
# Outputs
# ---------------------------
output "jenkins_public_ip" {
  description = "Public IP of Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

