import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';

let stopping = false;
let currentChild;

async function getPostgresAccessToken() {
  const tenantId = process.env.AZURE_TENANT_ID;
  const clientId = process.env.AZURE_CLIENT_ID;
  const tokenFile = process.env.AZURE_FEDERATED_TOKEN_FILE;

  if (!tenantId || !clientId || !tokenFile) {
    throw new Error('POSTGRES_AUTH_MODE=entra requires AZURE_TENANT_ID, AZURE_CLIENT_ID, and AZURE_FEDERATED_TOKEN_FILE.');
  }

  const clientAssertion = await readFile(tokenFile, 'utf8');
  const body = new URLSearchParams({
    client_assertion: clientAssertion,
    client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
    client_id: clientId,
    grant_type: 'client_credentials',
    scope: 'https://ossrdbms-aad.database.windows.net/.default',
  });

  const response = await fetch(`https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`, {
    body,
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to acquire Postgres Entra token: ${response.status} ${await response.text()}`);
  }

  const token = await response.json();
  if (!token.access_token) {
    throw new Error('Postgres Entra token response did not include access_token.');
  }
  return {
    accessToken: token.access_token,
    expiresIn: Number(token.expires_in ?? 3600),
  };
}

async function getPostgresPassword(authMode) {
  if (authMode === 'entra') {
    return getPostgresAccessToken();
  }

  if (authMode === 'password') {
    if (process.env.POSTGRES_PASSWORD) {
      return {
        accessToken: process.env.POSTGRES_PASSWORD,
        expiresIn: Number.POSITIVE_INFINITY,
      };
    }
    if (process.env.POSTGRES_PASSWORD_FILE) {
      return {
        accessToken: (await readFile(process.env.POSTGRES_PASSWORD_FILE, 'utf8')).trim(),
        expiresIn: Number.POSITIVE_INFINITY,
      };
    }
    throw new Error('POSTGRES_AUTH_MODE=password requires POSTGRES_PASSWORD or POSTGRES_PASSWORD_FILE.');
  }

  throw new Error(`Unsupported POSTGRES_AUTH_MODE: ${authMode}`);
}

function runBackend(env, args, restartAfterSeconds) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', ['packages/backend', ...args], {
      env,
      stdio: 'inherit',
    });
    currentChild = child;
    let restarting = false;
    const restartTimer = Number.isFinite(restartAfterSeconds)
      ? setTimeout(() => {
          restarting = true;
          child.kill('SIGTERM');
        }, restartAfterSeconds * 1000)
      : undefined;

    child.on('exit', code => {
      if (restartTimer) {
        clearTimeout(restartTimer);
      }
      if (currentChild === child) {
        currentChild = undefined;
      }
      if (stopping) {
        resolve(false);
      } else if (restarting) {
        resolve(true);
      } else if (code === 0) {
        resolve(false);
      } else {
        reject(new Error(`Backstage exited with code ${code ?? 'unknown'}`));
      }
    });
  });
}

async function main() {
  const authMode = process.env.POSTGRES_AUTH_MODE ?? 'entra';

  process.on('SIGTERM', () => {
    stopping = true;
    currentChild?.kill('SIGTERM');
  });
  process.on('SIGINT', () => {
    stopping = true;
    currentChild?.kill('SIGINT');
  });

  do {
    const token = await getPostgresPassword(authMode);
    const jitterSeconds = Number.isFinite(token.expiresIn)
      ? Math.floor(Math.random() * Math.min(300, Math.max(token.expiresIn - 60, 0)))
      : 0;
    const refreshBeforeExpirySeconds = Number.isFinite(token.expiresIn)
      ? Math.max(token.expiresIn - 300 - jitterSeconds, 60)
      : Number.POSITIVE_INFINITY;
    const shouldRestart = await runBackend(
      {
        ...process.env,
        POSTGRES_PASSWORD: token.accessToken,
      },
      process.argv.slice(2),
      refreshBeforeExpirySeconds,
    );
    if (!shouldRestart) {
      return;
    }
  } while (!stopping);
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
