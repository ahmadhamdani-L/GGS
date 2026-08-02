// GGS Werewolf — Load Test Script (k6)
// Run: k6 run scripts/load-test.js
// Install: brew install k6

import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';
const WS_URL = __ENV.WS_URL || 'ws://localhost:8080/ws';

// Custom metrics
const loginSuccess = new Rate('login_success');
const wsConnected = new Rate('ws_connected');
const roomCreated = new Counter('rooms_created');

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up to 50 users
    { duration: '1m', target: 100 },   // Hold at 100
    { duration: '2m', target: 200 },   // Peak at 200
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],   // 95% of requests under 500ms
    login_success: ['rate>0.95'],       // 95% login success rate
    ws_connected: ['rate>0.90'],        // 90% WS connection success
  },
};

export default function () {
  // 1. Register/Login
  const email = `loadtest_${__VU}_${__ITER}@test.com`;
  const loginRes = http.post(`${BASE_URL}/api/auth/guest`, JSON.stringify({
    displayName: `LoadBot_${__VU}`,
  }), { headers: { 'Content-Type': 'application/json' } });

  const success = check(loginRes, { 'login 2xx': (r) => r.status >= 200 && r.status < 300 });
  loginSuccess.add(success);

  if (!success) {
    sleep(1);
    return;
  }

  const token = loginRes.json('accessToken');

  // 2. Get Profile
  const profileRes = http.get(`${BASE_URL}/api/profile`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  check(profileRes, { 'profile 200': (r) => r.status === 200 });

  // 3. WebSocket Connection
  const wsRes = ws.connect(`${WS_URL}?token=${token}`, {}, function (socket) {
    wsConnected.add(1);

    socket.on('open', () => {
      // Create a room
      socket.send(JSON.stringify({
        type: 'create_room',
        payload: { userId: loginRes.json('userId'), maxPlayers: 8 },
      }));
      roomCreated.add(1);
    });

    socket.on('message', (msg) => {
      // Just consume messages
    });

    socket.setTimeout(() => {
      socket.close();
    }, 5000); // Stay connected for 5s
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: '  ', enableColors: true }),
  };
}

function textSummary(data) {
  return JSON.stringify(data.metrics, null, 2);
}
