# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# EKS Cluster Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = module.eks.cluster_platform_version
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = module.eks.oidc_provider_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

# Node Group Outputs
output "node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

# ECR Outputs
output "ecr_repository_laravel_fpm" {
  description = "The ECR repository URL for Laravel FPM"
  value       = aws_ecr_repository.laravel_fpm.repository_url
}

output "ecr_repository_laravel_swoole" {
  description = "The ECR repository URL for Laravel Swoole"
  value       = aws_ecr_repository.laravel_swoole.repository_url
}

output "ecr_repository_prometheus" {
  description = "The ECR repository URL for Prometheus"
  value       = aws_ecr_repository.prometheus.repository_url
}

output "ecr_repository_grafana" {
  description = "The ECR repository URL for Grafana"
  value       = aws_ecr_repository.grafana.repository_url
}

# IAM Role Outputs
output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.alb_controller_irsa_role.iam_role_arn
  depends_on  = [module.eks]
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = module.cluster_autoscaler_irsa_role.iam_role_arn
  depends_on  = [module.eks]
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver"
  value       = module.ebs_csi_irsa_role.iam_role_arn
  depends_on  = [module.eks]
}

# Commented out temporarily for infrastructure cleanup
/*
output "laravel_app_role_arn" {
  description = "IAM role ARN for Laravel Application"
  value       = module.laravel_app_irsa_role.iam_role_arn
  depends_on  = [module.eks]
}
*/

# Kubectl Config Command
output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
}

# ECR Login Commands
output "ecr_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# Registry URLs for easy reference
output "registry_urls" {
  description = "ECR registry URLs for Docker commands"
  value = {
    laravel_fpm    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_repository.laravel_fpm.name}"
    laravel_swoole = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_repository.laravel_swoole.name}"
    prometheus     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_repository.prometheus.name}"
    grafana        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_repository.grafana.name}"
  }
}

# Useful connection information
output "connection_info" {
  description = "Important connection and setup information"
  value = {
    kubectl_config = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
    ecr_login      = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    cluster_name   = module.eks.cluster_name
    region         = var.aws_region
    namespace      = "laravel-demo"
  }
}

# Cost Estimation (approximate)
output "estimated_monthly_cost_usd" {
  description = "Estimated monthly cost in USD (approximate)"
  value = {
    eks_control_plane  = "$72.00"
    ec2_nodes_ondemand = "${var.node_group_desired_size * 30.00}"
    ec2_nodes_spot     = "${var.node_group_desired_size * 9.00}"
    alb                = "$16.20"
    ebs_storage        = "${var.node_group_desired_size * var.node_group_disk_size * 0.10}"
    data_transfer      = "$5.00"
    total_spot         = "${72 + (var.node_group_desired_size * 9) + 16.20 + (var.node_group_desired_size * var.node_group_disk_size * 0.10) + 5}"
    total_ondemand     = "${72 + (var.node_group_desired_size * 30) + 16.20 + (var.node_group_desired_size * var.node_group_disk_size * 0.10) + 5}"
  }
}
