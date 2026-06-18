# Kyverno policies

Kubernetes admission policies live here and are tested with `kyverno test`.
Stage 07 makes this the in-cluster admission source of truth; Azure Policy for
AKS/Gatekeeper remains disabled so Kyverno is the only Kubernetes admission
engine.

The Stage 07 baseline includes:

| Policy | Control |
|--------|---------|
| `require-standard-labels` | Requires `app`, `team`, `costCenter`, and `dataClassification`. |
| `disallow-latest-image-tag` | Blocks mutable `:latest` image references. |
| `require-resource-requests-limits` | Requires CPU/memory requests and limits. |
| `disallow-privileged-containers` | Blocks privileged containers. |
| `disallow-host-namespaces` | Blocks host network/PID/IPC sharing. |
| `disallow-host-path-volumes` | Blocks hostPath volumes. |
| `require-run-as-non-root` | Requires pod-level non-root execution. |
| `require-read-only-root-filesystem` | Requires read-only container root filesystems. |
| `generate-default-network-policy` | Generates default-deny NetworkPolicies. |
| `require-default-network-policy` | Fails namespace updates when generated default-deny policy is missing. |
| `require-pod-security-restricted` | Requires workload namespaces to opt into PSA restricted. |
| `require-tenant-gitops-guardrails` | Requires tenant Flux `OCIRepository` and `HelmRelease` resources to keep signed OCI sources and restricted Helm settings. |
| `restrict-cert-manager-issuers` | Keeps tenant certificate requests under the tenant namespace subdomain. |
| `restrict-external-dns-hostnames` | Keeps tenant-published DNS names under the tenant namespace subdomain. |
| `restrict-tenant-reconciler-serviceaccounts` | Blocks tenant pods and workload controllers from mounting Helm reconciler service accounts. |
| `verify-cosign-signatures` | Verifies keyless cosign signatures from this repository's GitHub Actions identity. |

Terraform mirrors these files into
`platform-cluster-state/clusters/_base/addon-config/policies/kyverno/` during
repository seeding so Flux applies the same bundle tested in CI.
