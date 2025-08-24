import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '5m', target: 200 }, // Ramp up to 200 users
    { duration: '10m', target: 500 }, // Ramp up to 500 users  
    { duration: '5m', target: 1000 }, // Ramp up to 1000 users (stress point)
    { duration: '10m', target: 1000 }, // Stay at 1000 users
    { duration: '5m', target: 0 }, // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1000'], // Allow higher thresholds for stress test
    'http_req_failed': ['rate<0.05'], // Allow up to 5% error rate
  },
};

const BASE_URL = 'http://k8s-laraveld-laravelp-2e15132902-72eebfdc1be00901.elb.us-east-1.amazonaws.com';

export default function() {
  // Stress test with minimal think time
  let response = http.get(`${BASE_URL}/health`);
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });

  // Reduced sleep time for stress testing
  sleep(0.1);
}

export function handleSummary(data) {
  return {
    'benchmarks/results/stress-test-summary.json': JSON.stringify(data, null, 2),
  };
}
