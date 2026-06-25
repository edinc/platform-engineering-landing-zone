# Architecture decision records

This directory contains accepted and proposed architecture decision records
for the platform landing zone. Use [`0000-template.md`](0000-template.md) for
new ADRs.

Next free number: **0057**

| ADR | Title | Status | File |
|-----|-------|--------|------|
| 0001 | Primary IaC | Accepted | [`0001-iac.md`](0001-iac.md) |
| 0002 | GitOps engine | Seeded in plan | Pending |
| 0003 | Cluster ingress | Seeded in plan | Pending |
| 0004 | Service mesh | Accepted | [`0004-no-mesh.md`](0004-no-mesh.md) |
| 0005 | Azure-resource provisioning from cluster | Accepted | [`0005-aso-boundary.md`](0005-aso-boundary.md) |
| 0006 | Secrets in cluster | Accepted | [`0006-secrets-in-cluster.md`](0006-secrets-in-cluster.md) |
| 0007 | Image signing | Accepted | [`0007-image-signing.md`](0007-image-signing.md) |
| 0008 | Subscription vending | Accepted | [`0008-subscription-vending.md`](0008-subscription-vending.md) |
| 0009 | AKS dataplane | Seeded in plan | Pending |
| 0010 | AKS node auto-provisioning | Seeded in plan | Pending |
| 0011 | Compliance baseline | Accepted | [`0011-compliance-baseline.md`](0011-compliance-baseline.md) |
| 0012 | Backstage hosting | Accepted | [`0012-backstage-hosting.md`](0012-backstage-hosting.md) |
| 0013 | Repository topology | Seeded in plan | Pending |
| 0014 | Terraform state | Accepted | [`0014-terraform-state.md`](0014-terraform-state.md) |
| 0015 | Internal API auth | Seeded in plan | Pending |
| 0016 | Image promotion | Accepted | [`0016-image-promotion.md`](0016-image-promotion.md) |
| 0017 | DR posture | Seeded in plan | Pending |
| 0018 | Developer inner loop | Accepted | [`0018-inner-loop.md`](0018-inner-loop.md) |
| 0019 | CI scanning | Accepted | [`0019-ci-scanning.md`](0019-ci-scanning.md) |
| 0020 | Backstage build-vs-buy | Accepted | [`0020-build-vs-buy.md`](0020-build-vs-buy.md) |
| 0021 | Pre-commit framework and local quality gates | Accepted | [`0021-pre-commit.md`](0021-pre-commit.md) |
| 0022 | Conventional Commits and Release Please | Accepted | [`0022-conventional-commits-release-please.md`](0022-conventional-commits-release-please.md) |
| 0023 | SCM branching and GitHub Environments | Accepted | [`0023-scm-branching.md`](0023-scm-branching.md) |
| 0024 | Break-glass procedure | Accepted | [`0024-break-glass.md`](0024-break-glass.md) |
| 0025 | OIDC federation policy | Accepted | [`0025-oidc-federation.md`](0025-oidc-federation.md) |
| 0026 | AVM module pinning and subscription-baseline composition | Accepted | [`0026-avm-modules.md`](0026-avm-modules.md) |
| 0027 | Policy exception workflow and approver matrix | Accepted | [`0027-policy-exception.md`](0027-policy-exception.md) |
| 0028 | Subscription topology and ALZ ownership boundary | Accepted | [`0028-subscription-topology.md`](0028-subscription-topology.md) |
| 0029 | Custom RBAC roles and group-only assignments | Accepted | [`0029-custom-roles.md`](0029-custom-roles.md) |
| 0030 | Hub-and-spoke networking for MVP | Accepted | [`0030-hub-and-spoke.md`](0030-hub-and-spoke.md) |
| 0031 | Default-deny egress and FQDN allowlist | Accepted | [`0031-default-deny-egress.md`](0031-default-deny-egress.md) |
| 0032 | Platform-internal eventing uses Azure Service Bus | Accepted | [`0032-platform-eventing.md`](0032-platform-eventing.md) |
| 0033 | AKS namespace as workload-scope vending unit | Accepted | [`0033-aks-namespace-vending.md`](0033-aks-namespace-vending.md) |
| 0034 | Vending request schema | Accepted | [`0034-vending-request-schema.md`](0034-vending-request-schema.md) |
| 0035 | Dependency updater strategy | Accepted | [`0035-dependency-updater-strategy.md`](0035-dependency-updater-strategy.md) |
| 0036 | Kyverno as single in-cluster policy engine | Accepted | [`0036-kyverno-single-engine.md`](0036-kyverno-single-engine.md) |
| 0037 | OTel resource attributes and log fields | Accepted | [`0037-otel-conventions.md`](0037-otel-conventions.md) |
| 0038 | SLO tooling | Accepted | [`0038-slo-tooling.md`](0038-slo-tooling.md) |
| 0039 | On-call tooling | Accepted | [`0039-on-call-tooling.md`](0039-on-call-tooling.md) |
| 0040 | Status page tooling | Accepted | [`0040-status-page-tooling.md`](0040-status-page-tooling.md) |
| 0041 | Backstage RBAC | Accepted | [`0041-backstage-rbac.md`](0041-backstage-rbac.md) |
| 0042 | TechDocs storage | Accepted | [`0042-techdocs-storage.md`](0042-techdocs-storage.md) |
| 0043 | Ownership matrix | Accepted | [`0043-ownership-matrix.md`](0043-ownership-matrix.md) |
| 0044 | Template versioning | Accepted | [`0044-template-versioning.md`](0044-template-versioning.md) |
| 0045 | Game-day cadence and scope | Seeded in Stage 12 | Pending |
| 0046 | Post-mortem retention and PII handling | Seeded in Stage 12 | Pending |
| 0047 | Policy testing split | Accepted | [`0047-policy-testing-split.md`](0047-policy-testing-split.md) |
| 0048 | Runner connectivity model | Accepted | [`0048-runner-connectivity.md`](0048-runner-connectivity.md) |
| 0049 | DDoS protection posture | Accepted | [`0049-ddos-protection.md`](0049-ddos-protection.md) |
| 0050 | ACA managed environment as a platform shared service | Accepted | [`0050-aca-managed-environment.md`](0050-aca-managed-environment.md) |
| 0051 | Cross-repo GitHub writes | Accepted | [`0051-cross-repo-github-writes.md`](0051-cross-repo-github-writes.md) |
| 0052 | Backstage Postgres passwordless auth | Accepted | [`0052-backstage-postgres-auth.md`](0052-backstage-postgres-auth.md) |
| 0053 | ACA GitOps exception | Accepted | [`0053-aca-gitops-exception.md`](0053-aca-gitops-exception.md) |
| 0054 | Flux controller Workload Identity migration | Accepted | [`0054-flux-controller-workload-identity-migration.md`](0054-flux-controller-workload-identity-migration.md) |
| 0055 | Dedicated public Backstage ingress for demo access | Accepted | [`0055-public-backstage-ingress.md`](0055-public-backstage-ingress.md) |
| 0056 | Dedicated Backstage GitHub App | Accepted | [`0056-backstage-github-app.md`](0056-backstage-github-app.md) |

ADR seeds 0002-0020 are defined in [`plan/plan.md` section 9](../../plan/plan.md#9-key-architecture-decisions-adr-seeds).
Later seeds are introduced by the stage files under [`plan/stages/`](../../plan/stages/).
Promote seeded ADRs to full ADR files as their owning stages are implemented.
