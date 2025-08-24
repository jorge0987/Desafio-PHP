# Main Terraform Configuration
terraform {
  required_version = ">= 1.0"

  # Uncomment for remote state (recommended for production)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "eks-laravel-demo/terraform.tfstate"
  #   region = "us-east-1"
  #   encrypt = true
  #   dynamodb_table = "terraform-lock-table"
  # }
}

# Local values for computed configurations
locals {
  name = var.cluster_name

  # Tags to be applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = "jorge-devops-demo"
    Purpose     = "eks-laravel-demo"
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }

  # Cluster configuration is now in eks.tf

  # Node group configuration
  node_group_defaults = {
    instance_types = var.node_group_instance_types
    capacity_type  = var.use_spot_instances ? "SPOT" : "ON_DEMAND"

    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
    desired_size = var.node_group_desired_size

    disk_size = var.node_group_disk_size
    ami_type  = "AL2_x86_64"

    labels = {
      Environment = var.environment
      Project     = var.project_name
    }

    # Instance metadata options for security
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "disabled"
    }

    # Update configuration
    update_config = {
      max_unavailable_percentage = 25
    }
  }
}

# Resource dependencies and data sources
data "aws_region" "current" {}
data "aws_partition" "current" {}
