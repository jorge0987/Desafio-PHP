<?php

namespace App\Http\Controllers;

use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Prometheus\CollectorRegistry;
use Prometheus\Counter;
use Prometheus\Gauge;
use Prometheus\Histogram;
use Prometheus\RenderTextFormat;

/**
 * Metrics Controller para Prometheus
 * 
 * Exporta métricas específicas do PHP/Laravel para Prometheus
 * Diferencia métricas entre PHP-FPM e Swoole
 */
class MetricsController extends Controller
{
    private CollectorRegistry $registry;
    private string $namespace = 'laravel_app';

    public function __construct()
    {
        $this->registry = app(CollectorRegistry::class);
    }

    /**
     * Endpoint de métricas no formato Prometheus
     */
    public function index(): Response
    {
        // Registra métricas básicas
        $this->registerApplicationMetrics();
        $this->registerPhpMetrics();
        $this->registerServerSpecificMetrics();

        // Renderiza métricas no formato texto
        $renderer = new RenderTextFormat();
        $result = $renderer->render($this->registry->getMetricFamilySamples());

        return response($result, 200, [
            'Content-Type' => RenderTextFormat::MIME_TYPE
        ]);
    }

    /**
     * Métricas específicas da aplicação Laravel
     */
    private function registerApplicationMetrics(): void
    {
        // Request counter
        $requestCounter = $this->registry->getOrRegisterCounter(
            $this->namespace,
            'http_requests_total',
            'Total number of HTTP requests',
            ['method', 'endpoint', 'status_code', 'server_type']
        );

        // Database connection pool
        try {
            $activeConnections = $this->getDatabaseConnections();
            $dbGauge = $this->registry->getOrRegisterGauge(
                $this->namespace,
                'database_connections_active',
                'Number of active database connections',
                ['connection']
            );
            $dbGauge->set($activeConnections, [config('database.default')]);
        } catch (\Exception $e) {
            // Ignore database errors for metrics
        }

        // Cache hit rate
        $this->registerCacheMetrics();

        // Queue metrics
        $this->registerQueueMetrics();
    }

    /**
     * Métricas específicas do PHP
     */
    private function registerPhpMetrics(): void
    {
        // Memory usage
        $memoryGauge = $this->registry->getOrRegisterGauge(
            $this->namespace,
            'php_memory_usage_bytes',
            'PHP memory usage in bytes',
            ['type']
        );
        
        $memoryGauge->set(memory_get_usage(true), ['current']);
        $memoryGauge->set(memory_get_peak_usage(true), ['peak']);

        // OPcache metrics
        $this->registerOPcacheMetrics();

        // PHP-FPM specific metrics
        if (php_sapi_name() === 'fpm-fcgi') {
            $this->registerPhpFpmMetrics();
        }

        // Swoole specific metrics
        if (function_exists('swoole_version')) {
            $this->registerSwooleMetrics();
        }
    }

    /**
     * Métricas específicas do servidor (FPM vs Swoole)
     */
    private function registerServerSpecificMetrics(): void
    {
        $serverType = $this->getServerType();
        
        $serverGauge = $this->registry->getOrRegisterGauge(
            $this->namespace,
            'server_info',
            'Server information',
            ['server_type', 'php_version', 'laravel_version']
        );

        $serverGauge->set(1, [
            $serverType,
            PHP_VERSION,
            app()->version()
        ]);
    }

    /**
     * Métricas OPcache
     */
    private function registerOPcacheMetrics(): void
    {
        if (!function_exists('opcache_get_status')) {
            return;
        }

        $status = opcache_get_status(false);
        if (!$status) {
            return;
        }

        // OPcache memory
        $opcacheMemoryGauge = $this->registry->getOrRegisterGauge(
            $this->namespace,
            'opcache_memory_bytes',
            'OPcache memory usage in bytes',
            ['type']
        );

        $opcacheMemoryGauge->set($status['memory_usage']['used_memory'], ['used']);
        $opcacheMemoryGauge->set($status['memory_usage']['free_memory'], ['free']);
        $opcacheMemoryGauge->set($status['memory_usage']['wasted_memory'], ['wasted']);

        // OPcache statistics
        $opcacheStatsGauge = $this->registry->getOrRegisterGauge(
            $this->namespace,
            'opcache_statistics',
            'OPcache statistics',
            ['type']
        );

        $stats = $status['opcache_statistics'];
        $opcacheStatsGauge->set($stats['num_cached_scripts'], ['cached_scripts']);
        $opcacheStatsGauge->set($stats['hits'], ['hits']);
        $opcacheStatsGauge->set($stats['misses'], ['misses']);
        $opcacheStatsGauge->set($stats['opcache_hit_rate'], ['hit_rate']);
    }

