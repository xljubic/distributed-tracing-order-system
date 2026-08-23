// Shortened background-load profile for the distributed-tracing experiment (Phase 5/16).
// Derived from k6-tests/rest/03-stress-test.js (5 x 1m ramps to a 75 VU peak) but each
// stage is shortened to 10s (50s total, same 75 VU peak) to create realistic contention
// while controlled probe requests are fired separately.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    stress_tracing_load: {
      executor: 'ramping-vus',
      stages: [
        { duration: '10s', target: 10 },
        { duration: '10s', target: 25 },
        { duration: '10s', target: 50 },
        { duration: '10s', target: 75 },
        { duration: '10s', target: 0 },
      ],
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
