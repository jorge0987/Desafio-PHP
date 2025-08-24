#!/bin/bash

# ==========================================
# Stress Test for Laravel K8s Autoscaling
# ==========================================

set -e

echo "🚀 Starting Laravel K8s Autoscaling Test..."

# Check if kubectl is working
if ! kubectl get pods -n laravel-demo >/dev/null 2>&1; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check if port-forward is running
if ! curl -s http://localhost:8081/ping >/dev/null 2>&1; then
    echo "🔗 Setting up port forward..."
    kubectl port-forward service/laravel-fpm-service 8081:80 -n laravel-demo &
    sleep 3
fi

echo "📊 Initial state:"
kubectl get pods -n laravel-demo
kubectl get hpa -n laravel-demo

echo ""
echo "🔥 Starting stress test with multiple concurrent requests..."
echo "📝 This will generate CPU load to trigger autoscaling"
echo ""

# Function to run stress test
run_stress() {
    for i in {1..1000}; do
        curl -s "http://localhost:8081/stress?duration=2" >/dev/null &
        if [ $((i % 50)) -eq 0 ]; then
            echo "Sent $i requests..."
        fi
    done
    wait
}

# Start stress test in background
echo "🚀 Launching stress test..."
run_stress &
STRESS_PID=$!

# Monitor autoscaling
echo "📊 Monitoring autoscaling (press Ctrl+C to stop)..."
echo ""

trap "echo 'Stopping stress test...'; kill $STRESS_PID 2>/dev/null; exit 0" INT

# Monitor loop
for i in {1..30}; do
    echo "=== Monitoring cycle $i ==="
    echo "Pods:"
    kubectl get pods -n laravel-demo -o wide
    echo ""
    echo "HPA status:"
    kubectl get hpa -n laravel-demo
    echo ""
    echo "CPU usage:"
    kubectl top pods -n laravel-demo 2>/dev/null || echo "Metrics not available yet"
    echo ""
    echo "Waiting 10 seconds..."
    echo "----------------------------------------"
    sleep 10
done

echo "✅ Stress test completed!"
echo "📊 Final state:"
kubectl get pods -n laravel-demo
kubectl get hpa -n laravel-demo
