# ADR-0012: Host Backstage in AKS with Flux and Helm

- Status: accepted
- Date: 2026-06-15
- Stage: Stage 09 - Backstage MVP

## Context

The developer portal must run close to the platform control plane, use the same
GitOps and supply-chain controls as workload services, and authenticate to AKS,
Azure Blob Storage, and Postgres without long-lived credentials.

## Decision

Host Backstage in the platform AKS cluster. Package the deployment as the
`backstage/deploy` Helm chart, publish it to the platform ACR OCI repository, and
let Flux reconcile it from `platform-cluster-state`.

Backstage runs with a Workload Identity-enabled service account. The identity is
used for Azure integrations and Kubernetes API reads; kubeconfigs are not stored
in Backstage.

## Consequences

- Backstage uses the same signed-image and PR-promotion path as platform
  workloads.
- Flux owns runtime desired state and rollback history.
- Private networking, DNS, and ingress are inherited from prior stages.
- ACR chart/image availability becomes part of the Backstage dependency model.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Azure Container Apps | Simpler app hosting but weaker fit for the Kubernetes plugin and existing Flux ownership boundary. |
| VM/App Service | Adds a separate runtime model and duplicates platform controls. |
| SaaS portal | Deferred to Stage 13 build-vs-buy re-evaluation. |

## References

- [`plan/stages/stage-09-backstage-mvp.md`](../../plan/stages/stage-09-backstage-mvp.md)
- [`backstage/deploy/`](../../backstage/deploy/)
