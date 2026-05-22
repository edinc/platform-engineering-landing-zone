# Stage 13 — Advanced / future

> This stage is a *deliberate backlog*, not a deliverable. Each item has an
> explicit **trigger** that promotes it into a stage with its own plan.

## Goal

Capture deferred capabilities so they are visible, sequenced, and not silently
dropped — while keeping the MVP focused.

## Items & triggers

### A — Platform API & CLI (`pectl`)

- **Why**: A typed platform API is a prerequisite for a VS Code extension and
  for programmatic consumers (CI, third-party tools).
- **What**: OpenAPI 3 spec for vending, onboarding, scaffolder, catalog
  queries, observability queries. A Go-based `pectl` CLI wraps it; thin
  layer over Backstage backend + GH API + ASO.
- **Trigger**: ≥ 3 distinct consumer requests for non-Backstage access, OR
  before Item B begins.

### B — Visual Studio Code extension

- **Why**: Improve developer inner-loop; reduce context switching.
- **What**: Wraps `pectl`; shows catalog entity for the open repo,
  scaffolder shortcuts, K8s status, port-forwarding, log tail.
- **Trigger**: Item A delivered + DevEx survey demand.

### C — Bicep authoring path (dual-language IaC)

- **Why**: User requirement to "leave the option open".
- **What**: Bicep equivalents for a curated subset of modules (network,
  Key Vault, ACR) plus a generation/diff harness to keep parity.
- **Trigger**: A real internal consumer / team requests Bicep authoring with
  a concrete use case.

### D — Service mesh

- **Why**: Workload-driven east-west authN/Z, mTLS, traffic splitting that
  cannot be met by NetworkPolicy + WI alone.
- **What**: ADR comparing Istio AKS add-on, Cilium service mesh, and
  Linkerd. Pilot in `nonprod`, mesh-per-namespace opt-in.
- **Trigger**: First workload with documented mesh-requiring requirement.

### E — Radius application model

- **Why**: Higher-level app abstraction may simplify golden paths.
- **What**: Prototype golden path using Radius; compare maintenance,
  developer ergonomics, drift, debugability vs Helm + ASO.
- **Trigger**: Helm + ASO friction becomes a recurring developer complaint
  in onboarding survey.

### F — Dapr building blocks

- **Why**: Standardised pub/sub, state, secrets, bindings across workloads.
- **What**: Optional Dapr sidecar (or shared Dapr runtime where supported)
  installed via Flux; one golden path adopts it; compare to direct SDK use.
- **Trigger**: ≥ 2 services need shared eventing/state abstraction and
  current SDKs introduce coupling.

### G — Multi-region active-active (paired with Item M)

- **Why**: HA beyond DR active-passive for tier-0 workloads.
- **What**: AKS Fleet Manager (Item M) is a prerequisite. Dual-region
  Front Door config, Postgres **read replicas** (note: read replicas do
  **not** provide HA writes; cross-region writes need either application-
  level partitioning or a different DB topology — captured in the ADR
  produced by this item), traffic shaping.
- **Trigger**: Tier-0 workload arrives with HA requirement beyond Stage-12 DR.

### H — AI / ML golden paths

- **Why**: Likely demand from data/ML teams.
- **What**: Azure Machine Learning workspace, AKS GPU pools, model
  registry, ML pipeline template, prompt-flow / AI Foundry integration.
- **Trigger**: First ML team onboarding request.

### I — Fabric / data product golden path

- **Why**: Data domain has different governance/lineage/cost models.
- **What**: ADLS Gen2 + Microsoft Fabric workspace + data contract scaffold +
  lineage hooks.
- **Trigger**: Data platform sponsor + minimal-viable governance contract in
  place.

### J — Argo Workflows (or alternative)

- **Why**: Async in-cluster workflows beyond what GH Actions covers.
  **Argo Workflows is a workflow engine, not a CD engine** — distinct from
  Argo CD (which the platform already rejects in ADR-0002).
- **What**: Argo Workflows / Argo Events installed; one platform workflow
  (e.g., scheduled cost report) ported.
- **Trigger**: Real need for cluster-scoped, GH-Actions-unfriendly workflows.

### K — Microsoft Sentinel

- **Why**: SIEM/SOAR for security-incident response.
- **What**: Sentinel workspace, ALZ-aligned data connectors, baseline
  analytics rules, playbooks.
- **Trigger**: Compliance scope expansion (e.g., SOC 2, PCI), OR security
  team capacity to operate it.

### L — Custom Backstage "Platform Console" plugin

- **Why**: Single-pane view of GitOps, policy, drift, on-call, vending
  queue, scorecard.
- **What**: Custom Backstage plugin combining Flux, Kyverno reports,
  PagerDuty status, Cost showback.
- **Trigger**: Demonstrated repeated UX friction with stitched community
  plugins.

### M — AKS Fleet Manager

- **Why**: Operate many AKS clusters consistently.
- **What**: Adopt Fleet Manager, port `clusters/_base/` to Fleet
  ClusterResourcePlacement.
- **Trigger**: > 5 AKS clusters under management.

### N — AKS Automatic mode adoption

- **Why**: Reduce operational burden for non-prod / per-team clusters.
- **What**: Re-evaluate Automatic mode feature parity against standard
  baseline; pilot in `demo`.
- **Trigger**: AKS Automatic reaches feature parity for: WI, private
  cluster, Cilium dataplane, Defender profile, planned maintenance.

### O — Build-vs-buy re-evaluation: SaaS IDP

- **Why**: Backstage TCO may exceed Port / Humanitec / Cortex / OpsLevel
  after 12–18 months.
- **What**: TCO model + functional gap analysis; produce ADR with
  recommendation (stay / hybrid / migrate).
- **Trigger**: 12 months after Stage 09 GA, OR sustained Backstage
  maintenance > 0.5 FTE.

### P — Notation / Notary v2 alongside cosign

- **Why**: ACR ecosystem may align on Notation.
- **What**: Evaluate Notation support, dual-signing pilot, migration ADR.
- **Trigger**: ACR pushes Notation-required features OR a downstream tool
  mandates Notation.

### Q — APIM-fronted external API surface

- **Why**: External / partner API surface needs developer-portal-style
  features (subscription keys, throttling, versioning). (APIM is
  north-south, not an east-west service mesh — see Item D for mesh.)
- **What**: APIM Premium with self-hosted gateway pattern; APIM golden path
  template.
- **Trigger**: First external-API workload onboards.

## Deliverables (in this stage's life-cycle, not at MVP)

Per-item ADR + a `plan/stages/stage-13-<item>.md` written *when triggered*,
NOT now. This file is the index.

## Decisions / ADRs

- Each item carries a trigger; each trigger event opens an ADR PR. No
  pre-emptive ADRs at MVP.

## Acceptance criteria

This stage has no "done" — it is the parking lot. Reviewed quarterly by the
platform team; items move into real stages as triggers fire.
