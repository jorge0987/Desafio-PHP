# 🎯 CI/CD Workflows Guide

Este projeto inclui workflows GitHub Actions completos para demonstrar expertise DevOps/SRE profissional.

## 📋 Workflows Disponíveis

### 1. 🏗️ Infrastructure Management (`infrastructure.yml`)
**Objetivo**: Gerenciamento completo da infraestrutura AWS EKS

**Triggers**:
- Manual via workflow_dispatch
- Push em arquivos terraform/
- Pull requests

**Ações Disponíveis**:
- `plan`: Terraform plan para revisar mudanças
- `apply`: Criar/atualizar infraestrutura EKS
- `destroy`: Destruir infraestrutura completamente

**Ambientes**:
- `staging`: Para desenvolvimento e testes
- `production`: Para demonstrações finais

### 2. 🚀 Application CI/CD (`application.yml`)
**Objetivo**: Pipeline completo de aplicação com security scanning

**Features**:
- ✅ Code quality (PHPStan, CodeSniffer)
- 🐳 Docker build multi-platform (ARM64)
- 🛡️ Security scanning (Trivy)
- 🚀 Deploy com Helm
- 🐤 Canary deployments (produção)
- ↩️ Rollback automático

**Triggers**:
- Manual dispatch
- Push/PR em app/ ou helm/

### 3. 🔄 Full Stack Pipeline (`full-stack.yml`)
**Objetivo**: Orquestração completa - infraestrutura + aplicação

**Features**:
- 🏗️ Deploy infraestrutura
- ⏳ Espera cluster estar pronto
- 🚀 Deploy aplicação
- 🧪 Testes de integração
- ⏰ Auto-destroy programado
- 📊 Relatório completo

### 4. 🧪 Automated Testing (`testing.yml`)
**Objetivo**: Suite completa de testes automatizados

**Tipos de Teste**:
- 💨 Smoke tests (conectividade básica)
- ⚡ Load tests (performance sob carga)
- 🔥 Stress tests (limites do sistema)
- 🛡️ Security tests (vulnerabilidades)

**Schedule**: Execução diária às 02:00 UTC

## 🔧 Configuração Necessária

### GitHub Secrets
Configure no repositório (`Settings > Secrets and variables > Actions`):

```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

### Permissions IAM
O usuário AWS precisa de:
- EKS Full Access
- EC2 Full Access  
- VPC Full Access
- IAM Limited Access
- ECR Full Access
- CloudWatch Logs Access

### 2. Security Pipeline
```yaml
# .github/workflows/security.yml
name: Security Scan
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * 1'  # Weekly scan

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Docker image
        run: docker build -f app/Dockerfile.k8s -t security-scan:${{ github.sha }} .
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'security-scan:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
      
      - name: Dependency Check
        run: |
          composer audit
          npm audit --audit-level high
```

### 3. Build and Deploy Pipeline
```yaml
# .github/workflows/deploy.yml
name: Build and Deploy
on:
  push:
    branches: [main]
    tags: ['v*']

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: laravel-k8s
  EKS_CLUSTER: laravel-cluster

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.image.outputs.image }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push image
        id: image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -f app/Dockerfile.k8s -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Update kube config
        run: aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION
      
      - name: Deploy to staging
        run: |
          helm upgrade --install laravel-app-staging ./helm/laravel-app \
            --namespace laravel-staging \
            --create-namespace \
            --set image.repository=${{ needs.build.outputs.image }} \
            --set image.tag="" \
            --set environment=staging \
            --wait

  deploy-production:
    needs: [build, deploy-staging]
    runs-on: ubuntu-latest
    environment: production
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Update kube config
        run: aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION
      
      - name: Canary deployment
        run: |
          # Deploy canary version (10% traffic)
          helm upgrade --install laravel-app-canary ./helm/laravel-app \
            --namespace laravel \
            --set image.repository=${{ needs.build.outputs.image }} \
            --set image.tag="" \
            --set replicaCount=1 \
            --set service.name=laravel-canary \
            --wait
          
          # Wait and monitor metrics
          sleep 300
          
          # Check canary health
          if kubectl rollout status deployment/laravel-app-canary -n laravel; then
            # Promote to full deployment
            helm upgrade --install laravel-app ./helm/laravel-app \
              --namespace laravel \
              --set image.repository=${{ needs.build.outputs.image }} \
              --set image.tag="" \
              --wait
            
            # Cleanup canary
            helm uninstall laravel-app-canary -n laravel
          else
            echo "Canary deployment failed, rolling back"
            helm uninstall laravel-app-canary -n laravel
            exit 1
          fi
```

## Environment Management

### Development
- **Trigger**: Every push to feature branches
- **Testing**: Full test suite + security scan
- **Deployment**: Local Docker Compose

### Staging
- **Trigger**: Push to `develop` branch
- **Testing**: Integration tests + load testing
- **Deployment**: Kubernetes cluster (reduced resources)

### Production
- **Trigger**: Git tags (`v*`)
- **Testing**: Full test suite + security validation
- **Deployment**: Canary deployment with monitoring

## Secrets Management

### GitHub Secrets
```bash
# Required secrets in GitHub repository
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
DOCKERHUB_USERNAME  # Optional for rate limits
DOCKERHUB_TOKEN     # Optional for rate limits
```

### Kubernetes Secrets
```yaml
# Created automatically by pipeline
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: laravel
type: Opaque
data:
  APP_KEY: <base64-encoded>
  DB_PASSWORD: <base64-encoded>
```

## Monitoring and Alerting

### Pipeline Monitoring
- **Build Success Rate**: >95%
- **Deployment Time**: <5 minutes
- **Test Coverage**: >80%
- **Security Scan**: No high/critical vulnerabilities

### Notifications
- **Slack Integration**: Build status notifications
- **Email Alerts**: Failed deployments
- **GitHub Checks**: PR status validation

## Rollback Strategy

### Automatic Rollback
```bash
# Triggered on health check failures
kubectl rollout undo deployment/laravel-deployment -n laravel
```

### Manual Rollback
```bash
# Rollback to specific version
helm rollback laravel-app 1 -n laravel
```

## Performance Optimization

### Build Optimization
- **Multi-stage builds**: Reduced image size
- **Layer caching**: Docker BuildKit optimization
- **Parallel jobs**: Concurrent pipeline execution

### Deployment Optimization
- **Blue-green deployments**: Zero-downtime deployments
- **Resource pre-warming**: Pod readiness optimization
- **Progressive delivery**: Canary with automatic promotion
