# 🐘 PHP DevOps Guide Completo

## 📋 Índice
- [PHP-FPM Fundamentals](#php-fpm-fundamentals)
- [Container Optimization](#container-optimization)
- [Performance Tuning](#performance-tuning)
- [Monitoring & Observability](#monitoring--observability)
- [Security Best Practices](#security-best-practices)
- [Laravel Specific](#laravel-specific)
- [Troubleshooting](#troubleshooting)

## 🚀 PHP-FPM Fundamentals

### O que é PHP-FPM?
**FPM (FastCGI Process Manager)** é uma implementação primária do PHP FastCGI contendo recursos essenciais para aplicações de alta performance:

- **Gerenciamento avançado de processos** com parada/início elegante
- **Pools independentes** com diferentes uid/gid/chroot/environment
- **Logging configurável** stdout e stderr
- **Reinicialização de emergência** em caso de falhas
- **Upload acelerado** para arquivos grandes
- **Slowlog** para debugging de scripts lentos

### Configurações Críticas para DevOps

#### `/etc/php-fpm.conf` - Configuração Global
```ini
; Global Configuration
error_log = /var/log/php-fpm.log
log_level = notice
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s
```

#### Pool Configuration - `/etc/php-fpm.d/www.conf`
```ini
[www]
; Process Management
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500

; Performance
pm.process_idle_timeout = 10s
pm.status_path = /fpm-status
ping.path = /fpm-ping

; Security
user = www-data
group = www-data
listen = 127.0.0.1:9000
listen.allowed_clients = 127.0.0.1

; Monitoring
pm.status_path = /status
slowlog = /var/log/php-fpm-slow.log
request_slowlog_timeout = 5s
```

## 🐳 Container Optimization

### Multi-stage Dockerfile Otimizado
```dockerfile
# Build stage
FROM php:8.2-fpm-alpine AS builder
RUN apk add --no-cache \
    composer \
    zip \
    unzip \
    git

WORKDIR /app
COPY composer.* ./
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Production stage
FROM php:8.2-fpm-alpine AS production

# Install production dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    && docker-php-ext-install \
    pdo_mysql \
    opcache \
    bcmath

# Security: Non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -u 1001 -S appuser -G appuser

# Copy optimized vendor
COPY --from=builder /app/vendor /var/www/html/vendor
COPY --chown=appuser:appuser . /var/www/html

# PHP Configuration
COPY php.ini /usr/local/etc/php/
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

USER appuser
EXPOSE 8080
```

### PHP Production Configuration
```ini
; php.ini for Production
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
implicit_flush = Off
serialize_precision = -1

; Error Handling
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php_errors.log
ignore_repeated_errors = Off

; Performance
memory_limit = 256M
max_execution_time = 30
max_input_time = 60
post_max_size = 32M
upload_max_filesize = 32M
max_file_uploads = 20

; Security
expose_php = Off
allow_url_fopen = Off
allow_url_include = Off
session.cookie_httponly = On
session.cookie_secure = On
session.use_strict_mode = On

; OPcache (Critical for Performance)
[opcache]
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 4000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1
opcache.validate_timestamps = 0
```

## ⚡ Performance Tuning

### CPU & Memory Optimization
```bash
# Calculate optimal pm.max_children
# Formula: (Available RAM - Other processes) / Average process size
# Example: (1GB - 200MB) / 20MB = 40 children

# Monitor memory usage
ps aux | grep php-fpm | awk '{sum+=$6} END {print "Total memory: " sum/1024 " MB"}'

# Check process distribution
pgrep -c php-fpm
```

### OPcache Monitoring
```php
<?php
// opcache-status.php
$status = opcache_get_status();
$config = opcache_get_configuration();

echo "Hit Rate: " . round($status['opcache_statistics']['opcache_hit_rate'], 2) . "%\n";
echo "Memory Usage: " . round($status['memory_usage']['used_memory']/1024/1024) . "MB\n";
echo "Cached Files: " . $status['opcache_statistics']['num_cached_scripts'] . "\n";
?>
```

### Laravel Specific Optimizations
```bash
# Production optimizations
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# Clear development caches
php artisan optimize:clear

# Database optimization
php artisan migrate --force
php artisan db:seed --force
```

## 📊 Monitoring & Observability

### Health Check Endpoints
```php
<?php
// health.php - Simple health check
header('Content-Type: application/json');

$health = [
    'status' => 'healthy',
    'timestamp' => date('c'),
    'version' => '1.0.0'
];

// Database check
try {
    $pdo = new PDO($_ENV['DATABASE_URL']);
    $health['database'] = 'connected';
} catch (Exception $e) {
    $health['status'] = 'unhealthy';
    $health['database'] = 'disconnected';
    http_response_code(503);
}

// OPcache check
if (function_exists('opcache_get_status')) {
    $opcache = opcache_get_status();
    $health['opcache'] = $opcache['opcache_enabled'] ? 'enabled' : 'disabled';
}

echo json_encode($health);
?>
```

### Prometheus Metrics
```php
<?php
// metrics.php
header('Content-Type: text/plain');

$fpm_status = file_get_contents('http://127.0.0.1/fpm-status?json');
$status = json_decode($fpm_status, true);

echo "# HELP php_fpm_processes Current number of processes\n";
echo "# TYPE php_fpm_processes gauge\n";
echo "php_fpm_processes{state=\"active\"} " . $status['active-processes'] . "\n";
echo "php_fpm_processes{state=\"idle\"} " . $status['idle-processes'] . "\n";

echo "# HELP php_fpm_requests_total Total number of requests\n";
echo "# TYPE php_fpm_requests_total counter\n";
echo "php_fpm_requests_total " . $status['accepted-conn'] . "\n";

if (function_exists('opcache_get_status')) {
    $opcache = opcache_get_status();
    echo "# HELP php_opcache_hit_rate OPcache hit rate\n";
    echo "# TYPE php_opcache_hit_rate gauge\n";
    echo "php_opcache_hit_rate " . $opcache['opcache_statistics']['opcache_hit_rate'] . "\n";
}
?>
```

### Log Aggregation Configuration
```yaml
# docker-compose.yml snippet for logging
version: '3.8'
services:
  php-app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        labels: "service=php-app"
```

## 🔒 Security Best Practices

### Container Security
```dockerfile
# Security hardening
RUN apk add --no-cache dumb-init
ENTRYPOINT ["dumb-init", "--"]

# Remove unnecessary packages
RUN apk del .build-deps

# Set proper permissions
RUN chown -R appuser:appuser /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 644 /var/www/html/storage
```

### PHP Security Configuration
```ini
; Additional security settings
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
open_basedir = /var/www/html:/tmp
session.cookie_samesite = "Strict"
session.cookie_lifetime = 0
session.gc_maxlifetime = 1440
```

### Laravel Security
```php
// .env production settings
APP_DEBUG=false
APP_ENV=production
LOG_CHANNEL=stderr
SESSION_DRIVER=redis
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
```

## 🚨 Troubleshooting

### Common Issues & Solutions

#### 1. High Memory Usage
```bash
# Check memory per process
ps aux | grep php-fpm | awk '{print $6}' | sort -n

# Optimize configuration
# Reduce pm.max_children if memory usage is high
# Check for memory leaks in application code
```

#### 2. Slow Response Times
```bash
# Enable slow log
echo "request_slowlog_timeout = 5s" >> /etc/php-fpm.d/www.conf
echo "slowlog = /var/log/php-fpm-slow.log" >> /etc/php-fpm.d/www.conf

# Monitor slow queries
tail -f /var/log/php-fpm-slow.log
```

#### 3. 502 Bad Gateway
```bash
# Check PHP-FPM status
systemctl status php-fpm

# Check socket permissions
ls -la /var/run/php-fpm/

# Test PHP-FPM directly
cgi-fcgi -bind -connect 127.0.0.1:9000
```

#### 4. OPcache Issues
```bash
# Clear OPcache
curl -X POST http://localhost/opcache-reset.php

# Check OPcache status
curl http://localhost/opcache-status.php
```

### Debugging Commands
```bash
# Process monitoring
watch -n 2 'ps aux | grep php-fpm'

# Connection monitoring
netstat -tulpn | grep :9000

# Log monitoring
tail -f /var/log/php-fpm.log /var/log/nginx/error.log

# Performance profiling
strace -p $(pgrep php-fpm | head -1) -e write

# Memory analysis
pmap -x $(pgrep php-fpm | head -1)
```

## 📈 Performance Benchmarking

### Load Testing with Apache Bench
```bash
# Basic load test
ab -n 1000 -c 10 http://localhost/health.php

# With keepalive
ab -n 1000 -c 10 -k http://localhost/

# Monitor during test
watch -n 1 'ps aux | grep php-fpm | wc -l'
```

### Key Metrics to Monitor
```
- Response Time (p95 < 200ms)
- Memory Usage (< 80% of available)
- CPU Usage (< 70% sustained)
- Process Count (within pm.max_children)
- Hit Rate (OPcache > 95%)
- Error Rate (< 0.1%)
```

## 🎯 Production Deployment Checklist

### Pre-deployment
- [ ] OPcache enabled and configured
- [ ] Error logging enabled, display disabled
- [ ] Memory limits appropriate for workload
- [ ] File upload limits set correctly
- [ ] Security functions disabled
- [ ] Session configuration hardened

### Post-deployment
- [ ] Health checks responding
- [ ] Metrics collection working
- [ ] Log aggregation configured
- [ ] Monitoring alerts set up
- [ ] Performance baselines established
- [ ] Backup procedures tested

### Scaling Considerations
- [ ] Horizontal scaling with load balancer
- [ ] Session storage externalized (Redis)
- [ ] File storage externalized (S3/NFS)
- [ ] Database connection pooling
- [ ] CDN for static assets
- [ ] Auto-scaling policies defined

---

**💡 Pro Tips para DevOps:**
1. **Sempre monitore** memory_get_peak_usage() em produção
2. **Use OPcache** - pode melhorar performance em 3x
3. **Externalize sessions** para permitir scaling horizontal
4. **Monitor slow logs** para identificar gargalos
5. **Test failover scenarios** regularmente
6. **Keep PHP updated** por segurança e performance
7. **Use APM tools** como New Relic ou DataDog para insights profundos

Este guia cobre os aspectos essenciais que todo DevOps precisa dominar para operar PHP em produção com excelência! 🚀