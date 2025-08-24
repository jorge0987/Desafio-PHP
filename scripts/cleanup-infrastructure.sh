#!/bin/bash

# 🧹 Script de Limpeza Completa da Infraestrutura AWS
# Este script remove todos os recursos AWS de forma ordenada

set -e

AWS_REGION="us-east-1"
CLUSTER_NAME="laravel-swoole-cluster"

echo "🧹 Iniciando limpeza completa da infraestrutura AWS..."

# 1. Configurar kubectl se o cluster existir
echo "📋 Verificando cluster EKS..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &>/dev/null; then
    echo "✅ Cluster $CLUSTER_NAME encontrado, configurando kubectl..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
    
    # 2. Remover Helm releases
    echo "📦 Removendo Helm releases..."
    helm list -A -q 2>/dev/null | while read release; do
        if [ ! -z "$release" ]; then
            namespace=$(helm list -A | grep "^$release" | awk '{print $2}')
            echo "  🗑️ Removendo release: $release (namespace: $namespace)"
            helm uninstall $release -n $namespace --timeout=60s || true
        fi
    done
    
    # 3. Remover LoadBalancers
    echo "🔗 Removendo Load Balancers..."
    kubectl get svc -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do
        if [ ! -z "$ns" ] && [ ! -z "$name" ]; then
            echo "  🗑️ Removendo LoadBalancer: $name (namespace: $ns)"
            kubectl delete svc $name -n $ns --timeout=60s || true
        fi
    done
    
    # 4. Aguardar limpeza dos Load Balancers
    echo "⏳ Aguardando limpeza dos Load Balancers (2 minutos)..."
    sleep 120
    
    # 5. Remover nodegroups primeiro
    echo "🏗️ Removendo nodegroups do cluster EKS..."
    nodegroups=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --query 'nodegroups' --output text)
    
    if [ ! -z "$nodegroups" ] && [ "$nodegroups" != "None" ]; then
        for nodegroup in $nodegroups; do
            echo "  🗑️ Removendo nodegroup: $nodegroup"
            aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $AWS_REGION || true
        done
        
        # Aguardar todos os nodegroups serem deletados
        echo "⏳ Aguardando nodegroups serem deletados..."
        for nodegroup in $nodegroups; do
            echo "  ⏳ Aguardando nodegroup $nodegroup..."
            aws eks wait nodegroup-deleted --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $AWS_REGION --cli-read-timeout 0 --cli-connect-timeout 60 || true
        done
        echo "✅ Todos os nodegroups removidos!"
    else
        echo "ℹ️ Nenhum nodegroup encontrado"
    fi
    
    # 6. Deletar cluster EKS
    echo "🏗️ Deletando cluster EKS..."
    aws eks delete-cluster --name $CLUSTER_NAME --region $AWS_REGION
    
    echo "⏳ Aguardando cluster ser deletado (pode levar 5-10 minutos)..."
    aws eks wait cluster-deleted --name $CLUSTER_NAME --region $AWS_REGION --cli-read-timeout 0 --cli-connect-timeout 60
    echo "✅ Cluster EKS deletado com sucesso!"
else
    echo "ℹ️ Cluster $CLUSTER_NAME não encontrado, continuando..."
fi

# 7. Limpar repositórios ECR
echo "🐳 Limpando repositórios ECR..."

# Lista de possíveis repositórios para limpar
REPOS=("laravel-swoole-poc/laravel-fpm" "laravel-k8s" "laravel-fpm")

for repo in "${REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names $repo --region $AWS_REGION &>/dev/null; then
        echo "  🗑️ Limpando repositório: $repo"
        
        # Lista e delete todas as imagens
        images=$(aws ecr list-images --repository-name $repo --region $AWS_REGION --query 'imageIds[*]' --output json)
        if [ "$images" != "[]" ]; then
            echo "$images" | aws ecr batch-delete-image --repository-name $repo --region $AWS_REGION --image-ids file:///dev/stdin || true
        fi
        
        # Force delete do repositório
        aws ecr delete-repository --repository-name $repo --region $AWS_REGION --force || true
        echo "  ✅ Repositório $repo removido"
    else
        echo "  ℹ️ Repositório $repo não encontrado"
    fi
done

# 8. Remover recursos de rede órfãos
echo "🔌 Removendo recursos de rede órfãos..."

