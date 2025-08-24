<?php

use App\Http\Controllers\HealthController;
use App\Http\Controllers\MetricsController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes - Para demonstração K8s
|--------------------------------------------------------------------------
*/

// ==========================================
// Health Check Endpoints (Kubernetes)
// ==========================================

// Liveness Probe - Processo vivo?
Route::get('/ping', [HealthController::class, 'ping'])
    ->name('health.ping');

// Readiness Probe - App pronta para tráfego?
Route::get('/ready', [HealthController::class, 'ready'])
    ->name('health.ready');

// Health Check Completo - Monitoramento detalhado
Route::get('/health', [HealthController::class, 'health'])
    ->name('health.check');

// ==========================================
// Metrics Endpoint (Prometheus)
// ==========================================

// Métricas no formato Prometheus
Route::get('/metrics', [MetricsController::class, 'index'])
    ->name('metrics.prometheus');

// ==========================================
// Stress Test Endpoints (Para Autoscaling)
// ==========================================

// Stress test para CPU/Memory
Route::get('/stress', [HealthController::class, 'stress'])
    ->name('stress.test');

// ==========================================
// Demo Endpoints
// ==========================================

// Info básica da aplicação
Route::get('/', function () {
    return response()->json([
        'message' => 'Laravel K8s Demo API',
        'version' => '1.0.0',
        'server_type' => function_exists('swoole_version') ? 'swoole' : 'php-fpm',
        'php_version' => PHP_VERSION,
        'laravel_version' => app()->version(),
        'environment' => config('app.env'),
        'timestamp' => now()->toISOString(),
        'endpoints' => [
            'health' => [
                'ping' => url('/ping'),
                'ready' => url('/ready'), 
                'health' => url('/health'),
            ],
            'monitoring' => [
                'metrics' => url('/metrics'),
            ],
            'testing' => [
                'stress' => url('/stress'),
                'info' => url('/info'),
            ]
        ]
    ]);
})->name('api.index');

// Informações do servidor (debug)
Route::get('/info', function () {
    $serverInfo = [
        'server_type' => function_exists('swoole_version') ? 'swoole' : 'php-fpm',
        'php_version' => PHP_VERSION,
        'php_sapi' => php_sapi_name(),
        'laravel_version' => app()->version(),
        'environment' => config('app.env'),
        'memory_limit' => ini_get('memory_limit'),
        'memory_usage_mb' => round(memory_get_usage(true) / 1024 / 1024, 2),
        'memory_peak_mb' => round(memory_get_peak_usage(true) / 1024 / 1024, 2),
        'opcache_enabled' => function_exists('opcache_get_status') && opcache_get_status(false) !== false,
        'timestamp' => now()->toISOString(),
    ];

    // Informações específicas Swoole
    if (function_exists('swoole_version')) {
        $serverInfo['swoole'] = [
            'version' => swoole_version(),
            'cpu_cores' => swoole_cpu_num(),
        ];
    }

    // Informações OPcache
    if (function_exists('opcache_get_status')) {
        $opcacheStatus = opcache_get_status(false);
        if ($opcacheStatus) {
            $serverInfo['opcache'] = [
                'enabled' => $opcacheStatus['opcache_enabled'],
                'hit_rate' => $opcacheStatus['opcache_statistics']['opcache_hit_rate'] ?? 0,
                'memory_used_mb' => round($opcacheStatus['memory_usage']['used_memory'] / 1024 / 1024, 2),
                'scripts_cached' => $opcacheStatus['opcache_statistics']['num_cached_scripts'] ?? 0,
            ];
        }
    }

    return response()->json($serverInfo);
})->name('api.info');

// Teste de performance simples
Route::get('/performance', function (Request $request) {
    $iterations = min((int) $request->get('iterations', 1000), 10000);
    
    $startTime = microtime(true);
    $startMemory = memory_get_usage(true);
    
    // Operações típicas de uma aplicação web
    $results = [];
    for ($i = 0; $i < $iterations; $i++) {
        $results[] = [
            'iteration' => $i,
            'hash' => hash('sha256', "test-$i"),
            'timestamp' => microtime(true),
        ];
    }
    
    $endTime = microtime(true);
    $endMemory = memory_get_usage(true);
    
    return response()->json([
        'message' => 'Performance test completed',
        'server_type' => function_exists('swoole_version') ? 'swoole' : 'php-fpm',
        'iterations' => $iterations,
        'execution_time_ms' => round(($endTime - $startTime) * 1000, 2),
        'memory_used_mb' => round(($endMemory - $startMemory) / 1024 / 1024, 2),
        'operations_per_second' => round($iterations / ($endTime - $startTime), 2),
        'timestamp' => now()->toISOString(),
    ]);
})->name('api.performance');

// ==========================================
// Status Endpoints (Desenvolvimento)
// ==========================================

// Status geral da aplicação
Route::get('/status', function () {
    return response()->json([
        'status' => 'running',
        'uptime' => app('request')->server('REQUEST_TIME') ? time() - app('request')->server('REQUEST_TIME') : 0,
        'server_type' => function_exists('swoole_version') ? 'swoole' : 'php-fpm',
        'timestamp' => now()->toISOString(),
    ]);
})->name('api.status');
