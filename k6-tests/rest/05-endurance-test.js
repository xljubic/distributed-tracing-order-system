import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    endurance_test: {
      executor: 'constant-vus',
      vus: 20,
      duration: '10m',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<3000'],
    checks: ['rate>0.98'],
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
    'order is completed': (r) => {
      try {
        return r.json('status') === 'COMPLETED';
      } catch (e) {
        return false;
      }
    },
    'response has order id': (r) => {
      try {
        return r.json('id') !== undefined && r.json('id') !== null;
      } catch (e) {
        return false;
      }
    },
  });

  sleep(1);
}