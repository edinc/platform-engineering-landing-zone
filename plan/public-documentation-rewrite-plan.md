# Plan: Public documentation rewrite

Status: proposed
Owner: platform engineering
Audience: maintainers preparing this repository to be public

## Goal

Turn the repository's documentation from an internal, stage-sequenced build log
into a clean, public-facing product. A first-time reader should be able to
understand **what the platform is**, **why it is built this way**, and **how to
stand it up** — without ever needing to know the internal delivery schedule.

Two hard requirements from the request:

1. The main `README.md` is clean and leads with concrete setup steps.
2. Every "stage number" reference (e.g. "Stage 04", "stage-07", "Stage 08
   baseline") is removed from public-facing material and replaced with a durable,
   capability-based vocabulary.

A third, equally important outcome: add real "how everything works" documentation
so the architecture and the main workflows are explained, not just listed.

## Current state (audit findings)

| Area | Finding |
| --- | --- |
| `README.md` | **Wrong content.** 14 lines describing an "AKS workload namespace request" (a leftover PR/template body), not the project. Must be fully rewritten. |
| Stage references | ~459 occurrences of "Stage NN"/"stage-NN" repo-wide: ~213 in `docs/`, ~167 in `infrastructure/` comments, ~75 in `plan/`, ~49 across ADRs, plus `.github/` and templates. |
| `plan/` | `plan/plan.md` + `plan/stages/stage-00…stage-13` encode the internal roadmap. This is the single largest source of stage vocabulary and is inherently internal. |
| `docs/index.md` | Good capability table already, but links readers to `plan/plan.md` and `plan/stages/` and references "stages". |
| `docs/architecture/README.md` | 5-line stub (`# Architecture`). No real architecture content. |
| `docs/adr/` | 50 ADRs, 49 referencing stages (each ADR has a `Stage:` line). |
| `docs/runbooks/` | 21 runbooks + 4 SRE runbooks. Generally solid; some stage references. |
| Public hygiene | **No `LICENSE`, `SECURITY.md`, or `CODE_OF_CONDUCT.md`.** `CONTRIBUTING.md` exists (1.9 KB) but is thin. |
| TechDocs | `mkdocs.yml` (techdocs-core) publishes `docs/` to Backstage TechDocs. Nav: Overview, Architecture, ADRs, Runbooks. |
| Architecture model | `plan/plan.md` already defines a **stage-number-free layered-capability model (L0–L11)** and a component view — the natural replacement vocabulary. |

## Replacement vocabulary (the de-staging key)

Stop ordering docs by *when we built it*; order them by *what it is*. Use the
existing layered-capability model as the canonical map. Reference capabilities and
components, never stage numbers.

| Internal stage (to retire from public docs) | Public capability / component name |
| --- | --- |
| Stage 01 bootstrap / secret zero | Azure foundation (remote state, OIDC identity, seed Key Vault) |
| Stage 02 subscription baseline | Subscription baseline (Defender, diagnostics, budgets, cost exports) |
| Stage 03 connectivity / identity / egress | Connectivity & egress (hub/spoke, Private DNS, firewall allowlist) |
| Stage 04 platform shared services | Platform shared services (AKS, ACR, Key Vault, Postgres, Service Bus) |
| Stage 05 vending | Tenancy vending (subscription & namespace vending) |
| Stage 06 CI/CD & supply chain | Supply chain & CI/CD (reusable workflows, OIDC, cosign, SBOM, scanning) |
| Stage 07 in-cluster GitOps | GitOps platform (Flux, cert-manager, external-dns, ESO/CSI, Kyverno, KEDA) |
| Stage 08 observability / SRE / FinOps | Observability, SRE & FinOps (dashboards, SLOs, cost showback) |
| Stage 09 Backstage MVP | Developer portal (Backstage) |
| Stage 10 multi-tenancy & onboarding | Multi-tenancy & onboarding (team/product onboarding, RBAC, ownership) |
| Stage 11 golden paths | Golden paths (microservice, ACA service, workload namespace) |
| Stage 12 DR & incident | Reliability operations (DR, incident, status, post-mortems) |
| Stage 13 advanced / future | Roadmap & future options |

## Scope

### In scope

- Full rewrite of root `README.md`.
- Removal of stage-number vocabulary from all **public-facing** docs: `docs/`
  (index, architecture, ADRs, runbooks, contracts), `README.md`, `CONTRIBUTING.md`,
  `.github/` templates, and user-facing comments in `infrastructure/` and
  `templates/` where they leak into generated/reader-facing output.
- New "how everything works" documentation set (see workstream 3).
- Public-readiness files: `LICENSE`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, refreshed
  `CONTRIBUTING.md`.
- Restructure of `docs/` and `mkdocs.yml` nav to match the capability model.
- A decision on the fate of `plan/` (see workstream 4).

### Out of scope

- Changing platform behavior, IaC resources, workflow logic, or policies.
- Rewriting ADR *decisions* (only their stage metadata and cross-references change).
- The interactive concepts site — that is a separate plan
  (`plan/interactive-concepts-site-plan.md`).
- Renaming Terraform stack directories on disk (e.g. `_bootstrap`, `platform`):
  keep directory names; only fix reader-facing comments/prose that cite stage
  numbers.

## Workstreams

### 1. Root README rewrite (highest priority)

Replace the entire file. Target structure:

1. **Title + one-paragraph elevator pitch** — an opinionated, secure, compliant
   Internal Developer Platform for Azure, built on CAF / Azure Landing Zones /
   Well-Architected.
2. **Badges** — license, CI, docs (once available).
3. **What you get** — the capability table from `docs/index.md` (deduplicated).
4. **Architecture at a glance** — the component diagram (rendered, e.g. a Mermaid
   version of `plan/plan.md` §4) with a 4–6 bullet summary.
5. **Repository layout** — the de-staged version of `plan/plan.md` §8 (no stage
   annotations).
6. **Getting started / setup** — concrete, ordered steps:
   prerequisites → fork/clone → bootstrap (state, OIDC, seed Key Vault) →
   configure environment profile (`demo`/`nonprod`/`prod`) → deploy subscription
   baseline → connectivity → platform services → GitOps → portal. Each step links
   to the deeper how-it-works doc and the relevant runbook. Emphasize the
   ordering invariants (bootstrap before baseline; connectivity before platform;
   CI/CD before GitOps and Backstage) **as dependencies, not stage numbers**.
7. **Profiles** — `demo` vs `nonprod` vs `prod` and their cost/HA/security posture.
8. **Documentation** — links to the how-it-works set, ADRs, runbooks, and the
   concepts site.
9. **Security & contributing** — link `SECURITY.md`, `CONTRIBUTING.md`, `LICENSE`.

Keep it skimmable; push depth into `docs/`.

### 2. De-stage the public docs

- **ADRs (`docs/adr/`)**: drop or convert the `- Stage: Stage NN - …` metadata
  line. Recommended: replace with `- Capability:` using the table above, or remove
  it entirely. Fix in-body cross-references ("see Stage 07") to capability names.
  Keep ADR numbers and decisions unchanged. Update `docs/adr/README.md` if it
  groups by stage.
- **Runbooks (`docs/runbooks/`)**: replace stage citations with capability/component
  names and direct doc links.
- **Contracts (`docs/contracts/`)**: same treatment.
- **`docs/index.md`**: remove the "stage-by-stage implementation notes live in
  `plan/stages/`" sentence; point to the how-it-works docs and (if retained) an
  internal roadmap section.
- **IaC comments**: rewrite reader-facing comments in `infrastructure/` and
  `templates/` that cite stage numbers to cite the capability/module instead
  (e.g. `← Stage 04: AKS/ACR/KV/PG` becomes `← Platform shared services`). This is
  the largest mechanical change (~167 hits) and can be scripted with review.
- Provide a **single grep gate** the rewrite must pass:
  `grep -rIiE 'stage[ -][0-9]' README.md docs/ templates/ .github/` returns nothing
  (excluding any intentionally-retained internal roadmap under `plan/`).

### 3. New "how everything works" documentation

Create a coherent reference set under `docs/` (exact filenames TBD), at minimum:

- **`docs/architecture/README.md`** — promote from stub to the real reference:
  component view (Mermaid), the ownership-boundary model (ALZ vs Terraform vs Flux
  vs ASO vs Backstage), the three profiles, and the trust/network posture.
- **How-it-works guides** (one page each), explaining the *flow*, not just the
  inventory:
  - Foundation & bootstrap (secret zero, remote state, OIDC).
  - Connectivity & egress (hub/spoke, Private DNS, default-deny FQDN allowlist).
  - Platform services (private AKS with CNI Overlay + Cilium, ACR, Key Vault,
    Postgres) and the secure-by-default AKS patterns.
  - GitOps model (Flux source-of-truth, the separate cluster-state repo, Kyverno
    admission, the `platform-<profile>` source-name contract).
  - Supply chain & CI/CD (reusable workflows, OIDC federation, cosign keyless,
    SBOM, scanning, image promotion).
  - Tenancy vending & onboarding (how a team/namespace/subscription is vended,
    end to end, with the Backstage → PR → workflow → Terraform → Flux loop).
  - Golden paths (the three templates and what each scaffolds: CI, SBOM, signing,
    GitOps, dashboards, SLOs, cost tags, TechDocs, ownership).
  - Observability, SRE & FinOps (dashboards, SLOs, and the cost-showback pipeline:
    Cost Management export → allocator function → showback container → Cost
    Insights).
  - Security & compliance posture (inherited CIS/ALZ policy, Defender, required
    tags, Kyverno as the single admission engine).
- Each guide cross-links to the ADRs that justify its decisions and the runbooks
  that operate it. Diagrams use Mermaid so they render in GitHub and TechDocs.

### 4. Decide the fate of `plan/`

`plan/` is the internal, stage-sequenced source of truth and the densest stage
vocabulary. Options (pick one as part of this plan's execution):

- **A. Archive (recommended).** Move `plan/` to an internal-only location or a
  clearly-labelled `docs/roadmap/` that is framed as historical/roadmap context,
  not setup guidance, and de-stage its public-facing parts. Keep the valuable
  architecture content (component view, capability model) by promoting it into
  `docs/architecture/`.
- **B. Transform.** Convert `plan/stages/` into capability briefs under
  `docs/` (one per capability), dropping the stage framing entirely.
- **C. Remove from the public tree.** Drop `plan/` from the published surface
  (and TechDocs), retaining it only in history.

Whichever is chosen, the public entry points (README, `docs/index.md`) must stop
pointing readers at `plan/stages/`.

### 5. Public-readiness files

- **`LICENSE`** — choose and add (e.g. MIT or Apache-2.0); decide before going
  public. Add the SPDX header/notice expectations to `CONTRIBUTING.md`.
- **`SECURITY.md`** — vulnerability disclosure process and supported scope.
- **`CODE_OF_CONDUCT.md`** — standard (e.g. Contributor Covenant).
- **`CONTRIBUTING.md`** — expand: dev environment, the three required review
  passes (from `AGENTS.md`), validation commands (`terraform fmt/validate`,
  `conftest`, `kyverno test`, Backstage `yarn tsc`/tests), and the
  capability-based vocabulary.
- Ensure no secrets, tenant IDs, subscription IDs, or generated kubeconfigs are
  present anywhere in the published tree (scan before flipping to public).

### 6. Restructure docs nav + build

- Update `mkdocs.yml` nav to: Overview → Architecture → How it works (the new
  guides) → Golden paths → ADRs → Runbooks → Roadmap (if retained).
- Confirm `mkdocs build --strict` passes (no broken links/anchors) and TechDocs
  still renders.

## Technologies / tooling

- Markdown + Mermaid (renders in GitHub and TechDocs).
- Existing MkDocs (`techdocs-core`) for the published docs surface.
- A link checker (e.g. `lychee` or `markdown-link-check`) wired into CI.
- A simple CI grep gate enforcing "no stage-number vocabulary in public docs".

## Acceptance criteria

1. `README.md` describes the project (not a namespace request) and contains an
   ordered, runnable setup path from zero to a working portal.
2. `grep -rIiE 'stage[ -][0-9]' README.md docs/ templates/ .github/` returns no
   matches (and the same for `infrastructure/` reader-facing comments, modulo any
   explicitly-justified exception recorded in this plan).
3. `docs/architecture/README.md` contains a real component diagram and the
   ownership-boundary model (no longer a stub).
4. The how-it-works set exists, with at least one guide per capability in the
   replacement-vocabulary table, each cross-linking ADRs and runbooks.
5. `LICENSE`, `SECURITY.md`, `CODE_OF_CONDUCT.md` exist; `CONTRIBUTING.md` covers
   setup, validation, and review expectations.
6. `mkdocs build --strict` succeeds; the link checker passes in CI.
7. A secret/identifier scan of the published tree is clean.
8. `plan/`'s public exposure is resolved per workstream 4 and no public entry
   point links to `plan/stages/`.

## Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Mechanical de-staging changes meaning or breaks an intentional reference | Review each non-trivial replacement; keep ADR numbers/decisions intact; rely on the grep gate plus human review, not blind sed. |
| Losing valuable roadmap/architecture content when archiving `plan/` | Promote the component view and capability model into `docs/architecture/` before archiving. |
| Setup steps drift from reality | Derive the README setup path from the actual bootstrap scripts and deploy workflows; validate the ordering invariants against the code. |
| Secrets/tenant data exposure on going public | Mandatory pre-publish scan (gitleaks/trufflehog + manual review) as a gate. |
| Scope creep into the concepts site | Keep conceptual/marketing content in the separate Pages plan; this plan stays operational/reference. |

## Suggested execution order

1. README rewrite + public-readiness files (unblocks "looks like a real project").
2. `docs/architecture/README.md` + the how-it-works guides (the substance).
3. De-stage ADRs, runbooks, contracts, and IaC comments (mechanical, gated).
4. Resolve `plan/` (archive/transform) and fix entry-point links.
5. Nav + link-check + secret-scan CI gates; final review.
