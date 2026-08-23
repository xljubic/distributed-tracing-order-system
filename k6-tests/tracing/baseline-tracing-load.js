// Shortened background-load profile for the distributed-tracing experiment (Phase 5/16).
// Derived from k6-tests/rest/02-baseline-load-test.js (constant 10 VUs, 2m) but held for
// only 40s: this run exists purely to create realistic contention while controlled probe
// requests (with a sampled W3C traceparent header) are fired separately, not to reproduce
// the statistical final-experiment measurement.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    baseline_tracing_load: {
      executor: 'constant-vus',
      vus: 10,
      duration: '40s',
    },
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const payload = JSON.stringify({
    items: [
      {
        productId: 1,
        quantity: 1,
      },
    ],
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const response = http.post(`${BASE_URL}/api/orders`, payload, params);

  check(response, {
    'status is successful 2xx': (r) => r.status >= 200 && r.status < 300,
  });

  sleep(1);
}
