import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;

const read = file => readFileSync(join(root, file), 'utf8');

const requireContains = (file, value) => {
  const text = read(file);
  if (!text.includes(value)) {
    throw new Error(`${file} must contain ${JSON.stringify(value)}`);
  }
};

for (const value of [
  'microsoft:',
  'microsoftGraphOrg:',
  'githubDiscovery:',
  'azureBlobStorage:',
  '@backstage/plugin-kubernetes',
  '@backstage-community/plugin-flux',
  '@backstage/plugin-github-actions',
  '@backstage-community/plugin-cost-insights',
  'permission:',
]) {
  requireContains('app-config.yaml', value);
}

for (const value of [
  'backstage.io/kubernetes-id',
  'backstage.io/source-location',
  'lifecycle: production',
]) {
  requireContains('catalog-info.yaml', value);
}

const catalogEntityCount = [...read('catalog-info.yaml').matchAll(/^kind:\s+/gm)].length;
if (catalogEntityCount < 8) {
  throw new Error(`catalog-info.yaml must seed at least 8 entities, found ${catalogEntityCount}`);
}

if (read('app-config.yaml').toLowerCase().includes('kubeconfig')) {
  throw new Error('Backstage Kubernetes configuration must not contain kubeconfig material');
}

if (read('app-config.yaml').includes('githubOrgDiscovery')) {
  throw new Error('GitHub org discovery must not import identity entities');
}

console.log('Stage 09 Backstage app contract validated.');
