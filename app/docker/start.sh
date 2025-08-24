#!/bin/sh

# ==========================================
# Container startup script - Simplified
# ==========================================

set -e

echo "🚀 Starting Laravel container..."

# Start PHP-FPM in background
echo "📦 Starting PHP-FPM..."
php-fpm -D

# Give PHP-FPM time to start
echo "⏳ Waiting for PHP-FPM..."
sleep 3

echo "✅ PHP-FPM started!"

# Start Nginx in foreground
echo "🌐 Starting Nginx..."
exec nginx -g "daemon off;"
