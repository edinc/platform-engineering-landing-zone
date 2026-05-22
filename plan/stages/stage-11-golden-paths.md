# Stage 11 — Golden paths v1 (three templates)

## Goal

Deliver three Backstage software templates, each wired with CI/CD, GitOps,
observability, cost tags, TechDocs, SLO, and on-call hooks **out of the box**.

## Scope (in)

### Template 1 — AKS microservice

For stateful or stateless container workloads requiring Kubernetes.

- Inputs: name, language (Node TS / Python / .NET), team, product, data
  classification, public/private exposure.
- Outputs:
  - New GitHub repo from skeleton (`templates/aks-microservice/skeleton/`).
  - `.devcontainer/`, README, TechDocs (`mkdocs.yml` + `docs/`).
  - Language-specific scaffold (REST sample, structured logger config, OTel
    instrumentation).
  - Helm chart in `chart/` with sensible defaults (HPA, PDB, NetworkPolicy,
    ServiceMonitor, PrometheusRule from `slo.yaml`).
  - `slo.yaml` (Sloth).
  - GH Actions wired to Stage-06 reusable workflows: build, sign, SBOM,
    scan, helm-publish, dev image-automation bump.
  - `catalog-info.yaml` (Backstage Component referencing owner, repo,
    K8s annotations, TechDocs).
  - Flux Kustomization manifests committed to `platform-cluster-state` for
    the team's vended namespace.
- Default ingress: cluster-internal Service + optional `Ingress` for public
  exposure via ingress-nginx + Front Door.

### Template 2 — ACA service

For simpler containerised workloads (event-driven, scheduled, lightweight
HTTP) that don't need full Kubernetes. **Substrate**: the ACA managed
environment provisioned in Stage 04 (ADR-0050) — Template 2 deploys ACA
*apps* into the existing environment; it does **not** create environments.

- Inputs: same as Template 1 + scale rules (HTTP, queue, cron).
- Outputs:
  - New GitHub repo.
  - **Terraform** module call for an `azurerm_container_app`
    (`templates/aca-service/skeleton/infra/aca.tf`). Per ADR-0001
    (Terraform-first) and plan.md principle 3, **Bicep is not used** in
    golden-path templates.
  - GH Actions: build, sign, push to ACR, **`az containerapp update`**
    with the new digest. ACA deploys are imperative push (not Flux
    reconciled) — this is the **single documented exception to ADR-0002
    GitOps-everywhere**, recorded in ADR-0053. Rationale: ACA is a
    serverless control plane that does not have an in-cluster Flux
    counterpart; Terraform is the source of truth for the resource, and
    digest updates are a deploy not an infra change.
  - Application Insights wiring via OTel auto-instrumentation.
  - SLO: defined via Application Insights availability / failure / latency
    queries, **not** via Sloth/Prometheus (ACA does not expose
    Prometheus scrape targets the way AKS does); template includes a
    pre-built KQL pack.
  - Kyverno verify does **not** apply to ACA (no admission webhook);
    signature verification is enforced via the `gitops-push.yml` deploy
    workflow which calls `cosign verify` before `az containerapp update`,
    and by an Azure Policy `auditIfNotExists` on ACA apps.
  - Backstage Component (`type: service`, `lifecycle: production`, with ACA
    URL annotation).

### Template 3 — AKS workload namespace

The platform admin / team-lead workflow that *precedes* Templates 1 and 2 if
no namespace exists yet for the team/env. Re-exports the Stage-05 vending
flow with friendlier inputs.

- Inputs: team, product, environment, region, quota tier (S/M/L).
- Outputs:
  - Vending PR against `infrastructure/terraform/vending/aks-namespace/`.
  - Reviewers auto-assigned (platform + security).
  - Backstage `Resource` entity created tracking the vended namespace.

### Cross-cutting requirements every template enforces

- Mandatory tags (`env`, `owner`, `costCenter`, `product`,
  `dataClassification`, `confidentiality`, `managedBy`, `repo`).
