// ${{ values.name }} — the smallest service that satisfies the DevOps94 golden-path contract:
//   * listens on $PORT (8080)
//   * serves GET $BASE_PATH/health -> 200  (used by the ALB health check)
//   * logs JSON lines to stdout          (collected by CloudWatch Logs)
// No dependencies: fast builds, tiny image, nothing to patch.
const http = require('node:http');

const PORT = Number(process.env.PORT || 8080);
const BASE_PATH = (process.env.BASE_PATH || '').replace(/\/$/, ''); // e.g. /dev/${{ values.name }}
const INFO = {
  service: process.env.SERVICE_NAME || '${{ values.name }}',
  environment: process.env.ENVIRONMENT || 'local',
  version: process.env.APP_VERSION || 'dev',
};

function log(level, msg, extra = {}) {
  console.log(JSON.stringify({ time: new Date().toISOString(), level, msg, ...INFO, ...extra }));
}

function handler(req, res) {
  const started = Date.now();
  const url = new URL(req.url, 'http://localhost');
  // The ALB forwards the full path (/dev/${{ values.name }}/health); strip our prefix.
  let path = url.pathname;
  if (BASE_PATH && path.startsWith(BASE_PATH)) path = path.slice(BASE_PATH.length) || '/';

  const send = (status, body) => {
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
    if (path !== '/health') {
      log('info', 'request', { method: req.method, path: url.pathname, status, ms: Date.now() - started });
    }
  };

  if (req.method === 'GET' && path === '/health') return send(200, { status: 'ok' });
  if (req.method === 'GET' && path === '/') {
    return send(200, { ...INFO, message: 'Hello from the DevOps94 IDP', time: new Date().toISOString() });
  }
  return send(404, { error: 'not found', path: url.pathname });
}

const server = http.createServer(handler);

if (require.main === module) {
  server.listen(PORT, () => log('info', 'listening', { port: PORT, basePath: BASE_PATH }));
  // ECS sends SIGTERM before stopping a task: finish in-flight requests, then exit.
  process.on('SIGTERM', () => {
    log('info', 'SIGTERM received, shutting down');
    server.close(() => process.exit(0));
  });
}

module.exports = { server };
