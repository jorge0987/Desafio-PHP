#!/bin/bash

# =============================================================================
# EKS Infrastructure Deployment Script
# =============================================================================
# Purpose: Deploy complete EKS infrastructure for Laravel demo
# Author: Jorge DevOps Demo
# Date: August 2025
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}"
PROJECT_NAME="laravel-eks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    log_success "All prerequisites are satisfied"
}

# Function to show current AWS configuration
show_aws_config() {
    log_info "Current AWS Configuration:"
    aws_identity=$(aws sts get-caller-identity)
    account_id=$(echo "$aws_identity" | jq -r '.Account')
    user_arn=$(echo "$aws_identity" | jq -r '.Arn')
    region=$(aws configure get region)
    
    echo "  Account ID: $account_id"
    echo "  User/Role:  $user_arn"
    echo "  Region:     $region"
    echo
}

# Function to estimate costs
show_cost_estimate() {
    log_info "Estimated AWS Costs (monthly):"
    echo "  EKS Control Plane:  \$72.00"
    echo "  EC2 t3.medium (2x): \$60.00 (on-demand) / \$18.00 (spot)"
    echo "  ALB Load Balancer:  \$16.20"
    echo "  EBS Volumes (40GB): \$4.00"
    echo "  Data Transfer:      \$5.00"
    echo "  ────────────────────────────"
    echo "  Total (spot):       ~\$115/month"
    echo "  Total (on-demand):  ~\$157/month"
    echo
    echo "  For demo (3-5 days): \$15-25"
    echo
}

# Function to initialize Terraform
terraform_init() {
    log_info "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    
    terraform init
    
    log_success "Terraform initialized"
}

# Function to plan Terraform deployment
terraform_plan() {
    log_info "Planning Terraform deployment..."
    cd "$TERRAFORM_DIR"
    
    terraform plan -out=tfplan
    
    log_success "Terraform plan completed. Review the plan above."
}

# Function to apply Terraform deployment
terraform_apply() {
    log_info "Applying Terraform deployment..."
    cd "$TERRAFORM_DIR"
    
    # Apply with plan file
    terraform apply tfplan
    
    log_success "Infrastructure deployed successfully!"
}

# Function to configure kubectl
configure_kubectl() {
    log_info "Configuring kubectl for EKS cluster..."
    cd "$TERRAFORM_DIR"
    
    # Get cluster name from Terraform output
    cluster_name=$(terraform output -raw cluster_name)
    region=$(aws configure get region || echo "us-east-1")
    
    # Update kubeconfig
    aws eks --region "$region" update-kubeconfig --name "$cluster_name"
    
    # Test connection
    log_info "Testing cluster connection..."
    kubectl get nodes
    
    log_success "kubectl configured successfully"
}

# Function to get ECR login
get_ecr_login() {
    log_info "Getting ECR login commands..."
    cd "$TERRAFORM_DIR"
    
    # Get ECR login command from Terraform output
    ecr_login_cmd=$(terraform output -raw ecr_login_command)
    
    echo "ECR Login Command:"
    echo "$ecr_login_cmd"
    echo
    
    # Execute ECR login
    eval "$ecr_login_cmd"
    
    log_success "ECR login completed"
}

# Function to show important outputs
show_outputs() {
    log_info "Important Infrastructure Information:"
    cd "$TERRAFORM_DIR"
    
    echo "Cluster Information:"
    terraform output cluster_name
    terraform output cluster_endpoint
    echo
    
    echo "ECR Repositories:"
    terraform output ecr_repository_laravel_fpm
    terraform output ecr_repository_laravel_swoole
    echo
    
    echo "Connection Commands:"
    terraform output configure_kubectl
    echo
    terraform output ecr_login_command
    echo
    
    log_info "Registry URLs:"
    terraform output registry_urls
}

# Function to validate deployment
validate_deployment() {
    log_info "Validating deployment..."
    
    # Check if cluster is accessible
    if kubectl get nodes &> /dev/null; then
        log_success "Cluster is accessible"
    else
        log_error "Cannot access cluster"
        return 1
    fi
    
    # Check if required namespaces exist
    if kubectl get namespace laravel-demo &> /dev/null; then
        log_success "laravel-demo namespace exists"
    else
        log_warning "laravel-demo namespace not found"
    fi
    
    # Check if load balancer controller is running
    if kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller &> /dev/null; then
        log_success "AWS Load Balancer Controller is deployed"
    else
        log_warning "AWS Load Balancer Controller not found"
    fi
    
    # Check if metrics server is running
    if kubectl get pods -n kube-system -l k8s-app=metrics-server &> /dev/null; then
        log_success "Metrics Server is deployed"
    else
        log_warning "Metrics Server not found"
    fi
    
    log_success "Deployment validation completed"
}

