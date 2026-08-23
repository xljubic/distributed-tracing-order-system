// Shortened background-load profile for the distributed-tracing experiment (Phase 5/16).
// Derived from k6-tests/rest/04-spike-test.js (30s/30s/1m/30s/30s ramps to a 100 VU peak)
// but the sustained-peak hold is shortened from 1m to 20s (60s total, same 10->100 VU
// spike shape) to create realistic contention while controlled probe requests are fired
// separately.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    spike_tracing_load: {
      executor: 'ramping-vus',
      stages: [
        { duration: '10s', target: 10 },
        { duration: '10s', target: 100 },
        { duration: '20s', target: 100 },
        { duration: '10s', target: 10 },
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
