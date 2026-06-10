# Platform Engineering Landing Zone — High-Level Plan

> Status: high-level plan, v2. Round 1: high-level plan reviewed by GPT-5.5 +
> Claude Opus 4.7. Round 2: 14 stage files reviewed by GPT-5.5 + Claude Sonnet
> 4.6. Both rounds synthesised and applied. Per-stage detail lives in
> [`stages/`](./stages/).

## 1. Vision

An opinionated, reusable **Platform Engineering Landing Zone** that assumes an
Azure Landing Zone already exists and onboards existing Azure subscriptions into
a production-grade Internal Developer Platform (IDP) end-to-end:

- A compliant, secure subscription baseline aligned with **CAF / Azure Landing
  Zones (ALZ) / Azure Well-Architected**, without owning the tenant-wide ALZ.
- **Backstage** as the developer portal (Stage 09), powered by **golden paths**
  (Stage 11).
- **GitOps-driven** workload delivery on **AKS** via Flux.
- Identity, secrets, observability, cost, DR, and policy treated as first-class
  capabilities — not afterthoughts.
- **Terraform-first** IaC, with Bicep retained as a documented alternative for
  future re-evaluation.

The output is this repository: a curated set of Terraform modules, Flux
manifests, Backstage code, software templates, reusable CI workflows, policy
bundles, and runbooks that bootstrap and operate the platform.

## 2. Guiding principles

1. **Azure-native first.** Prefer first-party Azure services. Use **Azure
   Verified Modules (AVM)** where they exist and are GA.
2. **CAF / ALZ aligned.** Consume an existing management-group and policy
   foundation; this repo owns subscription onboarding, platform shared services,
   hub-and-spoke connectivity integration, central diagnostics wiring, Defender
   baseline, and cost controls.
3. **Everything-as-Code.** Terraform is primary. Bicep is recorded as a future
   option (Stage 13).
4. **GitOps everywhere.** Flux (AKS extension, Microsoft-supported) is the
   single source of truth for in-cluster state.
5. **Self-service via golden paths.** Backstage Software Templates are the
   primary way developers create services, infrastructure, and docs.
6. **Secure by default.** Workload Identity, OIDC federated CI, Private Link,
   default-deny egress, signed images, Kyverno verify, Defender for Cloud,
   Azure Policy alignment with CIS Foundations + existing ALZ initiatives.
7. **Operationally complete.** On-call, incident workflow, runbooks, status
   page, DR drills, platform SLOs are stage gates — not appendices.
8. **Hard ownership boundaries.** The existing ALZ owns management groups and
   tenant/MG-scoped policy; Terraform in this repo owns subscription-scoped
   baseline and platform-shared infra; Flux owns Kubernetes desired state;
   **Azure Service Operator v2** owns
   workload-team Azure dependencies; Backstage *initiates* workflows but is
   never the source of truth.
9. **Three profiles.** `demo`, `nonprod`, `prod` are Terraform variable sets
   controlling SKU/Defender tier/HA so the platform is approachable at low cost
   yet production-capable at full tier.
10. **Brownfield-aware.** Designed to work against existing subscriptions with
    prior policy/network footprints.

## 3. Personas

- **Platform engineers** — operate and evolve the landing zone.
- **Application developers** — consume golden paths through Backstage.
- **Security & compliance** — consume policy reports, audit logs, Defender data.
- **FinOps / leadership** — consume cost insights by team/product/namespace.
- **SRE / on-call** — consume runbooks, dashboards, status page, incident tools.

## 4. Architecture (component view)

```
┌─────────────────────────────── Tenant / Entra ID ──────────────────────────────┐
│                                                                                │
│  Existing Management Group hierarchy (external ALZ)                             │
│  ┌─ alz ─┐                                                                     │
│  │ platform ─ {management, connectivity, identity}                             │
│  │ landingzones ─ {corp, online}                                               │
│  │ sandbox, decommissioned                                                     │
│  └───────┘                                                                     │
│                                                                                │
│  Hub-and-spoke network (Azure Firewall Premium, Private DNS zones)             │
│                                                                                │
│  ┌────────── platform subscription ─────────────────┐                          │
│  │ AKS (private, Azure CNI Overlay + Cilium)        │   ┌── workload LZ ──┐    │
│  │   ├─ Flux (AKS extension)                        │   │ App namespaces  │    │
│  │   ├─ cert-manager, external-dns                  │   │ ASO-managed     │    │
│  │   ├─ Workload Identity + Key Vault CSI / ESO     │←──┤ Azure deps      │    │
│  │   ├─ Managed Prometheus + Managed Grafana        │   └─────────────────┘    │
│  │   ├─ Kyverno (sign verify, label policy)         │                          │
│  │   ├─ ingress-nginx + Front Door (edge)           │                          │
│  │   └─ Backstage (Helm)                            │                          │
│  │ ACR Premium (geo-rep, pull-through cache)        │                          │
│  │ Key Vault (RBAC, Private Link)                   │                          │
│  │ Postgres Flexible (HA, PITR, CMK) ← Backstage DB │                          │
│  └──────────────────────────────────────────────────┘                          │
│                                                                                │
│  GitHub  ── OIDC ──▶ Azure;  reusable workflows; cosign keyless; SBOM; CodeQL  │
│                                                                                │
│  Azure Monitor / Log Analytics / Defender for Cloud / Cost Management          │
└────────────────────────────────────────────────────────────────────────────────┘
```

