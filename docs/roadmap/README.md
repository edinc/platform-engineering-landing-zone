# Roadmap

This roadmap describes the capabilities the platform delivers today and the
options on the horizon. It is organized by **capability and dependency**, not by
an internal delivery schedule. Detailed delivery history is preserved in version
control.

- For how each capability works, see the [how-it-works guides](../how-it-works/README.md).
- For how they fit together, see the [architecture reference](../architecture/README.md).
- For the trade-offs behind each choice, see the [ADRs](../adr/README.md).

## Capability map

| Capability | Outcome |
| --- | --- |
| [Azure foundation](../how-it-works/foundation.md) | Remote Terraform state, GitHub-to-Azure OIDC federation, seed Key Vault, break-glass, DNS delegation captured. |
| [Subscription baseline](../how-it-works/foundation.md) | Existing-ALZ subscription onboarding, Activity Log diagnostics to central Log Analytics, Defender baseline, tag-policy alignment, budgets and cost exports. |
| [Connectivity & egress](../how-it-works/connectivity-egress.md) | Hub VNet, Azure Firewall Premium, Private DNS, default-deny FQDN allowlist, exception workflow, Entra groups, PIM. |
| [Platform shared services](../how-it-works/platform-services.md) | Private AKS (Cilium), ACR Premium + pull-through cache, Key Vault, Postgres Flexible (HA, PITR, CMK), ingress, DR baked in. |
| [Tenancy vending](../how-it-works/tenancy-vending-onboarding.md) | Existing-ALZ vending integration, optional `Azure/lz-vending` composition, and Backstage scaffolder hooks for subscriptions, namespaces, and teams. |
| [Supply chain & CI/CD](../how-it-works/supply-chain-cicd.md) | OIDC-federated reusable workflows, cosign keyless, SBOMs, Defender + Trivy + CodeQL, and PR-based image promotion with digest pinning and signature re-verify. |
| [GitOps platform](../how-it-works/gitops.md) | Flux, cert-manager, external-dns, Workload Identity + CSI/ESO, Kyverno verify, Pod Security Admission, and Managed Prometheus/Grafana. |
| [Observability, SRE & FinOps](../how-it-works/observability-sre-finops.md) | OpenTelemetry pipeline, seeded dashboards, alert routing, SLO toolkit, status page, cost allocation, and node auto-provisioning. |
| [Developer portal](../how-it-works/developer-portal.md) | Backstage built by this repo's own supply chain, deployed via Flux, with Entra OIDC, catalog ingestion, plugins, TechDocs, and RBAC. |
| [Multi-tenancy & onboarding](../how-it-works/tenancy-vending-onboarding.md) | Namespace vending workflow, Backstage RBAC and entitlements, ownership matrix, cost showback by team, and the developer inner loop. |
| [Golden paths](../how-it-works/golden-paths.md) | AKS microservice, ACA service, and AKS workload namespace — each wired with CI, SBOMs, signing, GitOps, dashboards, SLOs, cost tags, TechDocs, and on-call hooks. |
| [Reliability operations](../how-it-works/reliability-operations.md) | RTO/RPO matrix validated by restore drills, incident response, runbook catalog, status page, and post-mortems. |

## Dependency order

The capabilities build on each other. These are hard dependencies:

- **Foundation before baseline** — nothing deploys without remote state, OIDC,
  and a break-glass identity.
- **Connectivity & egress before platform services** — AKS without a defined
  egress policy produces fragile builds and unsafe defaults.
- **Tenancy vending before supply chain** — vending is the primary platform
  workflow, so CI/CD has to *be* vendable.
- **Supply chain & CI/CD before GitOps and the portal** — Backstage and the
  in-cluster platform are built and deployed *by* this platform's own pipeline.
- **Observability before the portal and golden paths** — templates must wire
  dashboards, SLOs, and cost tags from inception; retro-fitting observability is
  the most common platform-engineering anti-pattern.
- **Multi-tenancy before golden paths** — golden paths instantiate a
  team/namespace abstraction that must already exist.

## MVP scope

The MVP spans the **Azure foundation through golden paths**, with these explicit
cuts to keep it tractable:

- **Three golden paths** (not six): AKS microservice, ACA service, AKS workload
  namespace.
- **No service mesh** at MVP. NetworkPolicies + Workload Identity + ingress TLS
  are sufficient; a mesh is a future option.
- **No Argo Workflows** at MVP. Flux + GitHub Actions cover delivery and
  orchestration.
- **No custom Backstage plugins** at MVP beyond Entra auth + catalog rules.
  Community plugins only.
- **No Fabric / data-product template** at MVP.
- **No multi-region active-active.** Single primary region, zone-redundant where
  supported; a secondary region is the DR target for Postgres, ACR, and DNS.
- **`demo` profile is targetable** with cost-optimized SKUs (NAT Gateway instead
  of Firewall Premium, Defender free, ACR Standard, single-AZ Postgres).

### MVP success criteria

1. A platform engineer can run the documented bootstrap and subscription
   onboarding path against an existing ALZ subscription within one working day of
   pipeline time.
2. An application developer can use Backstage to create a microservice from a
   golden-path template and reach a running endpoint in dev within ~30 minutes,
   with no Azure portal interaction.
3. All workloads run with Workload Identity (no secrets in env vars), signed
   images (cosign keyless + Kyverno verify), Kyverno-enforced policy, and cost
   tags.
4. Logs, metrics, traces, and cost data flow into the central observability and
   FinOps surfaces by default.
5. A DR drill is executed: Postgres PITR restore, AKS Backup restore, Key Vault
   recovery, and ACR failover, all within stated RTO/RPO.
6. Platform SLOs are published and the platform team reports against them.

## Future options

These are documented to avoid silent rejection. Each is re-evaluated by trigger;
none is part of the MVP. Many are captured as ADRs.

- **Bicep dual-language** — re-evaluate when a concrete consumer requests Bicep
  authoring.
- **Radius / Dapr** — application abstraction and distributed primitives;
  evaluate after golden paths land.
- **Crossplane** — re-evaluate if multi-cloud or a composite platform API becomes
  a goal.
- **Service mesh** (Istio AKS add-on / Cilium service mesh) — ADR after the
  multi-tenancy capability validates real demand.
- **Application Gateway for Containers** — re-evaluate against ingress-nginx +
  Front Door in 6-12 months.
- **SaaS IDP alternatives** (Port / Humanitec / Cortex) — a build-vs-buy
  re-evaluation with a TCO model.
- **AKS Fleet Manager / multi-region active-active** — revisit when multi-region
  is on the roadmap.
- **Microsoft Sentinel** — explicit trigger: compliance scope expansion.
- **Platform CLI + API contract** and a **VS Code extension** for the inner loop.

See the [architecture decision records](../adr/README.md) for the related ADRs
and their triggers.
