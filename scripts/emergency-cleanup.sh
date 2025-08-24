#!/bin/bash

# 🚨 Script de Limpeza Manual de Emergência
# Use este script quando o Terraform destroy falhar

set -e

AWS_REGION="us-east-1"

echo "🚨 Iniciando limpeza manual de emergência..."
echo "⚠️ Este script irá forçar a remoção de recursos AWS"

# 1. Listar e remover todos os ENIs
echo "🔌 Limpeza forçada de ENIs..."
aws ec2 describe-network-interfaces --region $AWS_REGION --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,VpcId,Description]' --output table

# Forçar detach de todos os ENIs
aws ec2 describe-network-interfaces --region $AWS_REGION --query 'NetworkInterfaces[*].[NetworkInterfaceId,Attachment.AttachmentId]' --output text | while read eni attachment; do
    if [ ! -z "$eni" ] && [ "$eni" != "None" ]; then
        echo "  🔓 Processando ENI: $eni"
        if [ ! -z "$attachment" ] && [ "$attachment" != "None" ]; then
            echo "    🔓 Forçando detach: $attachment"
            aws ec2 detach-network-interface --attachment-id $attachment --region $AWS_REGION --force || true
            sleep 10
        fi
        echo "    🗑️ Deletando ENI: $eni"
        aws ec2 delete-network-interface --network-interface-id $eni --region $AWS_REGION || true
    fi
done

echo "⏳ Aguardando ENIs serem processados..."
sleep 60

# 2. Remover todos os NAT Gateways
echo "🌐 Limpeza forçada de NAT Gateways..."
aws ec2 describe-nat-gateways --region $AWS_REGION --query 'NatGateways[*].[NatGatewayId,State,VpcId]' --output table

aws ec2 describe-nat-gateways --region $AWS_REGION --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text | while read nat_id; do
    if [ ! -z "$nat_id" ]; then
        echo "  🗑️ Removendo NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id $nat_id --region $AWS_REGION || true
    fi
done

echo "⏳ Aguardando NAT Gateways serem deletados..."
sleep 120

# 3. Liberar todos os Elastic IPs
echo "🏷️ Limpeza forçada de Elastic IPs..."
aws ec2 describe-addresses --region $AWS_REGION --query 'Addresses[*].[AllocationId,PublicIp,AssociationId]' --output table

aws ec2 describe-addresses --region $AWS_REGION --query 'Addresses[*].[AllocationId,AssociationId]' --output text | while read alloc_id assoc_id; do
    if [ ! -z "$alloc_id" ]; then
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

# 4. Verificação final
echo "🔍 Verificação final de recursos..."
echo ""
echo "ENIs restantes:"
aws ec2 describe-network-interfaces --region $AWS_REGION --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status]' --output table || echo "Nenhum ENI encontrado"

echo ""
echo "EIPs restantes:"
aws ec2 describe-addresses --region $AWS_REGION --query 'Addresses[*].[AllocationId,PublicIp]' --output table || echo "Nenhum EIP encontrado"

echo ""
echo "NAT Gateways restantes:"
aws ec2 describe-nat-gateways --region $AWS_REGION --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]' --output table || echo "Nenhum NAT Gateway encontrado"

echo ""
echo "🎉 Limpeza manual concluída!"
