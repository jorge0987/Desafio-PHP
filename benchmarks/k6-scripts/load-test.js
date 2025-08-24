import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up to 10 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'], // 95% of requests must complete below 500ms
    'http_req_failed': ['rate<0.01'],   // Error rate must be below 1%
  },
};

const BASE_URL = 'http://k8s-laraveld-laravelp-2e15132902-72eebfdc1be00901.elb.us-east-1.amazonaws.com';

export default function() {
  // Health check endpoint
  let healthResponse = http.get(`${BASE_URL}/health`);
  
  check(healthResponse, {
    'health check status is 200': (r) => r.status === 200,
    'health check returns "healthy"': (r) => r.body === 'healthy',
    'health check response time < 100ms': (r) => r.timings.duration < 100,
  });

  // API endpoint test (if available)
  let apiResponse = http.get(`${BASE_URL}/api/status`);
  
  check(apiResponse, {
    'api status is 200 or 404': (r) => r.status === 200 || r.status === 404,
    'api response time < 200ms': (r) => r.timings.duration < 200,
  });

  // Think time between requests
  sleep(1);
}

export function handleSummary(data) {
  return {
    'benchmarks/results/load-test-summary.json': JSON.stringify(data, null, 2),
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options) {
  return `
Load Test Results Summary
========================

Test Duration: ${data.state.testRunDurationMs}ms
Virtual Users: ${data.metrics.vus.values.max}

Request Metrics:
- Total Requests: ${data.metrics.http_reqs.values.count}
- Request Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)}/s
- Failed Requests: ${data.metrics.http_req_failed.values.rate.toFixed(4) * 100}%

Response Time:
- Average: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms
- Min: ${data.metrics.http_req_duration.values.min.toFixed(2)}ms
- Max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms
- p(90): ${data.metrics.http_req_duration.values['p(90)'].toFixed(2)}ms
- p(95): ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms

Data Transfer:
- Received: ${(data.metrics.data_received.values.count / 1024 / 1024).toFixed(2)} MB
- Sent: ${(data.metrics.data_sent.values.count / 1024 / 1024).toFixed(2)} MB
`;
}
