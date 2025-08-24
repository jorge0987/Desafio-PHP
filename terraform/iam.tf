# IAM Role for EKS Cluster Service Account (IRSA)
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# EBS CSI Driver IRSA Role
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.project_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Name = "${var.project_name}-ebs-csi-driver-role"
  }
}

# AWS Load Balancer Controller IRSA Role
module "alb_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${var.project_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name = "${var.project_name}-alb-controller-role"
  }
}

# Cluster Autoscaler IRSA Role
module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "${var.project_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = {
    Name = "${var.project_name}-cluster-autoscaler-role"
  }
}

# CloudWatch Agent IRSA Role
module "cloudwatch_agent_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-cloudwatch-agent"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }

  tags = {
    Name = "${var.project_name}-cloudwatch-agent-role"
  }
}

# ECR Read Access Role for Nodes (additional)
resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = module.eks.eks_managed_node_groups["main"].iam_role_name

  depends_on = [module.eks]
}

# Additional CloudWatch permissions for nodes
resource "aws_iam_policy" "node_cloudwatch_policy" {
  name        = "${var.project_name}-node-cloudwatch-policy"
  description = "Additional CloudWatch permissions for EKS nodes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_cloudwatch" {
  policy_arn = aws_iam_policy.node_cloudwatch_policy.arn
  role       = module.eks.eks_managed_node_groups["main"].iam_role_name

  depends_on = [module.eks]
}

# Laravel Application Service Account Role (for accessing AWS services if needed)
# Commented out temporarily for infrastructure cleanup
/*
module "laravel_app_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-laravel-app"

  # Custom policy for Laravel app (can be extended)
  role_policy_arns = {
    policy = aws_iam_policy.laravel_app_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["laravel-demo:laravel-app-sa"]
    }
  }

  tags = {
    Name = "${var.project_name}-laravel-app-role"
  }
}

# Laravel App Custom Policy (minimal permissions)
resource "aws_iam_policy" "laravel_app_policy" {
  name        = "${var.project_name}-laravel-app-policy"
  description = "Policy for Laravel application"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
*/