## 5. Layered capabilities (no longer the stage order — see §6)

- **L0 Tenant & identity** — Entra tenant, PIM, platform groups, break-glass.
- **L1 Subscription baseline** — existing-ALZ readiness, subscription Activity
  Logs, Defender, tag expectations, budgets, cost exports.
- **L2 Connectivity & egress** — Hub VNet, Azure Firewall Premium, Private DNS,
  default-deny FQDN allowlist, Private Link standards, exception workflow.
- **L3 Platform shared services** — AKS, ACR (+ pull-through cache), Key Vault,
  Postgres, ingress, DNS, eventing.
- **L4 In-cluster platform (Flux GitOps)** — cert-manager, external-dns,
  Workload Identity + CSI/ESO, Kyverno, PSA, Managed Prom/Grafana, OTel.
- **L5 Supply chain & CI/CD** — GH Actions reusable workflows, OIDC federation,
  cosign keyless, SBOM, scanning, CodeQL, image-promotion semantics, base-image
  governance.
- **L6 Observability, SRE, FinOps** — OTel, dashboards, SLO toolkit (Sloth),
  alert routing, runbooks, cost allocation, AKS Node Auto-Provisioning (NAP).
- **L7 Developer portal** — Backstage with Entra auth, catalog, TechDocs,
  scaffolder, Kubernetes/Flux/GH Actions plugins.
- **L8 Multi-tenancy & onboarding** — team/product onboarding, namespace
  vending, Backstage RBAC, ownership matrix, cost showback.
- **L9 Golden paths v1** — 3 templates: AKS microservice, ACA service, AKS
  workload namespace.
- **L10 Reliability operations** — DR drills, status page, post-mortem template,
  incident workflow.
- **L11 Advanced / future** — VS Code extension, Bicep optionality, Radius,
  Dapr, AI/ML paths, Fabric, multi-region active-active.

## 6. Implementation stages

