#!/bin/bash
# 🚀 Deploy Laravel Application usando Helm
# Usage: ./scripts/helm-deploy.sh [command] [environment] [version]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COMMAND=${1:-deploy}
ENVIRONMENT=${2:-production}
VERSION=${3:-latest}
NAMESPACE="laravel-demo"
CHART_PATH="./helm/laravel-app"
RELEASE_NAME="laravel-${ENVIRONMENT}"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install Helm 3.x"
        exit 1
    fi
    
    # Check if kubectl is configured
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl is not configured. Please configure kubectl for EKS cluster"
        exit 1
    fi
    
    # Check if namespace exists for deploy command
    if [ "$COMMAND" = "deploy" ]; then
        if ! kubectl get namespace $NAMESPACE &> /dev/null; then
            log_info "Creating namespace: $NAMESPACE"
            kubectl create namespace $NAMESPACE
        fi
    fi
    
    log_success "Prerequisites validated"
}

# Deploy application using Helm
deploy_application() {
    log_info "Deploying Laravel application to $ENVIRONMENT environment..."
    log_info "Version: $VERSION"
    log_info "Namespace: $NAMESPACE"
    log_info "Release: $RELEASE_NAME"
    
    # Prepare Helm values based on environment
    case $ENVIRONMENT in
        "production")
            VALUES_FILE="values.yaml"
            REPLICAS=2
            INGRESS_HOST="laravel-demo.example.com"
            ;;
        "staging")
            VALUES_FILE="values.yaml"
            REPLICAS=1
            INGRESS_HOST="staging.laravel-demo.example.com"
            NAMESPACE="laravel-staging"
            RELEASE_NAME="laravel-staging"
            ;;
        "development")
            VALUES_FILE="values.yaml"
            REPLICAS=1
            INGRESS_HOST="dev.laravel-demo.example.com"
            NAMESPACE="laravel-dev"
            RELEASE_NAME="laravel-dev"
            ;;
        *)
            log_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
    
    # Deploy with Helm
    helm upgrade --install $RELEASE_NAME $CHART_PATH \
        --namespace $NAMESPACE \
        --create-namespace \
        --set image.tag=$VERSION \
        --set app.environment=$ENVIRONMENT \
        --set phpfpm.replicaCount=$REPLICAS \
        --set ingress.hosts[0].host=$INGRESS_HOST \
        --wait \
        --timeout=600s \
        --atomic
    
    if [ $? -eq 0 ]; then
        log_success "✅ Deployment completed successfully!"
    else
        log_error "❌ Deployment failed!"
        exit 1
    fi
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Wait for pods to be ready
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/instance=$RELEASE_NAME \
        -n $NAMESPACE \
        --timeout=300s
    
    # Check deployment status
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME
    kubectl get services -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME
    kubectl get ingress -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME
    
    # Get ALB URL
    INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    
    if [ "$INGRESS_HOST" != "pending" ] && [ -n "$INGRESS_HOST" ]; then
        log_success "🌐 Application URL: http://$INGRESS_HOST"
        log_info "Health check: http://$INGRESS_HOST/health"
        
        # Test health endpoint
        log_info "Testing health endpoint..."
        for i in {1..30}; do
            if curl -f -s "http://$INGRESS_HOST/health" > /dev/null 2>&1; then
                log_success "✅ Health check passed!"
                break
            else
                log_info "⏳ Waiting for ALB to be ready... ($i/30)"
                sleep 10
            fi
        done
    else
        log_warning "⏳ ALB is still provisioning. Check AWS console for updates."
    fi
}

# Check release status
check_status() {
    log_info "📊 Checking status for release: $RELEASE_NAME in namespace: $NAMESPACE"
    
    # Check if release exists
    if helm list --namespace "$NAMESPACE" -q 2>/dev/null | grep -q "^${RELEASE_NAME}$"; then
        log_success "Release found! Getting status..."
        helm status "$RELEASE_NAME" -n "$NAMESPACE"
        
        log_info "📦 Pod status:"
        kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" --show-labels 2>/dev/null || log_warning "No pods found"
        
        log_info "🌐 Service status:"
        kubectl get services -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" 2>/dev/null || log_warning "No services found"
        
        log_info "🔗 Ingress status:"
        kubectl get ingress -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" 2>/dev/null || log_warning "No ingress found"
        
        # Try to get ALB URL
        local ingress_host
        ingress_host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$ingress_host" ]; then
            log_success "🌐 Application URL: http://$ingress_host"
        else
            log_warning "⏳ ALB is still provisioning"
        fi
    else
        log_warning "❌ Release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"
        log_info "📋 Available releases in namespace '$NAMESPACE':"
        helm list --namespace "$NAMESPACE" 2>/dev/null || log_info "No releases found"
        
        log_info "📋 All Helm releases:"
        helm list --all-namespaces 2>/dev/null || log_info "No releases found"
        
        log_info "💡 To deploy the application, run:"
        log_info "   ./scripts/helm-deploy.sh deploy $ENVIRONMENT"
        return 1
    fi
}

# Rollback function
rollback_deployment() {
    log_warning "Rolling back deployment..."
    if helm list --namespace "$NAMESPACE" -q 2>/dev/null | grep -q "^${RELEASE_NAME}$"; then
        helm rollback $RELEASE_NAME -n $NAMESPACE
        log_success "Rollback completed. Check deployment status."
    else
        log_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        return 1
    fi
}

# Delete deployment
delete_deployment() {
    log_warning "Deleting deployment..."
    if helm list --namespace "$NAMESPACE" -q 2>/dev/null | grep -q "^${RELEASE_NAME}$"; then
        helm uninstall $RELEASE_NAME -n $NAMESPACE
        log_success "Deployment deleted"
    else
        log_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        return 1
    fi
}

# Main deployment function
main_deploy() {
    log_info "🚀 Starting Helm deployment process..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Version: $VERSION"
    
    check_prerequisites
    deploy_application
    verify_deployment
    
    log_success "🎉 Deployment process completed!"
    log_info "Use './scripts/helm-deploy.sh status $ENVIRONMENT' to see deployment status"
    log_info "Use 'kubectl get pods -n $NAMESPACE' to see running pods"
}

# Show usage
show_usage() {
    echo "Usage: $0 {deploy|rollback|status|delete} [environment] [version]"
    echo ""
    echo "Commands:"
    echo "  deploy    - Deploy application (default)"
    echo "  status    - Check deployment status"
    echo "  rollback  - Rollback to previous version"
    echo "  delete    - Delete deployment"
    echo ""
    echo "Environments:"
    echo "  production  - Production environment (default)"
    echo "  staging     - Staging environment"
    echo "  development - Development environment"
    echo ""
    echo "Examples:"
    echo "  $0 deploy production v1.2.3"
    echo "  $0 deploy staging latest"
    echo "  $0 status production"
    echo "  $0 rollback production"
    echo "  $0 delete staging"
    echo ""
}

# Handle script arguments
case "$COMMAND" in
    "deploy")
        main_deploy
        ;;
    "rollback")
        check_prerequisites
        rollback_deployment
        ;;
    "status")
        check_prerequisites
        check_status
        ;;
    "delete")
        check_prerequisites
        delete_deployment
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac
