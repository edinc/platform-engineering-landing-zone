# Stage 05 — Environment & subscription vending

## Goal

Codify how new subscriptions, workload landing zones, namespaces, and teams are
provisioned — by *infrastructure as code first*, *Backstage scaffolder second*.

## Scope (in)

- Adopt **`Azure/lz-vending`** Terraform module (Microsoft-maintained) as the
  primary subscription/landing-zone vending mechanism.
- Compose `lz-vending` for two archetypes:
  - **Workload subscription (corp/online)** — full subscription with peering,
    RBAC, budget (incl. action group for 80%/100% thresholds), tag baseline,
    diagnostic settings. Requires an **Enrollment Account** (EA) or **MCA
    billing scope** GUID configured in the bootstrap KV — covered in the
    prerequisites runbook.
  - **AKS workload namespace** — single namespace inside the shared platform
    cluster with quotas, RBAC, NetworkPolicy, ServiceAccount + federated
    credential, ACR pull rights, Key Vault read, default labels.
- **`platform-vending-bot` GitHub App** (Stage 05 deliverable) —
  necessary because Stage-05/06/11 workflows write Flux manifests into the
  separate `platform-cluster-state` repo. Cross-repo writes from GitHub
  Actions cannot use OIDC alone (OIDC federation works Azure-side, not
  GH-side). The App is created in this stage; its **private key is stored
  in the seed Key Vault (Stage 01)** and consumed by workflows via the
  `actions/create-github-app-token` pattern.
- **Vending API surface** (foundational for Stage 06+09):
  - A GitHub Action workflow `vend-subscription.yml` that takes an input YAML
    request, runs `lz-vending` Terraform, and opens a PR with the change.
  - A GitHub Action workflow `vend-namespace.yml` that does the same for an
    AKS namespace, using the **GitHub App token** to push a branch + open
    a PR to `platform-cluster-state` (Flux Kustomization). The Terraform
    `github` provider is **not** used for cross-repo writes — a small
    shell/script step using `gh` CLI authenticated as the App is the
    sanctioned mechanism.
  - Both workflows are written as **callers of Stage-06 reusable
    workflows** once Stage 06 lands; this stage ships them as standalone
    workflows and the refactor is tracked in `docs/runbooks/vending.md`.
- **Backstage scaffolder hooks** (UI added in Stage 11) — the Backstage
  template only orchestrates the same workflows: source of truth remains
  Terraform + Flux.
- **Vending request schema** (`docs/contracts/vending-request.yaml`):
  team, product, cost-center, on-call rotation ID, data-classification,
  environment, region(s), tags, budget thresholds, optional add-ons
  (Postgres, Service Bus, etc.). Schema validated by `ajv-cli` in CI.
- **Approval gates**: each vending request opens a PR; CODEOWNERS routes to
  platform + security + finance reviewers.

## Scope (out)

- Backstage scaffolder UI itself (Stage 11).
- Per-tenant Backstage RBAC (Stage 10).
- Data-product vending (Stage 13).

## Deliverables

- `infrastructure/terraform/vending/`
  - `subscription/` — `lz-vending` composition.
  - `aks-namespace/` — Terraform module producing Flux Kustomization manifests
    that the workflow then commits to `platform-cluster-state` via the
    `platform-vending-bot` GitHub App.
- `infrastructure/terraform/github-app/` — Terraform definition of the
  `platform-vending-bot` GitHub App registration, install scope, and the
  Key Vault secret entry for its private key.
- `.github/workflows/vend-subscription.yml`
- `.github/workflows/vend-namespace.yml`
- `docs/contracts/vending-request.yaml` — schema + examples.
- `docs/contracts/vending-request.schema.json` — JSON Schema validated by
  `ajv-cli` in CI.
- `docs/runbooks/vending.md` — operator runbook (incl. EA/MCA prereq, GH
  App rotation, post-Stage-06 refactor checklist).

## Dependencies

- Stage 02 (MG/policy), Stage 03 (hub for peering, Entra groups), Stage 04
  (platform cluster for namespace vending + `platform-cluster-state` repo).
- **Stage 07** is needed for the **reconciliation half** of namespace
  vending (Flux must be installed to reconcile the Kustomization). This
  stage's acceptance is therefore split — see below.

## Decisions / ADRs

- **ADR-0008** Subscription vending = `Azure/lz-vending`.
- **ADR-0033** AKS namespace = workload-scope vending unit; subscriptions used
  only for blast-radius / billing isolation that namespaces cannot provide.
- **ADR-0034** Vending request schema is the platform's first public contract;
  versioned with `apiVersion`.
- **ADR-0051** Cross-repo GitHub writes use a dedicated GitHub App
  (`platform-vending-bot`), not the Terraform `github` provider — to keep
  bot-identity, PAT-free auditing, and short-lived App-token security.

## Technologies

| Concern | Choice |
|---------|--------|
| Subscription vending | `Azure/lz-vending` (Terraform) |
| Workflow orchestration | GitHub Actions |
| Cross-repo manifest writes | `gh` CLI + `actions/create-github-app-token` (`platform-vending-bot`) |
| Schema validation | JSON Schema + `ajv-cli` |
| Schema | YAML (`apiVersion: platform.example.io/v1alpha1`) |

## Acceptance criteria

1. A vending request YAML committed to a PR triggers `vend-subscription.yml`
   that produces a green plan, requires approval, and on merge applies.
2. Namespace vending produces a Flux Kustomization PR under
   `platform-cluster-state/tenants/<team>/<env>/` opened by the
   `platform-vending-bot` App; the PR has the correct labels, reviewers,
   and passes its own CI.
3. **(Cross-stage gate, validated in Stage 07)** Once Flux is installed,
   that Kustomization reconciles within 5 min and the namespace has: RBAC
   binding to the team's Entra group, a ResourceQuota, a default-deny
   NetworkPolicy, an outbound NetworkPolicy referencing the egress
   allowlist, a federated SA for Workload Identity, labels for cost
   allocation.
4. Vending request schema versioning works (a v1alpha1 request rejects when
   v1 fields are required) — `ajv-cli` validates in CI.
5. The `platform-vending-bot` GitHub App's private key is **only** in the
   seed KV; no PATs anywhere; secret rotation runbook exercises a
   successful key rotation.

## Risks

- **`lz-vending` upstream churn** → pin version; track release notes.
- **PR-driven vending feels slow** for developers → mitigate with Backstage
  scaffolder UX (Stage 11) and a target SLA of "PR open → merged < 1 working
  day" for routine requests.
- **Drift between Backstage catalog and vended reality** → reconciliation
  job (Stage 09) compares Backstage entities to vended namespaces.
