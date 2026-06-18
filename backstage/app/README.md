# Backstage app

Backstage application scaffolded with `@backstage/create-app` for the platform portal.

The package keeps tenant-specific values outside git and wires the required
Backstage contracts for Entra auth, GitHub catalog discovery, Azure Blob
TechDocs, Workload Identity-backed Kubernetes views, Flux/GitHub Actions
plugins, Cost Insights, and Permission Framework RBAC.

```bash
corepack enable
yarn install --immutable
yarn test
yarn tsc
yarn build:backend
```
