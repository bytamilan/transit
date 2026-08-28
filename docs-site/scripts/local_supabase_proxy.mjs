#!/usr/bin/env node
// Local-only reverse proxy so @supabase/supabase-js's hardcoded /auth/v1 and
// /rest/v1 path conventions reach this repo's local compose stack, which
// exposes GoTrue and PostgREST unprefixed on separate ports (no Kong/gateway
// in deploy/compose/compose.yaml). Ephemeral — started and stopped only for
// Playwright portal screenshot capture (docs-site/scripts/portal_shots.spec.ts),
// never touches the shared stack.
import http from 'node:http';

const PORT = process.env.PROXY_PORT ?? 54321;
const AUTH_TARGET = process.env.AUTH_TARGET ?? 'http://localhost:9999';
const REST_TARGET = process.env.REST_TARGET ?? 'http://localhost:3000';

// GoTrue/PostgREST in this repo's compose stack aren't configured with CORS
// headers for the portal's dev-server origin (there's no Kong/gateway doing
// that either — see the header comment above). The browser's
// @supabase/supabase-js client calls this proxy cross-origin (portal on
// :3002/:3000, proxy on :54321), so the proxy adds permissive CORS headers
// itself rather than relying on the upstream services to send them.
// Local-only, ephemeral — never applies to the shared stack.
function withCors(req, res) {
  const origin = req.headers.origin ?? '*';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader(
    'Access-Control-Allow-Headers',
    req.headers['access-control-request-headers'] ?? 'authorization,apikey,content-type,x-client-info'
  );
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
}

function forward(req, res, targetBase, strippedPrefix) {
  const url = new URL(req.url, 'http://local');
  const targetPath = url.pathname.replace(strippedPrefix, '') + url.search;
  const target = new URL(targetPath, targetBase);
  const proxyReq = http.request(target, { method: req.method, headers: req.headers }, (proxyRes) => {
    res.writeHead(proxyRes.statusCode ?? 502, { ...proxyRes.headers, ...corsHeaders(res) });
    proxyRes.pipe(res);
  });
  proxyReq.on('error', (err) => {
    res.writeHead(502);
    res.end(`proxy error: ${err.message}`);
  });
  req.pipe(proxyReq);
}

// writeHead() replaces headers set via setHeader(), so capture what withCors()
// set and merge it back in explicitly when we write the proxied response.
function corsHeaders(res) {
  const names = res.getHeaderNames();
  return Object.fromEntries(names.map((name) => [name, res.getHeader(name)]));
}

const server = http.createServer((req, res) => {
  withCors(req, res);
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  if (req.url?.startsWith('/auth/v1')) return forward(req, res, AUTH_TARGET, '/auth/v1');
  if (req.url?.startsWith('/rest/v1')) return forward(req, res, REST_TARGET, '/rest/v1');
  res.writeHead(404);
  res.end('not found');
});

server.listen(PORT, () => {
  console.log(`local supabase proxy listening on :${PORT} -> auth ${AUTH_TARGET}, rest ${REST_TARGET}`);
});
