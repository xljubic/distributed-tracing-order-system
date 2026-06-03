import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    stress_test: {
      executor: 'ramping-vus',
      stages: [
        { duration: '1m', target: 10 },
        { duration: '1m', target: 25 },
        { duration: '1m', target: 50 },
        { duration: '1m', target: 75 },
        { duration: '1m', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<3000'],
    checks: ['rate>0.95'],
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