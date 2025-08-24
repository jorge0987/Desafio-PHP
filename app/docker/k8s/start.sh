#!/bin/sh

# ==========================================
# Kubernetes-optimized startup script
# Para usuário não-root com todas as correções
# ==========================================

set -e

echo "🚀 Starting Laravel container (Kubernetes optimized)..."

# Verificar se os diretórios existem e têm permissões corretas
echo "🔧 Checking directories and permissions..."

# Criar cache do OPcache se não existir
mkdir -p /tmp/opcache
chmod 755 /tmp/opcache

# Verificar se os diretórios do Nginx existem
if [ ! -d "/var/lib/nginx/tmp/client_body" ]; then
    echo "❌ Nginx temp directories not found! Container may not be built correctly."
    exit 1
fi

# Testar se podemos escrever nos diretórios de log
if ! touch /var/log/nginx/test.log 2>/dev/null; then
    echo "❌ Cannot write to Nginx log directory!"
    exit 1
fi
rm -f /var/log/nginx/test.log

echo "✅ Directory permissions OK"

# Iniciar PHP-FPM em background
echo "📦 Starting PHP-FPM..."
php-fpm -D

# Aguardar PHP-FPM inicializar
echo "⏳ Waiting for PHP-FPM to start..."
for i in $(seq 1 10); do
    if php-fpm -t > /dev/null 2>&1; then
        echo "✅ PHP-FPM configuration OK"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ PHP-FPM failed to start"
        exit 1
    fi
    sleep 1
done

# Testar se PHP-FPM está escutando
echo "🔍 Testing PHP-FPM connection..."
if ! nc -z 127.0.0.1 9000; then
    echo "❌ PHP-FPM not listening on port 9000"
    exit 1
fi

echo "✅ PHP-FPM started and listening!"

# Testar configuração do Nginx antes de iniciar
echo "🔍 Testing Nginx configuration..."
if ! nginx -t; then
    echo "❌ Nginx configuration test failed"
    exit 1
fi

echo "✅ Nginx configuration OK"

# Iniciar Nginx em foreground
echo "🌐 Starting Nginx..."
echo "🎉 Container ready to serve requests!"

exec nginx -g "daemon off;"