# Function to destroy infrastructure
destroy_infrastructure() {
    log_warning "⚠️  COMPLETE INFRASTRUCTURE DESTRUCTION ⚠️"
    echo
    log_warning "This will destroy ALL AWS resources created by this Terraform:"
    echo "  🔥 EKS Cluster (laravel-demo)"
    echo "  🔥 VPC and all networking components"
    echo "  🔥 ECR Repositories and all container images"
    echo "  🔥 IAM Roles and policies"
    echo "  🔥 Security Groups"
    echo "  🔥 Load Balancers (ALB)"
    echo "  🔥 EBS Volumes"
    echo "  🔥 KMS Keys"
    echo "  🔥 CloudWatch Log Groups"
    echo
    log_warning "💰 This will STOP all AWS charges immediately!"
    echo
    
    # Show current costs if terraform is initialized
    if [ -f "$TERRAFORM_DIR/.terraform.lock.hcl" ]; then
        log_info "Current infrastructure will cost ~\$3-5/day if left running"
        echo
    fi
    
    read -p "❌ Type 'DESTROY' in capital letters to confirm complete destruction: " confirm
    
    if [ "$confirm" = "DESTROY" ]; then
        log_info "🚀 Starting complete infrastructure destruction..."
        cd "$TERRAFORM_DIR"
        
        # Pre-destruction cleanup
        log_info "Step 1: Cleaning up kubectl context..."
        kubectl config unset current-context 2>/dev/null || true
        kubectl config delete-cluster "laravel-demo" 2>/dev/null || true
        
        # Destroy with detailed output
        log_info "Step 2: Destroying Terraform resources..."
        log_warning "This will take 10-15 minutes..."
        
        if terraform destroy -auto-approve; then
            log_success "✅ All Terraform resources destroyed successfully!"
        else
            log_error "❌ Terraform destroy failed. Manual cleanup may be required."
            log_info "Check AWS Console for remaining resources."
            return 1
        fi
        
        # Post-destruction cleanup
        log_info "Step 3: Cleaning up local files..."
        
        # Remove terraform state and plan files
        rm -f terraform.tfstate*
        rm -f tfplan
        rm -f .terraform.tfstate.lock.info
        
        # Remove generated key files
        rm -f eks-nodes-key.pem*
        
        log_info "Step 4: Verifying cleanup..."
        
        # Verify no major resources remain (optional check)
        if command -v aws &> /dev/null; then
            log_info "Checking for remaining EKS clusters..."
            remaining_clusters=$(aws eks list-clusters --query 'clusters[?contains(@, `laravel`)]' --output text 2>/dev/null || echo "")
            
            if [ -n "$remaining_clusters" ]; then
                log_warning "⚠️  Found remaining EKS clusters: $remaining_clusters"
                log_warning "Manual cleanup may be needed in AWS Console"
            else
                log_success "✅ No EKS clusters found - cleanup successful"
            fi
            
            log_info "Checking for remaining ECR repositories..."
            remaining_repos=$(aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `laravel-eks`)].repositoryName' --output text 2>/dev/null || echo "")
            
            if [ -n "$remaining_repos" ]; then
                log_warning "⚠️  Found remaining ECR repositories: $remaining_repos"
                log_info "These will not incur charges but can be manually deleted if desired"
            else
                log_success "✅ No ECR repositories found - cleanup successful"
            fi
        fi
        
        log_success "🎉 COMPLETE DESTRUCTION SUCCESSFUL!"
        echo
        log_success "💰 All AWS charges have been stopped"
        log_success "🧹 Local files cleaned up"
        log_success "⚡ Ready for fresh deployment"
        echo
        log_info "To deploy again, run: ./deploy.sh deploy"
        
    else
        log_info "❌ Destruction cancelled - infrastructure preserved"
        log_info "💡 You typed: '$confirm' (required: 'DESTROY')"
    fi
}

# Emergency cleanup function for stuck resources
emergency_cleanup() {
    log_warning "🚨 EMERGENCY CLEANUP MODE 🚨"
    echo
    log_warning "This will attempt to force-delete stuck AWS resources"
    log_warning "Use this if normal destroy failed and resources are stuck"
    echo
    
    read -p "⚠️  Type 'EMERGENCY' to confirm emergency cleanup: " confirm
    
    if [ "$confirm" = "EMERGENCY" ]; then
        log_info "🚀 Starting emergency cleanup..."
        
        if command -v aws &> /dev/null; then
            # Force delete EKS cluster if exists
            log_info "Checking for EKS clusters..."
            clusters=$(aws eks list-clusters --query 'clusters[?contains(@, `laravel`)]' --output text 2>/dev/null || echo "")
            
            for cluster in $clusters; do
                log_warning "Force deleting EKS cluster: $cluster"
                aws eks delete-cluster --name "$cluster" 2>/dev/null || true
            done
            
            # Force delete ECR repositories with images
            log_info "Checking for ECR repositories..."
            repos=$(aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `laravel-eks`)].repositoryName' --output text 2>/dev/null || echo "")
            
            for repo in $repos; do
                log_warning "Force deleting ECR repository: $repo"
                aws ecr delete-repository --repository-name "$repo" --force 2>/dev/null || true
            done
            
            # Clear terraform state
            log_info "Clearing Terraform state..."
            cd "$TERRAFORM_DIR"
            rm -f terraform.tfstate*
            rm -f .terraform.tfstate.lock.info
            rm -f tfplan
            
            log_success "🧹 Emergency cleanup completed"
            log_warning "⚠️  Some resources may still exist - check AWS Console"
            
        else
            log_error "AWS CLI not available for emergency cleanup"
        fi
    else
        log_info "Emergency cleanup cancelled"
    fi
}

