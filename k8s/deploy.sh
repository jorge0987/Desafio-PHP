#!/bin/bash

# ==========================================
# Deploy Laravel FPM to Kubernetes
# ==========================================

set -e

echo "🚀 Starting Laravel K8s deployment..."

# Ensure we're using docker-desktop context
echo "📋 Checking Kubernetes context..."
if ! kubectl config current-context | grep -q "docker-desktop"; then
    echo "❌ Not using docker-desktop context. Switching..."
    kubectl config use-context docker-desktop
fi

echo "✅ Using context: $(kubectl config current-context)"

# Create namespace
echo "📦 Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Wait for namespace to be ready
echo "⏳ Waiting for namespace..."
kubectl wait --for=condition=Ready namespace/laravel-demo --timeout=30s

# Deploy FPM version
echo "🐘 Deploying Laravel FPM..."
kubectl apply -f k8s/fpm/

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/laravel-fpm -n laravel-demo

# Check pod status
echo "📊 Checking pod status..."
kubectl get pods -n laravel-demo -l app=laravel-fpm

# Get service info
echo "🌐 Service information:"
kubectl get service laravel-fpm-service -n laravel-demo

# Port forward for testing
echo "🔗 Setting up port forwarding..."
echo "📝 Run this command in another terminal to access the app:"
echo "   kubectl port-forward service/laravel-fpm-service 8081:80 -n laravel-demo"
echo ""
echo "🌍 Then access: http://localhost:8081"
echo ""
echo "✅ Deployment completed!"

# Show logs
echo "📋 Recent pod logs:"
kubectl logs -l app=laravel-fpm -n laravel-demo --tail=10
