# 🧪 Testing Strategy

## Testing Pyramid

### Unit Tests
- **Framework**: PHPUnit for Laravel application logic
- **Coverage**: >80% code coverage target
- **Scope**: Business logic, controllers, services

### Integration Tests
- **Container Testing**: Dockerfile validation and security scanning
- **API Testing**: REST endpoint validation
- **Database Testing**: Laravel database factories and seeders

### End-to-End Tests
- **Kubernetes Testing**: Pod lifecycle and health checks
- **Load Balancer Testing**: External connectivity validation
- **Monitoring Testing**: Metrics collection and alerting

## Performance Testing

### Load Testing with K6
```javascript
// benchmarks/k6-scripts/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 50 },
    { duration: '2m', target: 0 },
  ],
};

export default function() {
  let response = http.get('http://LOAD_BALANCER_URL/health');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 100ms': (r) => r.timings.duration < 100,
  });
  sleep(1);
}
```

### Stress Testing
```bash
cd benchmarks/
k6 run --out json=results/load-test-$(date +%Y%m%d-%H%M%S).json k6-scripts/load-test.js
```

## Security Testing

### Container Security
```bash
# Trivy security scanning
trivy image 533267409012.dkr.ecr.us-east-1.amazonaws.com/laravel-k8s:k8s-v1.1.0

# Check for vulnerabilities
docker scout cves laravel-k8s:latest
```

### Kubernetes Security
```bash
# Pod Security Standards validation
kubectl auth can-i --list -n laravel
kubectl get psp -A
```

## Monitoring & Observability

### Health Check Testing
```bash
#!/bin/bash
# scripts/health-check.sh

ENDPOINT="http://k8s-laraveld-laravelp-2e15132902-72eebfdc1be00901.elb.us-east-1.amazonaws.com/health"
EXPECTED_STATUS="200"
EXPECTED_BODY="healthy"

response=$(curl -s -w "%{http_code}" $ENDPOINT)
status_code="${response: -3}"
body="${response%???}"

if [[ "$status_code" == "$EXPECTED_STATUS" && "$body" == "$EXPECTED_BODY" ]]; then
    echo "✅ Health check passed: $status_code - $body"
    exit 0
else
    echo "❌ Health check failed: $status_code - $body"
    exit 1
fi
```

### Performance Metrics
- **Response Time**: Target <50ms for health endpoints
- **Throughput**: Baseline 500 req/sec with auto-scaling
- **Error Rate**: <0.1% error rate target
- **Availability**: 99.9% uptime SLA

## CI/CD Testing

### GitHub Actions Pipeline
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
      - name: Install dependencies
        run: composer install
      - name: Run tests
        run: vendor/bin/phpunit

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -f app/Dockerfile.k8s -t test-image .
      - name: Security scan
        run: trivy image test-image

  k8s-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate Helm charts
        run: helm lint helm/laravel-app/
```

## Test Data Management

### Database Seeding
```php
// database/seeders/TestDataSeeder.php
class TestDataSeeder extends Seeder
{
    public function run()
    {
        // Create test data for different scenarios
        User::factory(100)->create();
        // Additional test data setup
    }
}
```

### Environment Management
- **Local**: Docker Compose for development
- **Staging**: Kubernetes cluster with reduced resources
- **Production**: Full EKS cluster with monitoring
