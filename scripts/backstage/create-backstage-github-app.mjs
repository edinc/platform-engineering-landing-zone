#!/usr/bin/env node
// Create the Backstage portal GitHub App via the GitHub App Manifest flow.
//
// GitHub App registrations cannot be created purely through the REST API; the
// manifest flow needs a one-time in-browser approval. This script serves a
// pre-filled creation form, captures GitHub's redirect, exchanges the temporary
// code, and writes the resulting credentials to a local file. It never stores
// anything in Key Vault — the operator loads the five secrets per
// docs/runbooks/backstage-ops.md ("Backstage GitHub App").
//
// Usage:
//   HOMEPAGE_URL=https://<env>.backstage.<domain> \
//   APP_NAME=pe-backstage-<env> \
//   node scripts/backstage/create-backstage-github-app.mjs
//
// Env vars:
//   APP_NAME      GitHub App name (globally unique). Default: pe-backstage.
//   HOMEPAGE_URL  App homepage (the Backstage public URL). Required.
//   OWNER         Org login to create an org-owned app. Omit for a user app.
//   PORT          Local callback port. Default: 8765.
//   OUT           Output path for credentials JSON. Default: ./backstage-github-app-creds.json.
//
// The permission set matches the scaffolder actions Backstage enables
// (repo create/push, PRs, issues, pages, workflows, webhooks) plus catalog reads.

import http from 'node:http';
import fs from 'node:fs';
import crypto from 'node:crypto';

const APP_NAME = process.env.APP_NAME || 'pe-backstage';
const HOMEPAGE_URL = process.env.HOMEPAGE_URL;
const OWNER = process.env.OWNER || '';
const PORT = Number(process.env.PORT || 8765);
const OUT = process.env.OUT || './backstage-github-app-creds.json';

if (!HOMEPAGE_URL) {
  console.error('ERROR: HOMEPAGE_URL is required (the Backstage public URL).');
  process.exit(1);
}

const STATE = crypto.randomBytes(12).toString('hex');
const createPath = OWNER
  ? `https://github.com/organizations/${OWNER}/settings/apps/new?state=${STATE}`
  : `https://github.com/settings/apps/new?state=${STATE}`;

const manifest = {
  name: APP_NAME,
  url: HOMEPAGE_URL,
  redirect_url: `http://localhost:${PORT}/callback`,
  public: false,
  hook_attributes: { url: `${HOMEPAGE_URL}/api/github/webhook`, active: false },
  default_permissions: {
    administration: 'write',
    contents: 'write',
    metadata: 'read',
    pull_requests: 'write',
    issues: 'write',
    repository_hooks: 'write',
    workflows: 'write',
    pages: 'write',
  },
  default_events: [],
};

function formPage() {
  const json = JSON.stringify(manifest).replace(/"/g, '&quot;');
  return `<!doctype html><html><head><meta charset="utf-8"><title>Create Backstage GitHub App</title>
<style>body{font-family:system-ui;margin:3rem;max-width:640px}button{font-size:1rem;padding:.6rem 1rem;cursor:pointer}</style></head>
<body><h2>Create the Backstage GitHub App</h2>
<p>Sign in to GitHub as the intended owner, then click below to open GitHub's
pre-filled "Create GitHub App" page and click <b>Create GitHub App</b>.</p>
<form action="${createPath}" method="post">
  <input type="hidden" name="manifest" value="${json}">
  <button type="submit">Open GitHub to create the app &rarr;</button>
</form></body></html>`;
}

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, `http://localhost:${PORT}`);
  if (u.pathname === '/') {
    res.writeHead(200, { 'content-type': 'text/html' });
    res.end(formPage());
    return;
  }
  if (u.pathname === '/callback') {
    const code = u.searchParams.get('code');
    if (!code || u.searchParams.get('state') !== STATE) {
      res.writeHead(400);
      res.end('Missing code or state mismatch.');
      return;
    }
    try {
      const r = await fetch(`https://api.github.com/app-manifests/${code}/conversions`, {
        method: 'POST',
        headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'create-backstage-github-app' },
      });
      const body = await r.json();
      if (!r.ok) {
        res.writeHead(500);
        res.end(`Conversion failed (HTTP ${r.status}).`);
        return;
      }
      fs.writeFileSync(OUT, JSON.stringify(body, null, 2), { mode: 0o600 });
      fs.chmodSync(OUT, 0o600); // enforce 0600 even if the file pre-existed with looser perms
      res.writeHead(200, { 'content-type': 'text/html' });
      res.end(`<h2>Created ${body.slug} (App ID ${body.id}).</h2>
<p>Credentials written to ${OUT}. Install the app: <a href="${body.html_url}/installations/new">${body.html_url}/installations/new</a></p>`);
      console.log(`Created App ID ${body.id} (slug ${body.slug}). Credentials -> ${OUT}`);
      console.log(`Install on the platform repos: ${body.html_url}/installations/new`);
      server.close();
    } catch (e) {
      res.writeHead(500);
      res.end(`error: ${e.message}`);
      server.close();
    }
    return;
  }
  res.writeHead(404);
  res.end('not found');
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Open http://localhost:${PORT}/ in a browser signed in to GitHub as the app owner.`);
});
