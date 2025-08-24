# ==========================================
# EKS Add-ons - Managed by eks.tf module
# ==========================================
# Note: Core EKS addons (vpc-cni, kube-proxy, coredns, aws-ebs-csi-driver) 
# are now managed by the cluster_addons configuration in eks.tf

# AWS Load Balancer Controller (essential for ingress)
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_alb_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa_role.iam_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    module.eks.eks_managed_node_groups,
    module.alb_controller_irsa_role
  ]
}

# ==========================================
# Add-ons Configuration Complete
# ==========================================
# All Kubernetes resources will be managed via Helm charts in CI/CD
# This keeps Terraform focused on infrastructure provisioning
