# Architecture decision records

This directory contains accepted and proposed architecture decision records
for the platform landing zone. Use [`0000-template.md`](0000-template.md) for
new ADRs.

Next free number: **0054**

| ADR | Title | Status | File |
|-----|-------|--------|------|
| 0001 | Primary IaC | Accepted | [`0001-iac.md`](0001-iac.md) |
| 0002 | GitOps engine | Seeded in plan | Pending |
| 0003 | Cluster ingress | Seeded in plan | Pending |
| 0004 | Service mesh | Seeded in plan | Pending |
| 0005 | Azure-resource provisioning from cluster | Seeded in plan | Pending |
| 0006 | Secrets in cluster | Seeded in plan | Pending |
| 0007 | Image signing | Seeded in plan | Pending |
| 0008 | Subscription vending | Seeded in plan | Pending |
| 0009 | AKS dataplane | Seeded in plan | Pending |
| 0010 | AKS node auto-provisioning | Seeded in plan | Pending |
| 0011 | Compliance baseline | Accepted | [`0011-compliance-baseline.md`](0011-compliance-baseline.md) |
| 0012 | Backstage hosting | Seeded in plan | Pending |
| 0013 | Repository topology | Seeded in plan | Pending |
| 0014 | Terraform state | Accepted | [`0014-terraform-state.md`](0014-terraform-state.md) |
| 0015 | Internal API auth | Seeded in plan | Pending |
| 0016 | Image promotion | Seeded in plan | Pending |
| 0017 | DR posture | Seeded in plan | Pending |
| 0018 | Developer inner loop | Seeded in plan | Pending |
| 0019 | CI scanning | Seeded in plan | Pending |
| 0020 | Backstage build-vs-buy | Seeded in plan | Pending |
| 0021 | Pre-commit framework and local quality gates | Accepted | [`0021-pre-commit.md`](0021-pre-commit.md) |
| 0022 | Conventional Commits and Release Please | Seeded in Stage 06 | Pending |
| 0023 | SCM branching and GitHub Environments | Accepted | [`0023-scm-branching.md`](0023-scm-branching.md) |
| 0024 | Break-glass procedure | Accepted | [`0024-break-glass.md`](0024-break-glass.md) |
| 0025 | OIDC federation policy | Accepted | [`0025-oidc-federation.md`](0025-oidc-federation.md) |
| 0026 | AVM module pinning and subscription-baseline composition | Accepted | [`0026-avm-modules.md`](0026-avm-modules.md) |
| 0027 | Policy exception workflow and approver matrix | Accepted | [`0027-policy-exception.md`](0027-policy-exception.md) |
| 0028 | Subscription topology and ALZ ownership boundary | Accepted | [`0028-subscription-topology.md`](0028-subscription-topology.md) |
| 0029 | Custom RBAC roles and group-only assignments | Accepted | [`0029-custom-roles.md`](0029-custom-roles.md) |
| 0030 | Hub-and-spoke networking for MVP | Accepted | [`0030-hub-and-spoke.md`](0030-hub-and-spoke.md) |
| 0031 | Default-deny egress and FQDN allowlist | Accepted | [`0031-default-deny-egress.md`](0031-default-deny-egress.md) |
| 0032 | Platform eventing bus | Seeded in Stage 04 | Pending |
| 0033 | AKS namespace as workload-scope vending unit | Seeded in Stage 05 | Pending |
| 0034 | Vending request schema | Seeded in Stage 05 | Pending |
| 0035 | Dependency updater strategy | Seeded in Stage 06 | Pending |
| 0036 | Kyverno as single in-cluster policy engine | Seeded in Stage 07 | Pending |
| 0037 | OTel resource attributes and log fields | Seeded in Stage 08 | Pending |
| 0038 | SLO tooling | Seeded in Stage 08 | Pending |
| 0039 | On-call tooling | Seeded in Stage 08 | Pending |
| 0040 | Status page tooling | Seeded in Stage 08 | Pending |
| 0041 | Backstage RBAC | Seeded in Stage 09 | Pending |
| 0042 | TechDocs storage | Seeded in Stage 09 | Pending |
| 0043 | Ownership matrix | Seeded in Stage 10 | Pending |
| 0044 | Template versioning | Seeded in Stage 11 | Pending |
| 0045 | Game-day cadence and scope | Seeded in Stage 12 | Pending |
| 0046 | Post-mortem retention and PII handling | Seeded in Stage 12 | Pending |
| 0047 | Policy testing split | Accepted | [`0047-policy-testing-split.md`](0047-policy-testing-split.md) |
| 0048 | Runner connectivity model | Accepted | [`0048-runner-connectivity.md`](0048-runner-connectivity.md) |
| 0049 | DDoS protection posture | Accepted | [`0049-ddos-protection.md`](0049-ddos-protection.md) |
| 0050 | ACA managed environment substrate | Seeded in Stage 04 | Pending |
| 0051 | Cross-repo GitHub writes | Seeded in Stage 05 | Pending |
| 0052 | Backstage Postgres passwordless auth | Seeded in Stage 09 | Pending |
| 0053 | ACA GitOps exception | Seeded in Stage 11 | Pending |

ADR seeds 0002-0020 are defined in [`plan/plan.md` section 9](../../plan/plan.md#9-key-architecture-decisions-adr-seeds).
Later seeds are introduced by the stage files under [`plan/stages/`](../../plan/stages/).
Promote seeded ADRs to full ADR files as their owning stages are implemented.
