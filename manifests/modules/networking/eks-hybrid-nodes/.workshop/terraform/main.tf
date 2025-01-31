locals {
  remote_vpc_cidr = "10.50.0.0/16"
}

provider "aws" {
  region = "us-west-2"
  alias  = "remote"
}

data "aws_region" "current" {}

data "aws_vpc" "selected" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }
}

################################################################################
# Remote VPC
################################################################################

# Create VPC in remote region
resource "aws_vpc" "remote" {

  cidr_block           = local.remote_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "remote-vpc"
  })
}

# Create public subnets in remote VPC
resource "aws_subnet" "remote_public" {
  count = 2

  vpc_id            = aws_vpc.remote.id
  cidr_block        = cidrsubnet(local.remote_vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.remote.names[count.index]

  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "remote-public-${count.index + 1}"
  })
}

# Internet Gateway for remote VPC
resource "aws_internet_gateway" "remote" {
  vpc_id = aws_vpc.remote.id

  tags = merge(var.tags, {
    Name = "remote-igw"
  })
}

# Route table for remote public subnets
resource "aws_route_table" "remote_public" {
  vpc_id = aws_vpc.remote.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.remote.id
  }

  tags = merge(var.tags, {
    Name = "remote-public-rt"
  })
}

# Associate route table with public subnets
resource "aws_route_table_association" "remote_public" {
  count = 2

  subnet_id      = aws_subnet.remote_public[count.index].id
  route_table_id = aws_route_table.remote_public.id
}

# Get available AZs in remote region
data "aws_availability_zones" "remote" {
  state = "available"
}


################################################################################
# Psuedo Hybrid Node
# Demonstration only - AWS EC2 instances are not supported for EKS Hybrid nodes
################################################################################

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "~> 2.0"

  key_name           = "hybrid-node"
  create_private_key = true

  tags = var.tags
}

resource "local_file" "key_pem" {
  content         = module.key_pair.private_key_pem
  filename        = "key.pem"
  file_permission = "0600"
}

resource "local_file" "key_pub_pem" {
  content         = module.key_pair.public_key_pem
  filename        = "key_pub.pem"
  file_permission = "0600"
}

resource "local_file" "join" {
  content  = <<-EOT
    #!/usr/bin/env bash

    # Use SCP/SSH to execute commands on the remote host
    scp -i ${local_file.key_pem.filename} nodeConfig.yaml ubuntu@${aws_instance.hybrid_node["one"].public_ip}:/home/ubuntu/nodeConfig.yaml
    ssh -n -i ${local_file.key_pem.filename} ubuntu@${aws_instance.hybrid_node["one"].public_ip} sudo nodeadm init -c file://nodeConfig.yaml
    ssh -n -i ${local_file.key_pem.filename} ubuntu@${aws_instance.hybrid_node["one"].public_ip} sudo systemctl daemon-reload

    scp -i ${local_file.key_pem.filename} nodeConfig.yaml ubuntu@${aws_instance.hybrid_node["two"].public_ip}:/home/ubuntu/nodeConfig.yaml
    ssh -n -i ${local_file.key_pem.filename} ubuntu@${aws_instance.hybrid_node["two"].public_ip} sudo nodeadm init -c file://nodeConfig.yaml
    ssh -n -i ${local_file.key_pem.filename} ubuntu@${aws_instance.hybrid_node["two"].public_ip} sudo systemctl daemon-reload

    # Clean up
    rm nodeConfig.yaml
  EOT
  filename = "join.sh"
}

# Get Ubuntu AMI for the current region
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Define the security group for the hybrid nodes
resource "aws_security_group" "hybrid_nodes" {
  name        = "hybrid-nodes-sg"
  description = "Security group for hybrid EKS nodes"
  vpc_id      = aws_vpc.remote.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Create the EC2 instances
resource "aws_instance" "hybrid_node" {
  for_each = toset(["one", "two"])

  ami           = data.aws_ami.ubuntu.id
  instance_type = "m5.large"
  subnet_id     = aws_subnet.remote_public[0].id
  key_name      = module.key_pair.key_pair_name

  vpc_security_group_ids = [aws_security_group.hybrid_nodes.id]

  user_data = <<-EOF
              #cloud-config
              package_update: true
              packages:
                - unzip

              runcmd:
                - cd /home/
                - echo "Installing AWS CLI..."
                - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                - unzip awscliv2.zip
                - ./aws/install
                - rm awscliv2.zip
                - rm -rf aws/
                - echo "Verifying AWS CLI installation..."
                - aws --version
                
                - echo "Downloading nodeadm..."
                - curl -OL 'https://hybrid-assets.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm'
                - chmod +x nodeadm
                
                - echo "Moving nodeadm to /usr/local/bin"
                - mv nodeadm /usr/local/bin/

                - echo "Installing nodeadm..."
                - nodeadm install 1.31 --credential-provider ssm
                
                - echo "Verifying installations..."
                - nodeadm --version
                - kubectl version --client
              EOF

  tags = merge(var.tags, {
    Name = "hybrid-node-${each.key}"
  })
}

