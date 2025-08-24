# EKS Terraform - README

## 🏗️ **Infraestrutura EKS para Laravel Demo**

Este diretório contém a configuração Terraform completa para criar um cluster EKS production-ready na AWS para demonstração da aplicação Laravel.

## 📁 **Estrutura dos Arquivos**

```
terraform/
├── main.tf                    # Configuração principal e locals
├── providers.tf               # Configuração dos providers
├── variables.tf               # Definição de variáveis
├── outputs.tf                 # Outputs importantes
├── vpc.tf                     # VPC e networking
├── eks.tf                     # Cluster EKS
├── ecr.tf                     # Container registries
├── iam.tf                     # Roles e políticas IAM
├── addons.tf                  # Add-ons do Kubernetes
├── deploy.sh                  # Script de automação
├── terraform.tfvars.example   # Exemplo de configuração
└── README.md                  # Este arquivo
```

## 🚀 **Deploy Rápido**

### **Opção 1: Script Interativo (Recomendado)**
```bash
./deploy.sh
```

### **Opção 2: Comandos Individuais**
```bash
# 1. Inicializar
terraform init

# 2. Planejar
terraform plan

# 3. Aplicar
terraform apply

# 4. Configurar kubectl
aws eks --region us-east-1 update-kubeconfig --name laravel-demo-cluster
```

### **Opção 3: Deploy Automatizado**
```bash
./deploy.sh deploy
```

## ⚙️ **Configuração**

### **1. Prerequisites**
```bash
# Instalar ferramentas
brew install terraform kubectl awscli

# Configurar AWS
aws configure
aws sts get-caller-identity
```

### **2. Personalizar Configuração**
```bash
# Copiar e editar configuração
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

### **3. Variáveis Importantes**
| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `aws_region` | `us-east-1` | Região AWS |
| `node_group_desired_size` | `2` | Número inicial de nodes |
| `use_spot_instances` | `true` | Usar spot instances (economia) |
| `cluster_version` | `1.30` | Versão do Kubernetes |

## 💰 **Estimativa de Custos**

### **Configuração Padrão (Spot Instances)**
- **EKS Control Plane**: $72/mês
- **EC2 t3.medium (2x spot)**: ~$18/mês  
- **ALB**: $16/mês
- **EBS**: $4/mês
- **Total**: ~$110/mês

### **Para Demo (3-5 dias)**
- **Custo total**: $15-25

### **Otimizações de Custo**
- ✅ Spot instances habilitadas
- ✅ Single NAT Gateway
- ✅ Lifecycle policies no ECR
- ✅ Auto-scaling configurado

## 🏗️ **Arquitetura Criada**

### **Componentes AWS**
- **VPC**: 3 AZs, subnets públicas e privadas
- **EKS Cluster**: Versão 1.30 com OIDC
- **Node Groups**: Managed nodes com auto-scaling
- **ECR**: 4 repositórios para images
- **IAM**: Roles com least privilege
- **Security Groups**: Configuração segura

### **Add-ons Kubernetes**
- **AWS Load Balancer Controller**: ALB automation
- **Cluster Autoscaler**: Node scaling
- **Metrics Server**: HPA support
- **EBS CSI Driver**: Persistent volumes
- **CloudWatch Agent**: Monitoring

### **Namespaces e Service Accounts**
- **Namespace**: `laravel-demo`
- **Service Account**: `laravel-app-sa` (com IRSA)

## 🔧 **Pós-Deploy**

### **1. Verificar Cluster**
```bash
kubectl get nodes
kubectl get pods -A
kubectl get hpa -A
```

### **2. ECR Login**
```bash
# Comando será mostrado no output
terraform output ecr_login_command
```

### **3. Deploy Aplicações**
```bash
# Navegar para k8s manifests
cd ../k8s/
kubectl apply -f .
```

## 📊 **Monitoramento**

### **CloudWatch Metrics**
- Cluster performance
- Node utilization  
- Container insights

### **EKS Console**
- Cluster health
- Add-ons status
- Logs centralizados

### **Kubectl Commands**
```bash
# Status geral
kubectl get all -n laravel-demo

# Logs
kubectl logs -f deployment/laravel-fpm -n laravel-demo

# Métricas
kubectl top pods -n laravel-demo
kubectl top nodes
```

## 🛠️ **Troubleshooting**

### **Problemas Comuns**

#### **1. AWS Credentials**
```bash
aws sts get-caller-identity
aws configure list
```

#### **2. Terraform State Lock**
```bash
# Se necessário, force unlock
terraform force-unlock LOCK_ID
```

#### **3. EKS Access**
```bash
# Reconfigurar kubectl
aws eks update-kubeconfig --region us-east-1 --name laravel-demo-cluster

# Verificar permissions
kubectl auth can-i '*' '*' --all-namespaces
```

#### **4. Node Issues**
```bash
# Verificar nodes
kubectl describe nodes

# Verificar auto-scaling
kubectl get hpa -A
kubectl describe hpa -n kube-system
```

### **Logs Úteis**
```bash
# ALB Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Cluster Autoscaler logs  
kubectl logs -n kube-system deployment/cluster-autoscaler

# Metrics Server logs
kubectl logs -n kube-system deployment/metrics-server
```

## 🔥 **Cleanup**

### **Destruir Infraestrutura**
```bash
# Opção 1: Script
./deploy.sh destroy

# Opção 2: Terraform
terraform destroy

# Opção 3: Automatizado
./deploy.sh destroy
```

### **⚠️ Verificar Custos**
```bash
# Verificar recursos órfãos
aws ec2 describe-volumes --filters Name=status,Values=available
aws elbv2 describe-load-balancers
aws ec2 describe-security-groups
```

## 🎯 **Próximos Passos**

1. **Build Images**: Criar e push das images Docker
2. **Deploy Apps**: Aplicar manifests Kubernetes
3. **Configure Monitoring**: Setup Prometheus/Grafana
4. **Load Testing**: Validar auto-scaling
5. **Demo Preparation**: Preparar script de apresentação

## 📚 **Referências**

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

---

**🚀 Pronto para impressionar com infraestrutura cloud-native production-ready!**