- `spec.owner` references the team's Entra group.
- `slo.yaml` present and valid.
- Image is signed before deploy (Kyverno verify in Stage 07).
- Default NetworkPolicy denies all egress except platform-allowlisted FQDNs.
- Devcontainer.
- TechDocs scaffold with at least an architecture page + runbook page.
- On-call rotation reference (PagerDuty service or Teams channel).

## Scope (out)

- Static web app, library, data product, ML, scheduled job templates →
  deferred to v2 (Stage 13 or beyond).
- Custom Backstage plugins.

## Deliverables

- `templates/aks-microservice/`
- `templates/aca-service/`
- `templates/aks-workload-namespace/`
- `templates/_partials/` — shared Backstage template partials:
  `slo.yaml`, `catalog-info.yaml`, `.devcontainer/`, `Renovate config`,
  `mkdocs.yml`, on-call annotation block, `chart/templates/_helpers.tpl`.
  Each top-level template `includes` from here so the maintenance fan-out
  is one (DRY).
- `docs/runbooks/golden-paths.md` — author + consumer guides.
- `docs/adr/0044-template-versioning.md` — `apiVersion` + deprecation policy.
- `docs/adr/0053-aca-gitops-exception.md` — documented exception to ADR-0002:
  ACA apps are CI-push deploys, not Flux-reconciled.

## Dependencies

- Stage 04 (ACA managed environment substrate — ADR-0050), Stage 05
  (vending + `platform-vending-bot` GitHub App), Stage 06 (CI workflows
  incl. `techdocs-publish.yml`, `gitops-push.yml`), Stage 07 (Flux +
  Kyverno + KEDA), Stage 08 (ADR-0038 Sloth resolution — **hard
  dependency**; templates can only be written when the SLO format is
  fixed), Stage 09 (Backstage), Stage 10 (onboarding + ownership rules
  + onboarding smoke test).

## Decisions / ADRs

- **ADR-0044** Template versioning: every template carries
  `apiVersion: scaffolder.platform.example.io/v1` and a `metadata.deprecated`
  field; migration paths documented per major version.
- **ADR-0053** ACA-app deploys are an explicit, documented exception to
  ADR-0002 GitOps-everywhere — imperative CI push, with signature
  re-verification at deploy time and Terraform as the source of truth
  for the app resource definition.

## Technologies

| Concern | Choice |
|---------|--------|
| Template engine | Backstage Scaffolder |
| App scaffolds | Language-idiomatic (Node TS / Python / .NET) |
| K8s packaging | Helm |
| ACA packaging | **Terraform only** (`azurerm_container_app`) |
| Observability wiring | OTel + Sloth (AKS) / App Insights KQL (ACA) + Managed Prom/Grafana + App Insights |
| Docs | TechDocs (mkdocs-material) published via Stage-06 `techdocs-publish.yml` |

## Acceptance criteria

1. AKS-microservice template: a developer running the template produces, in
   < 30 min from "submit" to "**pod running + 200 OK from `/healthz`**" in
   dev:
   - new GitHub repo with CI green,
   - signed image in ACR,
   - Flux-deployed pods in the team's dev namespace,
   - dashboards + SLO + alerts visible,
   - TechDocs published.
1a. Public ingress (when chosen) is reachable via Front Door within
    < 45 min total (separate measurement, since DNS + Front Door route
    propagation are external).
2. ACA template likewise reaches a running ACA endpoint with public route
   within < 20 min.
3. Workload-namespace template produces a merged vending PR + reconciled
   namespace within < 1 working day SLA.
4. Every template's generated repo passes the platform's CI test harness on
   the very first run.
5. Removing a mandatory tag in a generated repo causes CI to fail and Kyverno
   to deny admission (AKS) / Azure Policy to flag (ACA).

## Risks

- **Template drift** — three templates × three languages × Helm + ACA + TF →
  combinatorial maintenance. Mitigation: shared template partials
  (`templates/_partials/`).
- **First-run friction** for developers without local Azure CLI / GH auth →
  Backstage scaffolder runs everything server-side via OIDC.
- **Schema-breaking template changes** → ADR-0044 versioning + Renovate
  auto-PR upgrades for downstream repos.