# 8.1. Remover ENIs órfãos (incluindo os attached)
echo "  🔌 Verificando ENIs..."
aws ec2 describe-network-interfaces --region $AWS_REGION --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' --output table

aws ec2 describe-network-interfaces --region $AWS_REGION --filters "Name=status,Values=available" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text | while read eni; do
    if [ ! -z "$eni" ]; then
        echo "    🗑️ Removendo ENI órfão: $eni"
        aws ec2 delete-network-interface --network-interface-id $eni --region $AWS_REGION || true
    fi
done

# 8.2. Forçar detach e remover ENIs em uso
aws ec2 describe-network-interfaces --region $AWS_REGION --filters "Name=vpc-id,Values=vpc-*" --query 'NetworkInterfaces[?Status==`in-use`].[NetworkInterfaceId,AttachmentId]' --output text | while read eni attachment_id; do
    if [ ! -z "$eni" ] && [ ! -z "$attachment_id" ]; then
        echo "    🔓 Forçando detach ENI: $eni (attachment: $attachment_id)"
        aws ec2 detach-network-interface --attachment-id $attachment_id --region $AWS_REGION --force || true
        sleep 30
        aws ec2 delete-network-interface --network-interface-id $eni --region $AWS_REGION || true
    fi
done

# 8.3. Remover NAT Gateways
echo "  🌐 Removendo NAT Gateways..."
aws ec2 describe-nat-gateways --region $AWS_REGION --filter "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' --output text | while read nat_id; do
    if [ ! -z "$nat_id" ]; then
        echo "    🗑️ Removendo NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id $nat_id --region $AWS_REGION || true
    fi
done

# 8.4. Aguardar NAT Gateways serem deletados
echo "  ⏳ Aguardando NAT Gateways serem deletados..."
sleep 120

# 8.5. Remover Elastic IPs órfãos
echo "  🏷️ Removendo Elastic IPs órfãos..."
aws ec2 describe-addresses --region $AWS_REGION --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]' --output text | while read alloc_id public_ip; do
    if [ ! -z "$alloc_id" ]; then
        echo "    🗑️ Liberando Elastic IP: $public_ip ($alloc_id)"
        aws ec2 release-address --allocation-id $alloc_id --region $AWS_REGION || true
    fi
done

# 8.6. Forçar liberação de todos os EIPs
aws ec2 describe-addresses --region $AWS_REGION --query 'Addresses[*].[AllocationId,PublicIp,AssociationId]' --output text | while read alloc_id public_ip assoc_id; do
    if [ ! -z "$alloc_id" ]; then
        if [ ! -z "$assoc_id" ] && [ "$assoc_id" != "None" ]; then
            echo "    🔓 Desassociando EIP: $public_ip"
            aws ec2 disassociate-address --association-id $assoc_id --region $AWS_REGION || true
            sleep 10
        fi
        echo "    🗑️ Liberando EIP: $public_ip ($alloc_id)"
        aws ec2 release-address --allocation-id $alloc_id --region $AWS_REGION || true
    fi
done

# 9. Aguardar propagação e limpeza final
echo "⏳ Aguardando propagação das mudanças (3 minutos para garantir limpeza completa)..."
sleep 180

# 9.1. Verificação final de recursos órfãos
echo "🔍 Verificação final de recursos órfãos..."
echo "  ENIs restantes:"
aws ec2 describe-network-interfaces --region $AWS_REGION --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status]' --output table || true

echo "  EIPs restantes:"
aws ec2 describe-addresses --region $AWS_REGION --query 'Addresses[*].[AllocationId,PublicIp]' --output table || true

echo "  NAT Gateways restantes:"
aws ec2 describe-nat-gateways --region $AWS_REGION --query 'NatGateways[*].[NatGatewayId,State]' --output table || true

# 10. Executar Terraform destroy
echo "🏗️ Executando Terraform destroy..."
cd "$(dirname "$0")/../terraform"

if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve -var-file="terraform.tfvars"
    echo "✅ Terraform destroy executado com sucesso!"
else
    echo "ℹ️ Arquivo terraform.tfstate não encontrado, infraestrutura já pode estar limpa"
fi

echo ""
echo "🎉 Limpeza completa finalizada!"
echo "ℹ️ Verifique no AWS Console se todos os recursos foram removidos:"
echo "   - EKS Clusters"
echo "   - EC2 Instances"
echo "   - Load Balancers"
echo "   - VPCs"
echo "   - ECR Repositories"
