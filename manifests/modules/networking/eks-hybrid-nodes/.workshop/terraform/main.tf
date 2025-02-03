data "aws_availability_zones" "available" {}

locals {
  name   = "${var.eks_cluster_id}-remote"
  azs    = slice(data.aws_availability_zones.available.names, 0, 1)
  remote_vpc_cidr = "10.50.0.0/16"
  vpc_cidr = "10.42.0.0/16"
  instance_type = "m5.large"
}

data "aws_region" "current" {}

data "aws_vpc" "cluster" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }
}

data "aws_subnets" "cluster_private" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }

  filter {
    name   = "tag:Name"
    values = ["*Private*"]
  }
}

data "aws_subnets" "cluster_public" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }

  filter {
    name   = "tag:Name"
    values = ["*Public*"]
  }
}

data "aws_route_table" "cluster_private" {
  subnet_id = data.aws_subnets.cluster_private[0].id
}

################################################################################
# Remote VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-remote"
  cidr = local.remote_vpc_cidr
  azs  = [local.azs

  public_subnets =  [cidrsubnet(local.remote_vpc_cidr, 4, 0)]
  private_subnets = [cidrsubnet(local.remote_vpc_cidr, 4, 1)]     

  enable_nat_gateway = true
  single_nat_gateway = true
  
  tags = var.tags
}

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "~> 2.0"

  name        = "{$local.name}-hybrid-tgw"
  description = "TGW between cluster and remote vpc"

  enable_auto_accept_shared_attachments = true

  vpc_attachments = {
    remote_vpc = {
      vpc_id       = module.vpc.vpc_id
      subnet_ids   = [ module.vpc.public_subnets[0].id ]
      dns_support  = true
      ipv6_support = true

      tgw_routes = [
        {
          destination_cidr_block = local.remote_vpc_cidr
        }
      ]
    }

    cluster_vpc = {
      vpc_id       = data.aws_vpc.cluster.vpc_id
      subnet_ids   = [ data.aws_subnets.cluster_public ]
      dns_support  = true
      ipv6_support = true

      tgw_routes = [
        {
          destination_cidr_block = local.vpc_cidr
        }
      ]

    }
  }

  tags = var.tags
}



resource "aws_route" "remote_node_private" {
  route_table_id            = one(module.vpc.public_route_table_ids)
  destination_cidr_block    = local.vpc_cidr
  transit_gateway_id        = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "to_remote_node" {
  route_table_id            = data.aws_route_table.cluster_private[0]
  destination_cidr_block    = local.remote_vpc_cidr
  transit_gateway_id        = module.tgw.ec2_transit_gateway_id
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

data "aws_ami" "ubuntu" {
  name_regex  = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server--*"
  most_recent = true

  owners = ["099720109477"] 
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

resource "aws_vpc_security_group_ingress_rule" "from_cluster" {
  cidr_ipv4                    = local.vpc_cidr
  ip_protocol                  = "all"
  security_group_id            = aws_security_group.hybrid_nodes.id

}

resource "aws_vpc_security_group_ingress_rule" "remote_node" {
  
  cidr_ipv4                    = local.remote_vpc_cidr
  ip_protocol                  = "all"
  security_group_id            = aws_security_group.hybrid_nodes.id
  
}

# Create the EC2 instances
resource "aws_instance" "hybrid_nodes" {

  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = local.instance_type
  key_name      = module.key_pair.key_pair_name

  # If not using user-data, block IMDS to make instance look less like EC2 and more like vanilla VM
  metadata_options {
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  source_dest_check = false

  vpc_security_group_ids = [aws_security_group.hybrid_nodes.id]
  subnet_id              = module.vpc.public_subnets[0]

  user_data = <<-EOF
              sudo apt-get update -y

              curl "https://hybrid-assets.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm" -o /usr/local/bin/nodeadm 
              chmod +x /usr/local/bin/nodeadm
              /usr/local/bin/nodeadm install "${var.eks_cluster_version}" --credential-provider "ssm"
           
              EOF

  tags = merge(
    var.tags,
    { Name = "hybrid-node-1" }
  )
}

module "eks_hybrid_node_role" {
  source  = "terraform-aws-modules/eks/aws//modules/hybrid-node-role"
  version = "~> 20.31"
  tags = local.tags
}

resource "aws_eks_access_entry" "karpenter" {
  cluster_name    = var.eks_cluster_id
  principal_arn = module.eks_hybrid_node_role.arn
  type          = "HYBRID_LINUX"
}