    /**
     * Métricas específicas PHP-FPM
     */
    private function registerPhpFpmMetrics(): void
    {
        // Tentar acessar página de status PHP-FPM
        try {
            $fpmStatus = $this->getPhpFpmStatus();
            if ($fpmStatus) {
                $fpmGauge = $this->registry->getOrRegisterGauge(
                    $this->namespace,
                    'php_fpm_processes',
                    'PHP-FPM process statistics',
                    ['state']
                );

                $fpmGauge->set($fpmStatus['active processes'], ['active']);
                $fpmGauge->set($fpmStatus['idle processes'], ['idle']);
                $fpmGauge->set($fpmStatus['total processes'], ['total']);
            }
        } catch (\Exception $e) {
            // Ignore FPM status errors
        }

        // Process uptime
        $uptimeGauge = $this->registry->getOrRegisterGauge(
            $this->namespace,
            'php_process_uptime_seconds',
            'PHP process uptime in seconds'
        );
        
        // Aproximação do uptime baseado no tempo de inicialização
        $uptime = time() - (int) ($_SERVER['REQUEST_TIME'] ?? time());
        $uptimeGauge->set($uptime);
    }

    /**
     * Métricas específicas Swoole
     */
    private function registerSwooleMetrics(): void
    {
        if (!function_exists('swoole_version')) {
            return;
        }

        // Swoole server stats (se disponível)
        try {
            $swooleGauge = $this->registry->getOrRegisterGauge(
                $this->namespace,
                'swoole_server_stats',
                'Swoole server statistics',
                ['type']
            );

            // Métricas básicas Swoole
            $swooleGauge->set(swoole_cpu_num(), ['cpu_cores']);
            
            // Se tivermos acesso ao servidor Swoole
            if (isset($GLOBALS['swoole_server'])) {
                $stats = $GLOBALS['swoole_server']->stats();
                $swooleGauge->set($stats['connection_num'], ['connections']);
                $swooleGauge->set($stats['accept_count'], ['accept_count']);
                $swooleGauge->set($stats['close_count'], ['close_count']);
                $swooleGauge->set($stats['worker_num'], ['workers']);
                $swooleGauge->set($stats['task_worker_num'], ['task_workers']);
            }
        } catch (\Exception $e) {
            // Ignore Swoole errors
        }
    }

    /**
     * Métricas de Cache
     */
    private function registerCacheMetrics(): void
    {
        try {
            // Cache store info
            $cacheGauge = $this->registry->getOrRegisterGauge(
                $this->namespace,
                'cache_info',
                'Cache store information',
                ['store', 'driver']
            );

            $cacheStore = Cache::getStore();
            $driver = config('cache.default');
            
            $cacheGauge->set(1, [get_class($cacheStore), $driver]);
        } catch (\Exception $e) {
            // Ignore cache errors
        }
    }

    /**
     * Métricas de Queue
     */
    private function registerQueueMetrics(): void
    {
        try {
            $queueGauge = $this->registry->getOrRegisterGauge(
                $this->namespace,
                'queue_info',
                'Queue connection information',
                ['connection', 'driver']
            );

            $connection = config('queue.default');
            $driver = config("queue.connections.{$connection}.driver");
            
            $queueGauge->set(1, [$connection, $driver]);
        } catch (\Exception $e) {
            // Ignore queue errors
        }
    }

    /**
     * Obtém status do PHP-FPM
     */
    private function getPhpFpmStatus(): ?array
    {
        $statusUrl = 'http://127.0.0.1:9000/status?json';
        
        try {
            $context = stream_context_create([
                'http' => [
                    'timeout' => 1,
                    'method' => 'GET'
                ]
            ]);
            
            $response = file_get_contents($statusUrl, false, $context);
            return $response ? json_decode($response, true) : null;
        } catch (\Exception $e) {
            return null;
        }
    }

    /**
     * Estima número de conexões de database ativas
     */
    private function getDatabaseConnections(): int
    {
        try {
            $result = DB::select("SHOW STATUS WHERE Variable_name = 'Threads_connected'");
            return (int) ($result[0]->Value ?? 0);
        } catch (\Exception $e) {
            return 0;
        }
    }

    /**
     * Detecta tipo do servidor
     */
    private function getServerType(): string
    {
        if (function_exists('swoole_version')) {
            return 'swoole';
        }
        
        if (php_sapi_name() === 'fpm-fcgi') {
            return 'php-fpm';
        }

        return 'unknown';
    }
}