# Function to check current AWS resource status
check_aws_resources() {
    log_info "🔍 Checking current AWS resources..."
    echo
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not available"
        return 1
    fi
    
    # Check EKS clusters
    log_info "EKS Clusters:"
    clusters=$(aws eks list-clusters --query 'clusters[?contains(@, `laravel`)]' --output table 2>/dev/null || echo "None found")
    echo "$clusters"
    echo
    
    # Check ECR repositories  
    log_info "ECR Repositories:"
    repos=$(aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `laravel-eks`)].{Name:repositoryName,URI:repositoryUri,Created:createdAt}' --output table 2>/dev/null || echo "None found")
    echo "$repos"
    echo
    
    # Check VPCs with laravel tag
    log_info "VPCs (with laravel tags):"
    vpcs=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=laravel-eks" --query 'Vpcs[].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}' --output table 2>/dev/null || echo "None found")
    echo "$vpcs"
    echo
    
    # Estimate current costs if resources exist
    if aws eks list-clusters --query 'clusters[?contains(@, `laravel`)]' --output text 2>/dev/null | grep -q laravel; then
        log_warning "💰 Current estimated daily cost: \$3-5"
        log_warning "💰 Monthly cost if left running: \$115-157"
        echo
        log_info "💡 Run './deploy.sh destroy' to stop all charges"
    else
        log_success "✅ No AWS resources found - no charges!"
    fi
}

# Main menu function
show_menu() {
    echo
    echo "=== EKS Laravel Demo - Infrastructure Management ==="
    echo "1. Check Prerequisites"
    echo "2. Show AWS Configuration"
    echo "3. Show Cost Estimate"
    echo "4. Initialize Terraform"
    echo "5. Plan Deployment"
    echo "6. Deploy Infrastructure"
    echo "7. Configure kubectl"
    echo "8. Get ECR Login"
    echo "9. Show Outputs"
    echo "10. Validate Deployment"
    echo "11. Full Deploy (2-9)"
    echo "12. 🔥 Destroy Infrastructure"
    echo "13. 🚨 Emergency Cleanup"
    echo "14. 🔍 Check AWS Resources"
    echo "0. Exit"
    echo
}

# Full deployment function
full_deploy() {
    log_info "Starting full deployment..."
    
    check_prerequisites
    show_aws_config
    show_cost_estimate
    
    read -p "Continue with deployment? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Deployment cancelled"
        return
    fi
    
    terraform_init
    terraform_plan
    
    read -p "Apply this plan? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Deployment cancelled"
        return
    fi
    
    terraform_apply
    configure_kubectl
    get_ecr_login
    show_outputs
    validate_deployment
    
    log_success "Full deployment completed successfully!"
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Choose an option: " choice
            
            case $choice in
                1) check_prerequisites ;;
                2) show_aws_config ;;
                3) show_cost_estimate ;;
                4) terraform_init ;;
                5) terraform_plan ;;
                6) terraform_apply ;;
                7) configure_kubectl ;;
                8) get_ecr_login ;;
                9) show_outputs ;;
                10) validate_deployment ;;
                11) full_deploy ;;
                12) destroy_infrastructure ;;
                13) emergency_cleanup ;;
                14) check_aws_resources ;;
                0) log_info "Goodbye!"; exit 0 ;;
                *) log_error "Invalid option" ;;
            esac
            
            read -p "Press Enter to continue..."
        done
    else
        # Command line mode
        case $1 in
            "init") terraform_init ;;
            "plan") terraform_plan ;;
            "apply") terraform_apply ;;
            "deploy") full_deploy ;;
            "destroy") destroy_infrastructure ;;
            "emergency") emergency_cleanup ;;
            "validate") validate_deployment ;;
            "outputs") show_outputs ;;
            "status") check_aws_resources ;;
            *) 
                echo "Usage: $0 [init|plan|apply|deploy|destroy|emergency|validate|outputs|status]"
                echo "  or run without arguments for interactive mode"
                echo
                echo "Commands:"
                echo "  init      - Initialize Terraform"
                echo "  plan      - Plan deployment"  
                echo "  apply     - Apply infrastructure"
                echo "  deploy    - Full automated deployment"
                echo "  destroy   - Destroy all infrastructure"
                echo "  emergency - Emergency cleanup for stuck resources"
                echo "  validate  - Validate deployment"
                echo "  outputs   - Show terraform outputs"
                echo "  status    - Check current AWS resources and costs"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"
