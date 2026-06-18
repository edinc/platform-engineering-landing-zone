import http from 'node:http';
import pino from 'pino';

const logger = pino({ name: '${{ values.componentId }}' });
const port = Number(process.env.PORT || ${{ values.port }});
const requestCounts = new Map();

function record(status) {
  requestCounts.set(status, (requestCounts.get(status) || 0) + 1);
}

function metrics() {
  const lines = [
    '# HELP http_server_requests_total Total HTTP requests by status code.',
    '# TYPE http_server_requests_total counter',
  ];
  for (const [status, count] of requestCounts.entries()) {
    lines.push(`http_server_requests_total{service="${{ values.componentId }}",status="${status}"} ${count}`);
  }
  return `${lines.join('\n')}\n`;
}

const server = http.createServer((req, res) => {
  if (req.url === '/healthz') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }
  if (req.url === '/metrics') {
    res.writeHead(200, { 'content-type': 'text/plain; version=0.0.4' });
    res.end(metrics());
    return;
  }

  logger.info({ path: req.url }, 'request received');
  record('200');
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ service: '${{ values.componentId }}', team: '${{ values.teamName }}' }));
});

server.listen(port, '0.0.0.0', () => {
  logger.info({ port }, 'service listening');
});
