<?php

// ==========================================
// Bootstrap - Basic setup
// ==========================================

// Error reporting
error_reporting(E_ALL);
ini_set('display_errors', 0); // Never show errors in production-like setup
ini_set('log_errors', 1);
ini_set('error_log', 'php://stderr');

// Basic constants
define('APP_START_TIME', microtime(true));

// Memory limit check
$memoryLimit = ini_get('memory_limit');
if ($memoryLimit !== '-1') {
    $maxMemory = (int) substr($memoryLimit, 0, -1);
    $unit = strtolower(substr($memoryLimit, -1));
    
    switch ($unit) {
        case 'g': $maxMemory *= 1024;
        case 'm': $maxMemory *= 1024;
        case 'k': $maxMemory *= 1024;
    }
    
    if (memory_get_usage(true) > ($maxMemory * 0.8)) {
        error_log('Warning: High memory usage detected');
    }
}

// Basic environment
$_ENV['APP_NAME'] = $_ENV['APP_NAME'] ?? 'Laravel K8s Demo';
$_ENV['APP_ENV'] = $_ENV['APP_ENV'] ?? 'production';
$_ENV['APP_DEBUG'] = $_ENV['APP_DEBUG'] ?? 'false';
