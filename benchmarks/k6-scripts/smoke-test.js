import http from 'k6/http';
import { check } from 'k6';

export let options = {
  vus: 1, // Single user
  duration: '30s', // Quick smoke test
  thresholds: {
    'http_req_duration': ['p(95)<100'], // Strict thresholds for smoke test
    'http_req_failed': ['rate<0.001'], // Very low error tolerance
  },
};

const BASE_URL = 'http://k8s-laraveld-laravelp-2e15132902-72eebfdc1be00901.elb.us-east-1.amazonaws.com';

export default function() {
  // Basic connectivity test
  let healthResponse = http.get(`${BASE_URL}/health`);
  
  check(healthResponse, {
    'health endpoint is accessible': (r) => r.status === 200,
    'health endpoint returns correct response': (r) => r.body === 'healthy',
    'health endpoint response time is fast': (r) => r.timings.duration < 50,
  });

  // Test additional endpoints if they exist
  let apiResponse = http.get(`${BASE_URL}/api/status`);
  
  check(apiResponse, {
    'api endpoint responds': (r) => r.status === 200 || r.status === 404,
  });
}

export function handleSummary(data) {
  let passed = data.metrics.checks.values.passes;
  let failed = data.metrics.checks.values.fails;
  let success_rate = (passed / (passed + failed)) * 100;
  
  console.log(`Smoke Test Results:`);
  console.log(`- Checks Passed: ${passed}`);
  console.log(`- Checks Failed: ${failed}`);
  console.log(`- Success Rate: ${success_rate.toFixed(2)}%`);
  
  return {
    'benchmarks/results/smoke-test-summary.json': JSON.stringify({
      test_type: 'smoke',
      timestamp: new Date().toISOString(),
      success_rate: success_rate,
      total_checks: passed + failed,
      passed_checks: passed,
      failed_checks: failed,
      average_response_time: data.metrics.http_req_duration.values.avg,
    }, null, 2),
  };
}
