# 🚀 Deployment Guide

## Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Helm 3.x installed
- Docker installed for local development

## Infrastructure Deployment

### 1. Deploy EKS Cluster
```bash
cd terraform/
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -auto-approve
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name laravel-cluster
```

### 3. Verify cluster
```bash
kubectl get nodes
kubectl get pods -A
```

## Application Deployment

### 1. Build and Push Image
```bash
cd app/
docker build -f Dockerfile.k8s -t laravel-k8s:latest .
docker tag laravel-k8s:latest 533267409012.dkr.ecr.us-east-1.amazonaws.com/laravel-k8s:k8s-v1.1.0
docker push 533267409012.dkr.ecr.us-east-1.amazonaws.com/laravel-k8s:k8s-v1.1.0
```

### 2. Deploy with Helm
```bash
cd helm/
helm upgrade --install laravel-app ./laravel-app \
  --namespace laravel \
  --create-namespace \
  --values ./laravel-app/values.yaml \
  --wait
```

### 3. Verify Deployment
```bash
kubectl get pods -n laravel
kubectl get svc -n laravel
kubectl logs -f deployment/laravel-deployment -n laravel
```

## Health Checks

### Internal Health Check
```bash
kubectl port-forward svc/laravel-service 8080:80 -n laravel
curl http://localhost:8080/health
```

### External Health Check
```bash
LOAD_BALANCER=$(kubectl get svc laravel-service -n laravel -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$LOAD_BALANCER/health
```

## Monitoring Setup

### 1. Install Prometheus
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 2. Access Grafana
```bash
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Default: admin/prom-operator
```

## Troubleshooting

### Common Issues
1. **Pod CrashLoopBackOff**: Check logs with `kubectl logs`
2. **Image Pull Errors**: Verify ECR permissions and image tags
3. **LoadBalancer Pending**: Check AWS Load Balancer Controller logs
4. **Health Check Failures**: Verify container port configuration

### Debug Commands
```bash
kubectl describe pod <pod-name> -n laravel
kubectl get events -n laravel --sort-by='.lastTimestamp'
kubectl exec -it <pod-name> -n laravel -- /bin/sh
```

## Cleanup
```bash
helm uninstall laravel-app -n laravel
kubectl delete namespace laravel
cd terraform/ && terraform destroy -auto-approve
```
