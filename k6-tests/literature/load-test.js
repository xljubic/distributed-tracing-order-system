import http from 'k6/http';
import { check } from 'k6';

const executor = __ENV.EXECUTOR || 'constant-vus';
const duration = __ENV.DURATION || '60s';
const vus = Number(__ENV.VUS || 10);

const scenario = {
  executor,
  exec: 'default',
};

if (executor === 'constant-arrival-rate') {
  scenario.rate = Number(__ENV.RATE);
  scenario.timeUnit = '1s';
  scenario.duration = duration;
  scenario.preAllocatedVUs = Number(__ENV.PREALLOCATED_VUS || 100);
  scenario.maxVUs = Number(__ENV.MAX_VUS || 1000);
} else if (executor === 'ramping-arrival-rate') {
  scenario.startRate = Number(__ENV.START_RATE);
  scenario.timeUnit = '1s';
  scenario.preAllocatedVUs = Number(__ENV.PREALLOCATED_VUS || 300);
  scenario.maxVUs = Number(__ENV.MAX_VUS || 2000);
  scenario.stages = [
    {
      target: Number(__ENV.TARGET_RATE),
      duration,
    },
  ];
} else if (executor === 'ramping-vus') {
  scenario.startVUs = Number(__ENV.START_VUS || 2);
  scenario.stages = [
    {
      target: Number(__ENV.TARGET_VUS || 100),
      duration,
    },
  ];
} else if (executor === 'shared-iterations') {
  scenario.vus = vus;
  scenario.iterations = Number(__ENV.TOTAL_REQUESTS);
  scenario.maxDuration = __ENV.MAX_DURATION || '24h';
} else if (executor === 'constant-vus') {
  scenario.vus = vus;
  scenario.duration = duration;
} else {
  throw new Error(`Unsupported executor: ${executor}`);
}

export const options = {
  scenarios: {
    default: scenario,
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
  },
};

const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
const protocol = __ENV.PROTOCOL || 'rest';
const shape = __ENV.SHAPE || 'flat';
const payloadSize = __ENV.PAYLOAD_SIZE || 'small';

export default function () {
  const response = http.get(
    `${baseUrl}/api/supplementary/literature/${protocol}/${shape}/${payloadSize}`,
  );

  check(response, {
    'supplementary response is successful': (result) =>
      result.status >= 200 && result.status < 300,
  });
}