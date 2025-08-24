#!/bin/bash

# 🔥 Limpeza VPC Direta - Para resolver dependências travadas
# Execute quando terraform destroy está travado

set -e

AWS_REGION="us-east-1"
VPC_ID="vpc-06d9806ccd32ef389"  # VPC do output do terraform

echo "🔥 Iniciando limpeza VPC direta..."
echo "🎯 VPC Target: $VPC_ID"
echo ""

# 1. Cancelar terraform se estiver rodando
echo "⚠️  PRIMEIRO: Cancele o terraform destroy com Ctrl+C se estiver rodando"
echo "⏳ Aguardando 10 segundos para você cancelar..."
sleep 10

# 2. Identificar e remover recursos específicos da VPC
echo "🔍 Identificando recursos na VPC $VPC_ID..."

# 2.1. Listar ENIs na VPC
echo "📋 ENIs na VPC:"
aws ec2 describe-network-interfaces --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' \
    --output table

# 2.2. Forçar remoção de ENIs
echo "🗑️ Removendo ENIs da VPC..."
aws ec2 describe-network-interfaces --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,Attachment.AttachmentId]' \
    --output text | while read eni attachment; do
    
    if [ ! -z "$eni" ] && [ "$eni" != "None" ]; then
        echo "  🔧 Processando ENI: $eni"
        
        # Detach se necessário
        if [ ! -z "$attachment" ] && [ "$attachment" != "None" ]; then
            echo "    🔓 Detaching: $attachment"
            aws ec2 detach-network-interface --attachment-id $attachment --region $AWS_REGION --force || true
            sleep 15
        fi
        
        # Delete ENI
        echo "    🗑️ Deletando ENI: $eni"
        aws ec2 delete-network-interface --network-interface-id $eni --region $AWS_REGION || true
        sleep 5
    fi
done

echo "⏳ Aguardando ENIs serem processados..."
sleep 60

# 2.3. Remover NAT Gateways da VPC
echo "🌐 Removendo NAT Gateways da VPC..."
aws ec2 describe-nat-gateways --region $AWS_REGION \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending,deleting" \
    --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
    --output text | while read nat_id state subnet_id; do
    
    if [ ! -z "$nat_id" ]; then
        echo "  🗑️ Removendo NAT Gateway: $nat_id (State: $state)"
        aws ec2 delete-nat-gateway --nat-gateway-id $nat_id --region $AWS_REGION || true
    fi
done

echo "⏳ Aguardando NAT Gateways serem deletados..."
sleep 120

# 2.4. Liberar EIPs associados à VPC
echo "🏷️ Liberando EIPs associados..."
aws ec2 describe-addresses --region $AWS_REGION \
    --query 'Addresses[*].[AllocationId,AssociationId,NetworkInterfaceId]' \
    --output text | while read alloc_id assoc_id eni_id; do
    
    if [ ! -z "$alloc_id" ]; then
        # Verificar se está associado a recursos da nossa VPC
        if [ ! -z "$assoc_id" ] && [ "$assoc_id" != "None" ]; then
            echo "  🔓 Desassociando EIP: $alloc_id"
            aws ec2 disassociate-address --association-id $assoc_id --region $AWS_REGION || true
            sleep 5
        fi
        
        echo "  🗑️ Liberando EIP: $alloc_id"
        aws ec2 release-address --allocation-id $alloc_id --region $AWS_REGION || true
    fi
done

echo "⏳ Aguardando propagação final..."
sleep 90

# 3. Verificação específica da VPC
echo "🔍 Verificação final da VPC $VPC_ID..."

echo ""
echo "ENIs restantes na VPC:"
aws ec2 describe-network-interfaces --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status]' \
    --output table 2>/dev/null || echo "✅ Nenhum ENI encontrado"

echo ""
echo "NAT Gateways restantes na VPC:"
aws ec2 describe-nat-gateways --region $AWS_REGION \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]' \
    --output table 2>/dev/null || echo "✅ Nenhum NAT Gateway encontrado"

echo ""
echo "🎉 Limpeza VPC específica concluída!"
echo ""
echo "💡 Agora execute:"
echo "cd terraform"
echo "terraform destroy -auto-approve -var-file=\"terraform.tfvars\""
echo ""
echo "Se ainda der problema, delete manualmente no console AWS:"
echo "🌐 https://console.aws.amazon.com/vpc/home?region=us-east-1#vpcs:"
