<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

/**
 * Health Check Controller
 * 
 * Implementa health checks específicos para ambientes Kubernetes
 * Diferencia entre liveness (processo vivo) e readiness (app funcionando)
 */
class HealthController extends Controller
{
    /**
     * Liveness Probe - Verifica se o processo está vivo
     * 
     * Para K8s: Se falhar, mata o pod
     * Deve ser simples e rápido (< 1s)
     */
    public function ping(): JsonResponse
    {
        return response()->json([
            'status' => 'pong',
            'timestamp' => now()->toISOString(),
            'server_type' => $this->getServerType()
        ]);
    }

    /**
     * Readiness Probe - Verifica se a aplicação está pronta para receber tráfego
     * 
     * Para K8s: Se falhar, remove do load balancer mas não mata
     * Verifica dependências críticas
     */
    public function ready(): JsonResponse
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
            'storage' => $this->checkStorage(),
        ];

        $allHealthy = collect($checks)->every(fn($check) => $check['healthy']);

        return response()->json([
            'status' => $allHealthy ? 'ready' : 'not_ready',
            'checks' => $checks,
            'timestamp' => now()->toISOString(),
            'server_type' => $this->getServerType()
        ], $allHealthy ? 200 : 503);
    }

    /**
     * Health Check Completo - Para monitoramento detalhado
     */
    public function health(): JsonResponse
    {
        $startTime = microtime(true);

        $health = [
            'status' => 'healthy',
            'version' => config('app.version', '1.0.0'),
            'environment' => config('app.env'),
            'server_type' => $this->getServerType(),
            'timestamp' => now()->toISOString(),
            'checks' => [
                'database' => $this->checkDatabase(),
                'redis' => $this->checkRedis(),
                'storage' => $this->checkStorage(),
                'opcache' => $this->checkOPcache(),
                'memory' => $this->checkMemoryUsage(),
            ],
            'response_time_ms' => round((microtime(true) - $startTime) * 1000, 2)
        ];

        $allHealthy = collect($health['checks'])->every(fn($check) => $check['healthy']);
        $health['status'] = $allHealthy ? 'healthy' : 'unhealthy';

        return response()->json($health, $allHealthy ? 200 : 503);
    }

    /**
     * Stress Test Endpoint - Para testes de carga e autoscaling
     */
    public function stress(Request $request): JsonResponse
    {
        $duration = min((int) $request->get('duration', 1), 10); // Max 10 segundos
        $memory = min((int) $request->get('memory', 1), 50); // Max 50MB
        
        $startTime = microtime(true);
        $startMemory = memory_get_usage(true);

        // CPU stress
        $endTime = $startTime + $duration;
        while (microtime(true) < $endTime) {
            // Operação intensiva de CPU
            hash('sha256', random_bytes(1024));
        }

        // Memory stress
        $data = [];
        for ($i = 0; $i < $memory; $i++) {
            $data[] = str_repeat('x', 1024 * 1024); // 1MB cada
        }

        $endTime = microtime(true);
        $endMemory = memory_get_usage(true);

        return response()->json([
            'message' => 'Stress test completed',
            'server_type' => $this->getServerType(),
            'duration_requested' => $duration,
            'duration_actual' => round($endTime - $startTime, 2),
            'memory_requested_mb' => $memory,
            'memory_used_mb' => round(($endMemory - $startMemory) / 1024 / 1024, 2),
            'peak_memory_mb' => round(memory_get_peak_usage(true) / 1024 / 1024, 2),
            'timestamp' => now()->toISOString()
        ]);
    }

    /**
     * Detecta se está rodando PHP-FPM ou Swoole
     */
    private function getServerType(): string
    {
        if (function_exists('swoole_version')) {
            return 'swoole-' . swoole_version();
        }
        
        if (php_sapi_name() === 'fpm-fcgi') {
            return 'php-fpm-' . PHP_VERSION;
        }

        return 'unknown-' . PHP_VERSION;
    }

    /**
     * Verifica conectividade com database
     */
    private function checkDatabase(): array
    {
        try {
            $startTime = microtime(true);
            DB::select('SELECT 1');
            $responseTime = round((microtime(true) - $startTime) * 1000, 2);

            return [
                'healthy' => true,
                'response_time_ms' => $responseTime,
                'connection' => config('database.default')
            ];
        } catch (\Exception $e) {
            return [
                'healthy' => false,
                'error' => $e->getMessage(),
                'connection' => config('database.default')
            ];
        }
    }

    /**
     * Verifica conectividade com Redis
     */
    private function checkRedis(): array
    {
        try {
            $startTime = microtime(true);
            Redis::ping();
            $responseTime = round((microtime(true) - $startTime) * 1000, 2);

            return [
                'healthy' => true,
                'response_time_ms' => $responseTime,
                'host' => config('database.redis.default.host')
            ];
        } catch (\Exception $e) {
            return [
                'healthy' => false,
                'error' => $e->getMessage(),
                'host' => config('database.redis.default.host')
            ];
        }
    }

    /**
     * Verifica storage/filesystem
     */
    private function checkStorage(): array
    {
        try {
            $testFile = storage_path('app/health-check.tmp');
            file_put_contents($testFile, 'health-check');
            $content = file_get_contents($testFile);
            unlink($testFile);

            return [
                'healthy' => $content === 'health-check',
                'path' => storage_path('app')
            ];
        } catch (\Exception $e) {
            return [
                'healthy' => false,
                'error' => $e->getMessage(),
                'path' => storage_path('app')
            ];
        }
    }

    /**
     * Verifica status do OPcache
     */
    private function checkOPcache(): array
    {
        if (!function_exists('opcache_get_status')) {
            return [
                'healthy' => false,
                'error' => 'OPcache not available'
            ];
        }

        $status = opcache_get_status(false);
        
        return [
            'healthy' => $status !== false,
            'enabled' => $status['opcache_enabled'] ?? false,
            'hit_rate' => $status['opcache_statistics']['opcache_hit_rate'] ?? 0,
            'memory_usage' => [
                'used_memory' => $status['memory_usage']['used_memory'] ?? 0,
                'free_memory' => $status['memory_usage']['free_memory'] ?? 0,
                'wasted_memory' => $status['memory_usage']['wasted_memory'] ?? 0,
            ]
        ];
    }

    /**
     * Verifica uso de memória
     */
    private function checkMemoryUsage(): array
    {
        $memoryLimit = $this->parseMemoryLimit(ini_get('memory_limit'));
        $memoryUsage = memory_get_usage(true);
        $memoryPeak = memory_get_peak_usage(true);

        return [
            'healthy' => $memoryUsage < ($memoryLimit * 0.9), // Alert se > 90%
            'memory_limit_mb' => round($memoryLimit / 1024 / 1024, 2),
            'memory_usage_mb' => round($memoryUsage / 1024 / 1024, 2),
            'memory_peak_mb' => round($memoryPeak / 1024 / 1024, 2),
            'usage_percentage' => round(($memoryUsage / $memoryLimit) * 100, 2)
        ];
    }

    /**
     * Converte memory_limit para bytes
     */
    private function parseMemoryLimit(string $memoryLimit): int
    {
        if ($memoryLimit === '-1') {
            return PHP_INT_MAX;
        }

        $unit = strtolower(substr($memoryLimit, -1));
        $value = (int) substr($memoryLimit, 0, -1);

        switch ($unit) {
            case 'g': return $value * 1024 * 1024 * 1024;
            case 'm': return $value * 1024 * 1024;
            case 'k': return $value * 1024;
            default: return (int) $memoryLimit;
        }
    }
}
