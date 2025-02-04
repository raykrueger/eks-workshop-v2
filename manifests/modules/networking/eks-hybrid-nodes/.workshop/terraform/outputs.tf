output "environment_variables" {
  description = "Environment variables to be added to the IDE shell"
  value = merge({
    VPC_ID                        = data.aws_vpc.cluster.id
    EKS_CLUSTER_SECURITY_GROUP_ID = var.cluster_security_group_id
    HYBRID_ROLE_ARN               = module.eks_hybrid_node_role.arn
    EC2_HYBRID_PRIVATE_KEY_PEM    = module.key_pair.private_key_pem
  })
}
