# 🔐 Configuração de Políticas IAM para GitHub Actions

## 📋 Opções de Configuração

### **Opção 1: Política Administrativa (Recomendado para Demo) ⚡**
```bash
# Criar usuário para GitHub Actions
aws iam create-user --user-name github-actions-cicd

# Anexar política administrativa
aws iam attach-user-policy \
    --user-name github-actions-cicd \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Criar access key
aws iam create-access-key --user-name github-actions-cicd
```

### **Opção 2: Política Específica (Mais Segura - Corrigida) 🛡️**

#### 1. Criar a política customizada:
```bash
# Criar política com permissões específicas (sem warnings)
aws iam create-policy \
    --policy-name GitHubActions-EKS-Policy \
    --policy-document file://docs/github-actions-policy.json
```

#### 2. Criar usuário e anexar política:
```bash
# Criar usuário
aws iam create-user --user-name github-actions-cicd

# Anexar política customizada
aws iam attach-user-policy \
    --user-name github-actions-cicd \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/GitHubActions-EKS-Policy

# Criar access key
aws iam create-access-key --user-name github-actions-cicd
```

## 🎯 Recomendação

Para demonstração e desenvolvimento, use a **Opção 1** (AdministratorAccess):
- ✅ Mais simples e rápida
- ✅ Evita problemas de permissão
- ✅ Ideal para POCs e demos
- ⚠️ Para produção, considere a Opção 2

## 🚀 Comandos Rápidos

### Para usar AdministratorAccess (Recomendado para demo):
```bash
# 1. Criar usuário
aws iam create-user --user-name github-actions-cicd

# 2. Dar permissões administrativas
aws iam attach-user-policy \
    --user-name github-actions-cicd \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 3. Criar access key
aws iam create-access-key --user-name github-actions-cicd

# 4. Copiar o output para configurar no GitHub
```

### Output esperado:
```json
{
    "AccessKey": {
        "UserName": "github-actions-cicd",
        "AccessKeyId": "AKIA...",
        "Status": "Active",
        "SecretAccessKey": "...",
        "CreateDate": "2025-08-24T..."
    }
}
```

## 🔧 Configurar no GitHub

Use os valores do output acima:

1. **AWS_ACCESS_KEY_ID**: `AccessKeyId` do output
2. **AWS_SECRET_ACCESS_KEY**: `SecretAccessKey` do output
3. **AWS_REGION**: `us-east-1`
4. **ECR_REPOSITORY**: `laravel-k8s`

## 🧹 Limpeza (Opcional)

Se quiser remover depois:
```bash
# Listar access keys
aws iam list-access-keys --user-name github-actions-cicd

# Deletar access key
aws iam delete-access-key --user-name github-actions-cicd --access-key-id AKIA...

# Remover políticas
aws iam detach-user-policy \
    --user-name github-actions-cicd \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Deletar usuário
aws iam delete-user --user-name github-actions-cicd
```

## 🎯 Próximos Passos

1. ✅ Execute os comandos acima para criar o usuário
2. ✅ Configure as secrets no GitHub com os valores obtidos
3. ✅ Teste o workflow "Infrastructure Management"
4. ✅ Execute o "Full Stack Pipeline" para deploy completo

---

**💡 Dica**: Para demo/entrevista, use AdministratorAccess. É mais simples e evita problemas de permissão durante a apresentação!