| # | Stage | Outcome / exit criteria | Stage file |
|---|-------|-------------------------|------------|
| 00 | Foundation & repo bootstrap | Repo layout, conventions, ADR template, IaC + policy CI test harness, lite contributor guide | [`stage-00-foundation.md`](./stages/stage-00-foundation.md) |
| 01 | Bootstrap & secret zero | TF remote state, GH↔Azure OIDC federation, seed Key Vault, break-glass, DNS delegation; the bootstrap workflow closes the loop via OIDC | [`stage-01-bootstrap-secret-zero.md`](./stages/stage-01-bootstrap-secret-zero.md) |
| 02 | Subscription baseline & compliance alignment | Existing-ALZ subscription onboarding, Activity Log diagnostics to central LA, Defender baseline, tag policy alignment, budgets/cost exports | [`stage-02-subscription-baseline.md`](./stages/stage-02-subscription-baseline.md) |
| 03 | Connectivity, identity, egress | Hub VNet, Firewall Premium, Private DNS, default-deny FQDN allowlist, exception workflow, Entra groups, PIM | [`stage-03-connectivity-identity-egress.md`](./stages/stage-03-connectivity-identity-egress.md) |
| 04 | Platform shared services | AKS (private, Cilium, standard mode), ACR Premium + pull-through cache, Key Vault, Postgres Flexible (HA, PITR, CMK), ingress controller, DR design baked in | [`stage-04-platform-shared-services.md`](./stages/stage-04-platform-shared-services.md) |
| 05 | Environment & subscription vending | Existing ALZ vending integration, optional `Azure/lz-vending` composition, and Backstage scaffolder hooks for subscriptions, namespaces, and teams | [`stage-05-vending.md`](./stages/stage-05-vending.md) |
| 06 | CI/CD & software supply chain | OIDC federated GH Actions, reusable workflows, cosign keyless, SBOM, Defender + Trivy + CodeQL, image-promotion semantics (auto-bump dev / PR-promote test+prod, digest pin, sign re-verify) | [`stage-06-cicd-supply-chain.md`](./stages/stage-06-cicd-supply-chain.md) |
| 07 | GitOps & in-cluster platform | Flux, cert-manager (Let's Encrypt + Key Vault private CA), external-dns, Workload Identity + CSI/ESO, Kyverno verify, Pod Security Admission, OTel/Managed Prom/Grafana | [`stage-07-gitops-incluster.md`](./stages/stage-07-gitops-incluster.md) |
| 08 | Observability, SRE, FinOps | OTel pipeline, seeded dashboards, alert routing, SLO toolkit (Sloth), status page, cost allocation, AKS NAP, idle/rightsizing | [`stage-08-observability-sre-finops.md`](./stages/stage-08-observability-sre-finops.md) |
| 09 | Backstage MVP | Backstage built by *this* repo's supply chain, deployed via Flux, Entra OIDC, GitHub catalog ingestion, K8s + Flux + GH Actions plugins, TechDocs, Backstage RBAC | [`stage-09-backstage-mvp.md`](./stages/stage-09-backstage-mvp.md) |
| 10 | Multi-tenancy, onboarding, ownership | Namespace vending workflow, Backstage RBAC + entitlements, ownership matrix, cost showback by team, dev onboarding loop, inner-loop (devcontainers + Bridge to Kubernetes / Tilt) | [`stage-10-multitenancy-onboarding.md`](./stages/stage-10-multitenancy-onboarding.md) |
| 11 | Golden paths v1 (3 templates) | AKS microservice, ACA service, AKS workload namespace — each wired with CI, SBOM, signing, GitOps, dashboards, SLO, cost tags, TechDocs, on-call hooks | [`stage-11-golden-paths.md`](./stages/stage-11-golden-paths.md) |
| 12 | DR drills & incident workflow | RTO/RPO matrix validated by restore drills (Postgres PITR, AKS Backup, KV recovery), incident response, runbook catalog, status page, post-mortem template | [`stage-12-dr-incident.md`](./stages/stage-12-dr-incident.md) |
| 13 | Advanced / future | VS Code extension, Platform CLI + API contract, Bicep optionality, Radius / Dapr ADRs, AI/ML golden paths, Fabric data product, multi-region, AKS Fleet Manager, Build-vs-buy re-evaluation | [`stage-13-advanced-future.md`](./stages/stage-13-advanced-future.md) |

### Why this order

- **Stage 01 before 02** — nothing can deploy without remote state, OIDC, and a
  break-glass identity.
- **Stage 03 (egress) before 04** — AKS without a defined egress policy
  produces fragile builds and unsafe defaults.
- **Stage 05 (vending) before 06** — vending is the primary platform workflow;
  CI/CD has to *be* vendable.
- **Stage 06 (CI/CD) before 07/09** — Backstage is built and deployed *by* this
  platform's own pipeline. Without Stage 06, Stage 09 has to be hand-rolled and
  then redone.
- **Stage 08 (observability) before 09/11** — templates must wire dashboards,
  SLOs, and cost tags from inception. Retro-fitting observability is the most
  common platform-engineering anti-pattern.
- **Stage 10 (multi-tenancy) before 11** — golden paths instantiate a
  team/namespace abstraction that must already exist.

## 7. MVP definition

The MVP is **Stages 00 → 11** with these explicit cuts:

- **3 golden paths** (not 6): AKS microservice, ACA service, AKS workload
  namespace.
- **No service mesh** at MVP. NetworkPolicies + Workload Identity + ingress
  TLS are sufficient. Istio AKS add-on or Cilium service mesh is an ADR for
  Stage 13.
- **No Argo Workflows** at MVP. Flux + GitHub Actions cover delivery and
  orchestration.
- **No custom Backstage plugins** at MVP beyond Entra auth + catalog rules.
  Community plugins only.
- **No Fabric / data-product template** at MVP.
- **No multi-region active-active.** Single primary region, zone-redundant
  where supported; secondary region as DR target for Postgres + ACR + DNS.
- **`demo` profile** is targetable: ingress-nginx + Front Door, Defender free,
  ACR Standard, single-AZ Postgres, no Firewall Premium (NAT Gateway instead).

### MVP success criteria

1. A platform engineer can run the documented bootstrap and subscription
   onboarding path against an existing ALZ subscription within **one working day
   of pipeline time**.
2. An application developer can use Backstage to create a new microservice
   from a golden-path template and reach a running endpoint in dev within
   **< 30 minutes**, with no Azure portal interaction.
3. All workloads run with **Workload Identity** (no secrets in env vars),
   **signed images** (cosign keyless + Kyverno verify), Kyverno-enforced
   policy, and tagged for cost allocation.
4. Logs, metrics, traces, and cost data flow into the central observability and
   FinOps surfaces by default.
5. **DR drill executed**: Postgres PITR restore, AKS Backup restore, KV
   recovery, ACR failover — all within stated RTO/RPO.
6. **Platform SLOs published** and the platform team reports against them.

## 8. Repository structure

This repo contains **platform code** only. Cluster *state* lives in a separate
Flux-watched repo to limit blast radius.

```
platform-engineering-landing-zone/        ← this repo
├── README.md
├── plan/
│   ├── plan.md                           ← this file
│   └── stages/                           ← per-stage detail
├── docs/
│   ├── adr/                              ← architecture decision records
│   ├── runbooks/                         ← operator runbooks
│   └── architecture/                     ← diagrams + reference
├── infrastructure/
│   ├── terraform/
│   │   ├── _bootstrap/                   ← Stage 01: state, OIDC, seed KV
│   │   ├── _modules/                     ← reusable, AVM-aligned
│   │   ├── subscription-baseline/        ← Stage 02
│   │   ├── connectivity/                 ← Stage 03
│   │   ├── identity/                     ← Stage 03 (Entra-supported parts)
│   │   ├── platform/                     ← Stage 04: AKS/ACR/KV/PG
│   │   ├── vending/                      ← Stage 05: lz-vending compositions
│   │   └── envs/{demo,nonprod,prod}/     ← per-profile composition
│   └── bicep/                            ← (placeholder; Stage 13)
├── platform-gitops/                      ← cluster state lives in separate repo
│   └── README.md                         ← link + bootstrap script
├── backstage/                            ← Backstage app + Helm + plugins
│   ├── app/
│   ├── plugins/
│   └── deploy/
├── templates/                            ← Backstage software templates
│   ├── aks-microservice/skeleton/
│   ├── aca-service/skeleton/
│   └── aks-workload-namespace/skeleton/
├── workflows/                            ← reusable GH Actions
│   ├── terraform-plan-apply.yml
│   ├── container-build-sign.yml
│   ├── helm-publish.yml
│   ├── promote-image.yml
│   └── policy-checks.yml
├── policies/
│   ├── azure/                            ← Azure Policy + initiatives
│   └── kyverno/                          ← in-cluster policies
└── scripts/
    └── bootstrap/                        ← `make bootstrap-init` (secret zero)
```

A separate repository hosts the GitOps source-of-truth:

```
platform-cluster-state/                   ← separate repo, owned by Flux
├── clusters/
│   ├── _base/                            ← shared bases
│   └── overlays/
│       ├── demo/
│       ├── nonprod/
│       └── prod/
└── tenants/                              ← per-team workload manifests (vended)
```

## 9. Key architecture decisions (ADR seeds)

Each item below becomes a `docs/adr/NNNN-*.md`. Defaults are listed; the ADR
captures alternatives and trade-offs.

| ADR | Decision | Default | Alternatives considered |
|-----|----------|---------|------------------------|
| 0001 | Primary IaC | Terraform | Bicep (Stage 13), Pulumi |
| 0002 | GitOps engine | Flux (AKS extension) | Argo CD |
| 0003 | Cluster ingress | ingress-nginx (cluster) + Azure Front Door Premium (edge) | AGC (re-evaluate 6–12 mo), AGIC, Envoy Gateway |
| 0004 | Service mesh | **None at MVP** | Istio AKS add-on, Cilium service mesh, Linkerd |
| 0005 | Azure-resource provisioning from cluster | ASO v2 | Crossplane (re-evaluate if multi-cloud emerges) |
| 0006 | Secrets in cluster | Key Vault + Secrets Store CSI Driver (default); ESO when K8s Secret objects required | Sealed Secrets |
| 0007 | Image signing | Cosign keyless via GH OIDC + Kyverno verify | Notation / Notary v2 (re-evaluate if ACR pushes Notation alignment) |
| 0008 | Subscription vending | Existing ALZ vending integration; `Azure/lz-vending` when repo-owned | Bicep ALZ vending, ServiceNow flow |
| 0009 | AKS dataplane | Azure CNI Overlay + Cilium | Azure CNI Powered-by-Cilium |
| 0010 | AKS node auto-provisioning | **AKS Node Auto-Provisioning (NAP)** — Microsoft-managed, built on Karpenter | Cluster autoscaler only; self-managed Karpenter |
| 0011 | Compliance baseline | Existing ALZ/CIS baseline + subscription-scoped hardening | ISO 27001 / SOC 2 mapping deferred but informed |
| 0012 | Backstage hosting | In-cluster on AKS via Helm, deployed by Flux | Azure Container Apps |
| 0013 | Repository topology | Platform repo (this) + separate `platform-cluster-state` repo | Monorepo |
| 0014 | Terraform state | AzureRM backend, per-stage state files, AZ blob lease lock, CMK | Terragrunt (only if team is fluent) |
| 0015 | Internal API auth | At MVP: ingress TLS + Workload Identity + NetworkPolicy; APIM for external/north-south APIs | Istio AuthorizationPolicy + SPIFFE/SPIRE (Stage 13 ADR) |
| 0016 | Image promotion | Auto-bump in dev (image-automation), **PR-based promotion** to nonprod/prod, digest pinning, signature re-verify on promote | Tag-based promotion |
| 0017 | DR posture | Active-passive across two paired regions; documented RTO/RPO per tier | Active-active (Stage 13) |
| 0018 | Developer inner loop | Devcontainers + Bridge to Kubernetes (or Tilt) | Skaffold, mirrord |
| 0019 | CI scanning | Defender for Containers + Trivy + CodeQL + cosign verify | Snyk, Aqua |
| 0020 | Backstage build-vs-buy | Build (Backstage) for Stage 1; **Stage 13 re-evaluation** vs Port / Humanitec / Cortex with TCO model | — |

> ADRs **0021–0046** are introduced by individual stage files. A canonical
> index is maintained in [`../docs/adr/README.md`](../docs/adr/README.md);
> stage files reference ADRs by number.

## 10. Tagging taxonomy (enforced via Azure Policy)

Mandatory tags on every Azure resource:

| Tag | Example | Purpose |
|-----|---------|---------|
| `env` | `prod`, `nonprod`, `demo` | Environment isolation |
| `owner` | `team-payments` | Ownership / on-call |
| `costCenter` | `cc-12345` | FinOps chargeback |
| `product` | `checkout` | Product cataloguing |
| `dataClassification` | `public`, `internal`, `confidential`, `restricted` | Compliance |
| `confidentiality` | `low`, `medium`, `high` | Risk posture |
| `managedBy` | `terraform`, `flux`, `aso`, `manual` | Ownership boundary |
| `repo` | `org/repo` | Source of truth link |

## 11. Operational model (Stage 12 baseline)

- **Platform SLOs** (initial): Backstage availability ≥ 99.5%; GitOps
  reconciliation p95 < 5 min; cluster API availability ≥ 99.9%; golden-path
  success rate ≥ 95%; time-to-restore (Postgres PITR) ≤ 60 min.
- **On-call**: weekly platform rotation; PagerDuty (or Teams + Azure Monitor
  Action Groups for `demo`).
- **Incident workflow**: incident channel template, severity matrix, IC handoff
  template, post-mortem template.
- **Runbook catalog** in `docs/runbooks/`, surfaced via Backstage TechDocs.
- **Status page** for the platform itself.
- **Game-days** quarterly: restore drills + chaos exercises (Azure Chaos
  Studio).

## 12. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Scope sprawl | Stage gates with explicit MVP cut list (§7); ADR triggers for deferred items |
| Existing ALZ integration drift | Readiness discovery, explicit external prerequisites, and periodic subscription-baseline validation |
| Backstage maintenance burden | Stay close to upstream; minimise core forks; isolate custom code to plugins; Stage 13 build-vs-buy re-evaluation |
| Identity complexity (Entra + WI + RBAC) | ADRs early; test harness with `kubelogin` + `az login` flows |
| Cost (Defender, Firewall Premium, Managed Grafana, Premium ACR) | `demo` profile uses Free/Standard tiers; per-profile SKU matrix |
| Skills gap | TechDocs + golden-path provides the paved road; "platform CLI" wraps complexity |
| ASO / Crossplane drift with Terraform | Hard ownership boundary in ADR 0005 + `managedBy` tag enforcement |
| AGC immaturity | Default to nginx + Front Door; AGC re-evaluation ADR |

## 13. Open questions (now scoped, with required-by-stage)

| # | Question | Required by |
|---|----------|------------|
| 1 | Which existing ALZ/subscription is the first onboarding target? | Stage 01 |
| 2 | Single Backstage tenant or per-BU? | Stage 09 |
| 3 | Cluster topology: regional AKS per env vs Fleet Manager? | Stage 04 |
| 4 | RPO/RTO per tier (Backstage, Postgres, ACR, KV, GitOps state, AKS) | Stage 04 |
| 5 | Public + private DNS zone ownership & delegation model | Stage 03 |
| 6 | Compliance regimes beyond the inherited ALZ/CIS baseline | Stage 02 |
| 7 | Primary + secondary regions (data residency) | Stage 03 / 04 |
| 8 | GitHub Cloud vs GHEC; ADO coexistence | Stage 00 |
| 9 | Platform API contract (for VS Code/CLI) — design now or later? | Stage 06 |
| 10 | Eventing bus: Service Bus or Event Grid (one as platform-internal) | Stage 04 |
| 11 | AVM module maturity audit — which we depend on, which we wrap | Stage 02 |
| 12 | Policy exception workflow + approver | Stage 02 |
| 13 | Working-hours vs 24×7 platform support model | Stage 12 |
| 14 | Cost/SLA for the platform itself | Stage 12 |
| 15 | Inner-loop tool (devcontainers + Bridge or Tilt) | Stage 10 |
| 16 | Sentinel trigger criteria (when to enable) | Stage 02 / 12 |

## 14. Alternatives considered (parked appendix)

These are documented to avoid silent rejection. Each will be re-evaluated by
trigger; none is part of the MVP.

- **Bicep dual-language** — re-evaluate when a concrete consumer requests Bicep
  authoring (Stage 13 ADR).
- **Radius (radapp.io)** — application abstraction layered on Bicep/Terraform;
  strong fit alongside Backstage. ADR after golden paths v1 land.
- **Dapr** — distributed primitives (state, pub/sub, secrets, bindings).
  Evaluate if eventing/state abstraction demand emerges.
- **Crossplane** — re-evaluate if multi-cloud or composite platform-API
  (XR/XRD) becomes a goal.
- **Pulumi** — alternative IaC. Rejected for MVP to avoid IaC fragmentation.
- **Argo CD** — alternative GitOps engine. Documented; not implemented.
- **AGC (Application Gateway for Containers)** — re-evaluate in 6–12 months.
- **Istio AKS add-on** / **Cilium service mesh** — ADR after multi-tenancy
  stage validates real demand.
- **Port / Humanitec / Cortex / OpsLevel** — SaaS IDP alternatives to
  Backstage; Stage 13 build-vs-buy ADR with TCO comparison.
- **Headlamp** — lightweight K8s UI; possible operator-side companion.
- **Azure Container Apps as default** for new services (vs AKS-default).
  Currently ACA is an equal-rank golden path; revisit ranking when usage data
  arrives.
- **AKS Fleet Manager** — multi-region/multi-cluster orchestration; revisit
  when multi-region active-active is on the roadmap.
- **AKS Automatic mode** — revisit when feature parity meets standard mode.
- **Microsoft Sentinel** — explicit trigger: compliance scope expansion.
- **Notation / Notary v2** — re-evaluate if ACR ecosystem standardises on it.

## 15. Process note — how this plan was produced

1. Drafted from scratch as a high-level plan covering vision, principles,
   architecture, stages, repo structure, risks, success criteria.
2. **Round 1** — two independent peer reviewers (GPT-5.5 and Claude Opus 4.7)
   cross-checked the high-level draft. Their convergent feedback was
   synthesised and applied.
3. **Round 2** — all 14 stage files independently reviewed by GPT-5.5 and
   Claude Sonnet 4.6. Both reviews identified the same structural and Azure-
   technical issues (private-cluster auth-IP no-op, Gatekeeper/Kyverno
   contradiction, missing `platform-cluster-state` bootstrap, ACA substrate
   gap, cross-repo GitHub App, Sloth/OpenSLO unresolved, several Azure-
   service mischaracterisations). Findings were applied to the stage files
   and this plan. Both reviews + synthesis trace are retained in the session
   artefact store, not in the repository.
4. Per-stage detail lives in [`stages/`](./stages/). Each stage file follows a
   uniform template: goals → deliverables → dependencies → decisions →
   technologies → acceptance criteria → risks.
