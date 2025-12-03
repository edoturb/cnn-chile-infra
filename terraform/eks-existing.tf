# Configuration for using existing EKS cluster
# This file provides data sources to reference the existing EKS cluster
# created manually in the AWS console

# Uncomment these data sources if you want to use the existing cluster
# instead of creating a new one. You'll also need to comment out the
# resource blocks in eks.tf

/*
# Reference the existing EKS cluster
data "aws_eks_cluster" "existing" {
  name = "confused-bluegrass-walrus"
}

data "aws_eks_cluster_auth" "existing" {
  name = "confused-bluegrass-walrus"
}

# Reference existing IAM roles
data "aws_iam_role" "eks_cluster_existing" {
  name = "c181773a4680376l11910160t1w220017-LabEksClusterRole-EAL858VZhhsq"
}

data "aws_iam_role" "eks_node_existing" {
  name = "LabRole"
}

# Output the existing cluster information
output "existing_cluster_endpoint" {
  description = "Endpoint of the existing EKS cluster"
  value       = data.aws_eks_cluster.existing.endpoint
}

output "existing_cluster_security_group_id" {
  description = "Security group ID of the existing EKS cluster"
  value       = data.aws_eks_cluster.existing.vpc_config[0].cluster_security_group_id
}

output "existing_cluster_arn" {
  description = "ARN of the existing EKS cluster"
  value       = data.aws_eks_cluster.existing.arn
}

output "existing_cluster_certificate_authority" {
  description = "Certificate authority data of the existing EKS cluster"
  value       = data.aws_eks_cluster.existing.certificate_authority[0].data
  sensitive   = true
}

output "existing_cluster_name" {
  description = "Name of the existing EKS cluster"
  value       = data.aws_eks_cluster.existing.name
}

output "existing_cluster_version" {
  description = "Kubernetes version of the existing EKS cluster"
  value       = data.aws_eks_cluster.existing.version
}

output "existing_cluster_role_arn" {
  description = "IAM role ARN of the existing EKS cluster"
  value       = data.aws_iam_role.eks_cluster_existing.arn
}

output "existing_node_role_arn" {
  description = "IAM role ARN for existing EKS nodes"
  value       = data.aws_iam_role.eks_node_existing.arn
}

# To use the existing cluster, update main.tf providers to use these data sources:
#
# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.existing.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.existing.token
# }
#
# provider "helm" {
#   kubernetes {
#     host                   = data.aws_eks_cluster.existing.endpoint
#     cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
#     token                  = data.aws_eks_cluster_auth.existing.token
#   }
# }
*/

# Instructions for using existing cluster:
# 1. Uncomment the data sources and outputs above
# 2. Comment out the resource blocks in eks.tf that create:
#    - aws_iam_role.eks_cluster
#    - aws_iam_role.eks_node_group
#    - aws_eks_cluster.main
#    - aws_eks_node_group.main
#    - aws_launch_template.eks_nodes
#    - Related policy attachments
# 3. Update references in other files to use:
#    - data.aws_eks_cluster.existing instead of aws_eks_cluster.main
#    - data.aws_iam_role.eks_cluster_existing instead of aws_iam_role.eks_cluster
#    - data.aws_iam_role.eks_node_existing instead of aws_iam_role.eks_node_group
# 4. Run: terraform plan -var-file="terraform.tfvars"
# 5. If the plan looks correct, apply: terraform apply -var-file="terraform.tfvars"
