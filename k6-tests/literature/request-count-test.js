import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 1,
  iterations: Number(__ENV.TOTAL_REQUESTS || 100),
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
    'supplementary response is successful': (result) => result.status >= 200 && result.status < 300,
  });
}
