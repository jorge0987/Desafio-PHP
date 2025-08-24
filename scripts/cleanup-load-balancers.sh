#!/bin/bash

# 🎯 Limpeza de Load Balancers - Resolver ENI network_load_balancer
# Este script remove Load Balancers que estão impedindo a limpeza da VPC

set -e

AWS_REGION="us-east-1"
VPC_ID="vpc-06d9806ccd32ef389"

echo "🎯 Removendo Load Balancers que impedem limpeza da VPC..."
echo "🔍 VPC Target: $VPC_ID"
echo ""

# 1. Listar todos os Load Balancers
echo "📋 Listando todos os Load Balancers..."
echo ""
echo "=== APPLICATION LOAD BALANCERS ==="
aws elbv2 describe-load-balancers --region $AWS_REGION \
    --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn,VpcId,Type,State.Code]' \
    --output table 2>/dev/null || echo "Nenhum ALB encontrado"

echo ""
echo "=== CLASSIC LOAD BALANCERS ==="
aws elb describe-load-balancers --region $AWS_REGION \
    --query 'LoadBalancerDescriptions[*].[LoadBalancerName,VPCId,Scheme]' \
    --output table 2>/dev/null || echo "Nenhum CLB encontrado"

echo ""
echo "=== NETWORK LOAD BALANCERS ==="
aws elbv2 describe-load-balancers --region $AWS_REGION \
    --query 'LoadBalancers[?Type==`network`].[LoadBalancerName,LoadBalancerArn,VpcId,State.Code]' \
    --output table 2>/dev/null || echo "Nenhum NLB encontrado"

# 2. Remover Load Balancers da nossa VPC
echo ""
echo "🗑️ Removendo Load Balancers da VPC $VPC_ID..."

# 2.1. Remover ALBs/NLBs (ELBv2)
aws elbv2 describe-load-balancers --region $AWS_REGION \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].[LoadBalancerArn,LoadBalancerName,Type]" \
    --output text | while read lb_arn lb_name lb_type; do
    
    if [ ! -z "$lb_arn" ]; then
        echo "  🗑️ Removendo $lb_type Load Balancer: $lb_name"
        echo "     ARN: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $AWS_REGION || true
        echo "     ✅ Comando enviado para $lb_name"
    fi
done

# 2.2. Remover Classic Load Balancers
aws elb describe-load-balancers --region $AWS_REGION \
    --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" \
    --output text | while read lb_name; do
    
    if [ ! -z "$lb_name" ]; then
        echo "  🗑️ Removendo Classic Load Balancer: $lb_name"
        aws elb delete-load-balancer --load-balancer-name "$lb_name" --region $AWS_REGION || true
        echo "     ✅ Comando enviado para $lb_name"
    fi
done

# 3. Aguardar Load Balancers serem deletados
echo ""
echo "⏳ Aguardando Load Balancers serem deletados (3 minutos)..."
sleep 180

# 4. Verificar Load Balancers restantes
echo ""
echo "🔍 Verificando Load Balancers restantes na VPC..."
echo ""

remaining_albs=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerName" \
    --output text 2>/dev/null || echo "")

remaining_clbs=$(aws elb describe-load-balancers --region $AWS_REGION \
    --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" \
    --output text 2>/dev/null || echo "")

if [ -z "$remaining_albs" ] && [ -z "$remaining_clbs" ]; then
    echo "✅ Nenhum Load Balancer restante na VPC!"
else
    echo "⚠️ Load Balancers ainda presentes:"
    echo "ALBs/NLBs: $remaining_albs"
    echo "CLBs: $remaining_clbs"
fi

# 5. Verificar ENIs novamente
echo ""
echo "🔍 Verificando ENIs da VPC após remoção dos Load Balancers..."
aws ec2 describe-network-interfaces --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,InterfaceType,Description]' \
    --output table 2>/dev/null || echo "✅ Nenhum ENI encontrado"

echo ""
echo "🎉 Limpeza de Load Balancers concluída!"
echo ""
echo "💡 Próximos passos:"
echo "1. Execute o script de limpeza VPC: ./scripts/force-vpc-cleanup.sh"
echo "2. Ou tente terraform destroy novamente:"
echo "   cd terraform && terraform destroy -auto-approve -var-file=\"terraform.tfvars\""
