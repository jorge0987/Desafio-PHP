<?php

// ==========================================
// Minimal Laravel Bootstrap - index.php
// ==========================================

// Basic autoloader (simples para demo)
require_once __DIR__ . '/../bootstrap.php';

// Routes handler
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];

// Health check endpoints
if ($uri === '/ping' && $method === 'GET') {
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'pong',
        'server_type' => 'php-fpm',
        'php_version' => PHP_VERSION,
        'timestamp' => date('c')
    ]);
    exit;
}

if ($uri === '/health' && $method === 'GET') {
    header('Content-Type: application/json');
    
    $health = [
        'status' => 'healthy',
        'server_type' => 'php-fpm',
        'php_version' => PHP_VERSION,
        'timestamp' => date('c'),
        'checks' => [
            'opcache' => function_exists('opcache_get_status'),
            'redis' => extension_loaded('redis'),
            'pdo' => extension_loaded('pdo'),
        ]
    ];
    
    echo json_encode($health);
    exit;
}

if ($uri === '/metrics' && $method === 'GET') {
    header('Content-Type: text/plain');
    
    // Basic Prometheus metrics
    echo "# Laravel Demo Metrics\n";
    echo "laravel_app_info{version=\"1.0.0\",server_type=\"php-fpm\"} 1\n";
    echo "laravel_app_memory_usage_bytes " . memory_get_usage(true) . "\n";
    echo "laravel_app_memory_peak_bytes " . memory_get_peak_usage(true) . "\n";
    echo "laravel_app_uptime_seconds " . (time() - $_SERVER['REQUEST_TIME']) . "\n";
    
    if (function_exists('opcache_get_status')) {
        $opcache = opcache_get_status(false);
        if ($opcache) {
            echo "laravel_app_opcache_hit_rate " . ($opcache['opcache_statistics']['opcache_hit_rate'] ?? 0) . "\n";
            echo "laravel_app_opcache_memory_used_bytes " . ($opcache['memory_usage']['used_memory'] ?? 0) . "\n";
        }
    }
    
    exit;
}

if ($uri === '/stress' && $method === 'GET') {
    header('Content-Type: application/json');
    
    $duration = min((int) ($_GET['duration'] ?? 1), 5); // Max 5 segundos
    $startTime = microtime(true);
    $startMemory = memory_get_usage(true);
    
    // CPU stress
    $endTime = $startTime + $duration;
    while (microtime(true) < $endTime) {
        hash('sha256', random_bytes(1024));
    }
    
    $actualDuration = microtime(true) - $startTime;
    $memoryUsed = memory_get_usage(true) - $startMemory;
    
    echo json_encode([
        'message' => 'Stress test completed',
        'server_type' => 'php-fpm', 
        'duration_requested' => $duration,
        'duration_actual' => round($actualDuration, 2),
        'memory_used_mb' => round($memoryUsed / 1024 / 1024, 2),
        'timestamp' => date('c')
    ]);
    exit;
}

if ($uri === '/' || $uri === '/info') {
    header('Content-Type: application/json');
    echo json_encode([
        'message' => 'Laravel K8s Demo - Simple Version',
        'version' => '1.0.0',
        'server_type' => 'php-fpm',
        'php_version' => PHP_VERSION,
        'environment' => 'demo',
        'endpoints' => [
            'health' => [
                'ping' => '/ping',
                'health' => '/health',
            ],
            'monitoring' => [
                'metrics' => '/metrics',
            ],
            'testing' => [
                'stress' => '/stress?duration=2',
                'info' => '/info',
            ]
        ],
        'timestamp' => date('c')
    ]);
    exit;
}

// 404 for other routes
header('HTTP/1.0 404 Not Found');
header('Content-Type: application/json');
echo json_encode(['error' => 'Not Found', 'uri' => $uri]);
exit;
