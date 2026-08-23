import http, { setResponseCallback, expectedStatuses } from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';

setResponseCallback(expectedStatuses({ min: 200, max: 599 }));

export const options = {
  scenarios: {
    edge_case_test: {
      executor: 'constant-vus',
      vus: 5,
      duration: '2m',
    },
  },
  thresholds: {
    checks: ['rate>0.95'],
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<3000'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

function postOrder(items) {
  const payload = JSON.stringify({ items });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  return http.post(`${BASE_URL}/api/orders`, payload, params);
}

function invalidProductScenario() {
  const response = postOrder([
    {
      productId: 999999,
      quantity: 1,
    },
  ]);

  check(response, {
    'invalid product returns controlled client/server response': (r) =>
      r.status >= 400 && r.status < 600,
    'invalid product does not timeout': (r) =>
      r.timings.duration < 3000,
  });
}

function insufficientStockScenario() {
  const response = postOrder([
    {
      productId: 1,
      quantity: 200000,
    },
  ]);

  check(response, {
    'insufficient stock returns controlled client/server response': (r) =>
      r.status >= 400 && r.status < 600,
    'insufficient stock does not timeout': (r) =>
      r.timings.duration < 3000,
  });
}

function paymentFailedScenario() {
  const response = postOrder([
    {
      productId: 1,
      quantity: 12,
    },
  ]);

  check(response, {
    'payment failure returns controlled response': (r) =>
      r.status >= 200 && r.status < 600,
    'payment failure does not timeout': (r) =>
      r.timings.duration < 3000,
  });
}

export default function () {
  const scenarioIndex = exec.scenario.iterationInTest % 3;

  if (scenarioIndex === 0) {
    invalidProductScenario();
  } else if (scenarioIndex === 1) {
    insufficientStockScenario();
  } else {
    paymentFailedScenario();
  }

  sleep(1);
}