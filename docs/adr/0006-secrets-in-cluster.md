# ADR-0006: Default to Secrets Store CSI with ESO as an exception path

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 07 - GitOps and in-cluster platform

## Context

The platform must keep Azure Key Vault as the durable source of truth for
secrets and certificates while supporting workloads and controllers that require
Kubernetes `Secret` objects. Long-lived secret material must not be committed to
Git or stored in workflow variables.

## Decision

Use the Secrets Store CSI driver with the Azure Key Vault provider as the
default secret delivery mechanism. Install External Secrets Operator as the
approved alternative when an application or controller requires a Kubernetes
`Secret` object.

All secret consumers must declare a rotation contract covering owner, maximum
age, reload signal, and validation evidence. Workload access uses Workload
Identity and Key Vault RBAC, not static credentials.

## Consequences

- Most workloads consume secrets as mounted files backed by Key Vault.
- ESO is allowed when a Kubernetes `Secret` is unavoidable, but the Key Vault
  object remains the source of truth.
- Rotation is operationally explicit and testable through
  `docs/runbooks/secret-rotation.md`.
- Golden paths must include secret ownership and reload metadata.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Kubernetes Secrets only | Moves durable secret state into etcd and GitOps workflows. |
| ESO only | Forces Kubernetes `Secret` material even when file mounts are enough. |
| Application-managed Key Vault SDK calls only | Leaves too much boilerplate to app teams and does not cover controllers. |

## References

- [`platform-gitops/clusters/_base/platform/secrets.yaml`](../../platform-gitops/clusters/_base/platform/secrets.yaml)
- [`docs/runbooks/secret-rotation.md`](../runbooks/secret-rotation.md)
- [`plan/stages/stage-07-gitops-incluster.md`](../../plan/stages/stage-07-gitops-incluster.md)
