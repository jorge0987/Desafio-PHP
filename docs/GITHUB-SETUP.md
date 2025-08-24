# 🔧 GitHub Setup e Configuração de Secrets

## 📋 Pré-requisitos

1. **Conta GitHub** com repositório criado
2. **AWS CLI configurado** localmente
3. **Credenciais AWS** com permissões de administrador

## 🔐 Secrets Necessárias

### Secrets Obrigatórias para CI/CD

Acesse: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

| Nome | Descrição | Como Obter |
|------|-----------|------------|
| `AWS_ACCESS_KEY_ID` | Access Key ID da AWS | Ver seção abaixo |
| `AWS_SECRET_ACCESS_KEY` | Secret Access Key da AWS | Ver seção abaixo |
| `AWS_REGION` | Região AWS (us-east-1) | `us-east-1` |
| `ECR_REPOSITORY` | URL do repositório ECR | Ver seção abaixo |

### 🔑 Como Obter Credenciais AWS

#### Opção 1: Usar suas credenciais atuais
```bash
# Verificar credenciais atuais
aws configure list
aws sts get-caller-identity

# Exportar para usar no GitHub
echo "AWS_ACCESS_KEY_ID: $(aws configure get aws_access_key_id)"
echo "AWS_SECRET_ACCESS_KEY: $(aws configure get aws_secret_access_key)"
```

#### Opção 2: Criar usuário específico para CI/CD (Recomendado)
```bash
# Criar usuário para CI/CD
aws iam create-user --user-name github-actions-ci

# Anexar política de administrador (ou políticas específicas)
aws iam attach-user-policy --user-name github-actions-ci --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Criar access key
aws iam create-access-key --user-name github-actions-ci
```

### 📦 Configuração do ECR Repository

O ECR será criado automaticamente pelo Terraform, mas você pode definir o nome:

```bash
# Para usar o padrão do projeto
ECR_REPOSITORY="laravel-k8s"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
FULL_ECR_URL="${ECR_REGISTRY}/${ECR_REPOSITORY}"

echo "Usar esta URL no GitHub Secret ECR_REPOSITORY:"
echo $FULL_ECR_URL
```

## 🎯 Configuração das Secrets no GitHub

### 1. Acessar Configurações
```
Seu Repositório → Settings → Secrets and variables → Actions
```

### 2. Adicionar Secrets
Clique em `New repository secret` para cada uma:

**AWS_ACCESS_KEY_ID**
```
Nome: AWS_ACCESS_KEY_ID
Valor: AKIA... (sua access key)
```

**AWS_SECRET_ACCESS_KEY**
```
Nome: AWS_SECRET_ACCESS_KEY  
Valor: sua secret key (mantenha secreta!)
```

**AWS_REGION**
```
Nome: AWS_REGION
Valor: us-east-1
```

**ECR_REPOSITORY**
```
Nome: ECR_REPOSITORY
Valor: laravel-k8s
```

## 🔄 Workflows Disponíveis

O projeto inclui 4 workflows prontos:

### 1. Infrastructure Management (`infrastructure.yml`)
- **Trigger**: Push em `terraform/`, workflow manual
- **Função**: Provisiona/atualiza infraestrutura AWS
- **Comandos**: 
  - `terraform plan`
  - `terraform apply`
  - `terraform destroy` (manual)

### 2. Application CI/CD (`application.yml`)
- **Trigger**: Push em `app/`, tags v*
- **Função**: Build e deploy da aplicação Laravel
- **Features**:
  - Build Docker multi-arch (AMD64/ARM64)
  - Push para ECR
  - Deploy via Helm
  - Health checks

### 3. Full Stack Pipeline (`full-stack.yml`)
- **Trigger**: Workflow manual
- **Função**: Deploy completo do zero
- **Sequência**:
  1. Provisiona infraestrutura
  2. Build da aplicação
  3. Deploy no EKS
  4. Testes de saúde

### 4. Testing Suite (`testing.yml`)
- **Trigger**: Pull requests, push em main
- **Função**: Testes automatizados
- **Inclui**:
  - Testes unitários PHP
  - Validação Terraform
  - Security scanning
  - Performance tests com k6

## 🚀 Primeiros Passos Após Configuração

### 1. Teste o Pipeline de Infraestrutura
```bash
# Trigger manual do workflow Infrastructure
# GitHub → Actions → Infrastructure Management → Run workflow
```

### 2. Faça Deploy da Aplicação
```bash
# Trigger automático via push ou tag
git tag v1.0.0
git push origin v1.0.0
```

### 3. Teste o Pipeline Completo
```bash
# Trigger manual do Full Stack Pipeline
# GitHub → Actions → Full Stack Pipeline → Run workflow
```

## 📊 Monitoramento dos Workflows

### Status dos Jobs
- ✅ **Success**: Todos os steps executaram com sucesso
- ❌ **Failure**: Algum step falhou, verificar logs
- 🟡 **In Progress**: Workflow em execução
- ⏸️ **Cancelled**: Workflow cancelado manualmente

### Logs Importantes
```bash
# Terraform Plan Output
terraform-plan-output.txt

# Kubectl Status
kubectl get pods -n laravel-demo

# Application Health
curl https://app-url/health
```

## 🛡️ Boas Práticas de Segurança

### 1. Rotação de Credenciais
```bash
# Rotacionar access keys periodicamente
aws iam update-access-key --user-name github-actions-ci --access-key-id AKIA... --status Inactive
aws iam create-access-key --user-name github-actions-ci
```

### 2. Princípio do Menor Privilégio
```bash
# Substituir AdministratorAccess por políticas específicas
aws iam create-policy --policy-name GitHubActionsEKS --policy-document file://github-actions-policy.json
aws iam attach-user-policy --user-name github-actions-ci --policy-arn arn:aws:iam::ACCOUNT:policy/GitHubActionsEKS
```

### 3. Monitoramento de Uso
```bash
# Verificar últimos acessos
aws iam get-access-key-last-used --access-key-id AKIA...

# Logs de CloudTrail para auditoria
aws logs describe-log-groups --log-group-name-prefix CloudTrail
```

## 📝 Exemplo de Política IAM Específica

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ec2:*",
                "iam:*",
                "ecr:*",
                "logs:*",
                "cloudwatch:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🎯 Checklist de Configuração

- [ ] Secrets configuradas no GitHub
- [ ] Credenciais AWS testadas localmente
- [ ] Workflow de infraestrutura testado
- [ ] Workflow de aplicação testado
- [ ] Pipeline completo validado
- [ ] Monitoramento configurado
- [ ] Documentação atualizada

## 🆘 Troubleshooting

### Erro: Invalid AWS Credentials
```bash
# Verificar credenciais
aws sts get-caller-identity

# Testar permissões EKS
aws eks list-clusters --region us-east-1
```

### Erro: ECR Permission Denied
```bash
# Testar login ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
```

### Erro: Terraform State Lock
```bash
# Verificar locks no S3 (se configurado)
# Ou remover lock local
rm terraform/.terraform.tfstate.lock.info
```

---

**🎉 Após esta configuração, seus workflows de CI/CD estarão prontos para automatizar todo o ciclo de vida da aplicação, desde infraestrutura até deploy!**
