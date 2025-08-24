#!/bin/bash

# Script para build e teste da aplicação Laravel

echo "🛠️  Building and testing Laravel application..."

# Move to project directory
cd /Users/jorgeoliveira/Documents/Projects/Desafio-php/app

echo "📦 Stopping any running containers..."
docker-compose down

echo "🔨 Building containers..."
docker-compose build

echo "🚀 Starting containers..."
docker-compose up -d

echo "⏳ Waiting for containers to be ready..."
sleep 10

echo "🏥 Testing health endpoints..."
echo "Testing /ping:"
curl -s http://localhost:8080/ping

echo -e "\nTesting /health:"
curl -s http://localhost:8080/health

echo -e "\nTesting /metrics:"
curl -s http://localhost:8080/metrics

echo -e "\n✅ Build and test completed!"
