# Plan: Interactive platform-engineering concepts site (GitHub Pages)

Status: proposed
Owner: platform engineering / developer relations
Audience: maintainers building a public educational microsite

## Goal

Build and publish a **dedicated, interactive website** that teaches the concepts
of platform engineering and shows **how this project embodies them**. It is a
conceptual and educational experience — the "why platform engineering, and what a
good Internal Developer Platform looks like" story — distinct from the repository's
operational reference docs (TechDocs).

The site is deployed with **GitHub Pages**, is interactive (not a wall of text),
and converts a curious visitor (engineer, architect, or leader) into someone who
understands the ideas and knows where to go next (the repo, the docs, the golden
paths).

## Why a separate site (relationship to the docs rewrite)

There are two audiences with two jobs:

| Surface | Audience | Job | Tone |
| --- | --- | --- | --- |
| Repo docs / TechDocs (see `plan/public-documentation-rewrite-plan.md`) | Operators, contributors | Stand it up, run it, change it | Reference, precise |
| **This Pages site** | Evaluators, learners, leaders | Understand the concepts and how this project applies them | Narrative, visual, interactive |

The site **links into** the docs/repo for depth; it does **not** duplicate runbooks
or setup steps. Single source of truth stays in `docs/`; the site is the
conceptual front door.

## Scope

### In scope

- A standalone static site (own directory in this repo, e.g. `site/` or `web/`).
- Conceptual content on platform engineering + an interactive tour of this
  project's architecture and golden paths.
- Interactive components (architecture explorer, golden-path walkthrough, cost
  showback illustration, capability/persona filters).
- GitHub Pages deployment via GitHub Actions.
- Design system, responsive layout, accessibility, performance budgets, SEO/social
  cards.

### Out of scope

- Operational runbooks, exhaustive API/IaC reference (those live in TechDocs).
- A live, connected demo against real Azure (use recorded/illustrative data; the
  demo environment is ephemeral and was torn down).
- Backend services — the site is fully static.

## Audience & messaging

- **Application developers** — "self-service golden paths remove the Azure/K8s
  toil; here's the paved road."
- **Platform engineers / architects** — "here's an opinionated, secure reference
  IDP and the decisions behind it."
- **Engineering leaders / FinOps** — "faster delivery, guardrails by default, and
  cost visibility by team/product."
- **The platform-curious** — "what *is* platform engineering and an IDP?"

Core narrative arc: **Problem (cognitive load, snowflake infra, slow & unsafe
delivery) → Idea (platform engineering + IDP + golden paths) → This project
(how each concept is realized, securely, on Azure) → Try it (repo, docs, golden
paths).**

## Information architecture (proposed pages/sections)

1. **Home / hero** — one-line thesis, animated architecture teaser, primary CTAs
   (Explore the architecture · Read the docs · View on GitHub).
2. **What is platform engineering?** — concepts explained simply: Internal
   Developer Platform, golden paths / paved roads, self-service, cognitive-load
   reduction, "you build it, you run it" with guardrails, Team Topologies framing
   (platform team as an enabling/platform team).
3. **Core concepts, applied** — one interactive card/section per concept, each
   pairing the *idea* with *how this project does it* and a link to the proof:
   - Golden paths → the three templates.
   - GitOps → Flux + separate cluster-state repo.
   - Policy as code → Kyverno (in-cluster) + Azure Policy (control plane) +
     OPA/conftest (plan-time).
   - Secure by default → private AKS, Workload Identity, default-deny egress,
     signed images, Private Link.
   - Supply chain security → OIDC, cosign keyless, SBOM, scanning.
   - Self-service & vending → namespace/subscription vending via Backstage.
   - Separation of concerns / ownership → ALZ vs Terraform vs Flux vs ASO vs
     Backstage.
   - FinOps / showback → cost allocation by team/product.
4. **Architecture explorer** — the flagship interactive: the layered/component
   diagram where clicking a layer or component reveals what it is, why it's there,
   and the ADR/doc behind it.
5. **Golden path walkthrough** — an animated, step-through of a request's life:
   developer fills a Backstage form → PR → reusable workflow → Terraform apply →
   Azure identity + RBAC → cluster-state PR → Flux reconcile → running, governed
   namespace. Each step expandable with the real artifacts it produces.
6. **Cost & FinOps** — illustrate the showback pipeline (Cost Management export →
   allocator → showback container → Cost Insights) with an interactive per-team /
   per-product breakdown using representative figures.
7. **Personas & journeys** — pick a persona, see their journey and the platform
   features that serve it.
8. **Concepts glossary** — short, linkable definitions (IDP, paved road, GitOps,
   workload identity, SBOM, showback, etc.).
9. **Get started / next steps** — links to the repo, the docs rewrite's
   how-it-works guides, and the golden-path templates.

## Interactivity (the "interactive" requirement)

- **Interactive architecture diagram** — clickable/zoomable layered + component
  view; hover for summaries, click for detail panels with ADR/doc deep links.
  Built from the same Mermaid/diagram source used in the docs, or an SVG with an
  interactive overlay.
- **Animated golden-path flow** — scroll- or click-driven step sequence with state
  transitions and the artifact produced at each hop.
- **Capability / persona filter** — toggle a persona to highlight the relevant
  capabilities across the page.
- **Profile switcher** — `demo` vs `nonprod` vs `prod` toggles that update posture
  callouts (cost vs HA vs security).
- **Cost showback visualization** — interactive bar/treemap of cost by team and
  product (representative data), demonstrating the FinOps story.
- **Copyable snippets** — key commands/manifests with copy buttons.
- **Light/dark theme**, smooth section transitions, and respectful motion
  (honor `prefers-reduced-motion`).

## Technology choice

Primary recommendation: **Astro** + a small number of interactive "islands"
(React or Svelte) for the explorer/flow/charts, with **MDX** for content and a
charting/diagram lib (e.g. D3, visx, or Mermaid + a custom interactive overlay;
ECharts/Recharts for the cost visualization).

Rationale: Astro ships mostly static HTML with hydration only where needed (great
Lighthouse scores), first-class GitHub Pages support, MDX authoring, and islands
for the interactive pieces without a heavy SPA.

| Option | Pros | Cons |
| --- | --- | --- |
| **Astro (recommended)** | Fast, content-first, islands for interactivity, easy Pages deploy, MDX | New dependency/build to maintain |
| Docusaurus | React + MDX, batteries-included docs/site, easy Pages | Heavier, more "docs-shaped," more JS by default |
| MkDocs Material | Reuses existing TechDocs stack | Weaker for bespoke interactivity/animation |
| Custom Vite + React/Svelte | Maximum control | Most build/maintenance effort |

Keep the toolchain consistent with the repo where possible: Node 20, pnpm or the
Backstage app's yarn — decide and pin. Pin all versions.

## Deployment (GitHub Pages)

- Site source in a dedicated directory (`site/`), with its own `package.json`.
- A dedicated workflow (`.github/workflows/pages.yml`) that builds the static
  output and deploys via the official Pages actions
  (`actions/configure-pages`, `actions/upload-pages-artifact`,
  `actions/deploy-pages`) using the `github-pages` environment and least-privilege
  `pages: write` + `id-token: write` permissions.
- Triggers: on push to the default branch when `site/**` changes, plus manual
  dispatch. PRs build (no deploy) for preview validation.
- Set Astro `base`/`site` correctly for the Pages URL (project-pages subpath) or a
  custom domain. Optional `CNAME` for a custom domain.
- Caching for `node_modules`/build to keep deploys fast.

## Design & quality

- A lightweight design system (tokens for color, type, spacing), responsive
  mobile-first layout, accessible components (WCAG 2.1 AA: contrast, keyboard nav,
  focus states, alt text, ARIA for the interactive diagram).
- Performance budget: Lighthouse ≥ 95 (perf/a11y/best-practices/SEO); minimal JS;
  lazy-load heavy visuals.
- SEO + social: meta tags, Open Graph/Twitter cards, sitemap, favicon.
- Analytics: optional, privacy-respecting (or none).

## Content sourcing

- Reuse the diagrams and capability model produced by the docs rewrite (avoid a
  third source of truth for architecture).
- Concept text is original/educational; link to authoritative external references
  (CNCF platforms whitepaper, Team Topologies, etc.) where helpful.
- Cost figures use clearly-labelled representative data (the live demo is gone).

## Acceptance criteria

1. A static site builds from `site/` and deploys to GitHub Pages via a dedicated
   Actions workflow on push to the default branch.
2. The site explains platform-engineering concepts (IDP, golden paths, GitOps,
   policy-as-code, secure-by-default, supply chain, self-service, FinOps) for a
   non-expert.
3. At least three genuinely interactive features work and are keyboard-accessible:
   the architecture explorer, the golden-path walkthrough, and the cost
   visualization.
4. Every concept section links to where the project proves it (repo path, doc, or
   ADR).
5. Responsive on mobile/desktop; Lighthouse ≥ 95 across categories; honors
   `prefers-reduced-motion`.
6. No secrets, tenant IDs, or live endpoints embedded; cost/demo data is labelled
   representative.
7. The site clearly defers operational depth to the docs (no duplicated runbooks).
8. Versions pinned; the Pages workflow uses least-privilege permissions and the
   official Pages deploy actions.

## Phasing / milestones

1. **Skeleton + deploy pipeline** — scaffold Astro in `site/`, wire the Pages
   workflow, ship a hero + "what is platform engineering" page (proves the
   end-to-end deploy).
2. **Concepts, applied** — the interactive concept cards with deep links.
3. **Architecture explorer** — the flagship interactive diagram.
4. **Golden-path walkthrough + cost visualization** — the two narrative
   interactives.
5. **Personas, glossary, polish** — a11y/perf/SEO pass, social cards, custom
   domain (optional).

## Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Concept site drifts from the real architecture | Source diagrams/capability model from the docs rewrite; review together. |
| Interactivity hurts performance/accessibility | Astro islands (hydrate only what's needed), perf/a11y budgets in CI (Lighthouse), reduced-motion support. |
| Maintenance burden of a second toolchain | Keep it small and static; pin versions; isolate in `site/`; no backend. |
| Pages base-path/asset issues | Configure Astro `site`/`base` for the Pages subpath; test the built artifact, not just dev. |
| Embedding stale/sensitive demo data | Use labelled representative figures; pre-publish secret scan. |
| Overlap/confusion with TechDocs | Explicit "this is concepts; docs are reference" framing and cross-links. |

## Open questions

- Custom domain or default `*.github.io` project page?
- Astro vs Docusaurus final call (recommendation: Astro).
- How much of the cost story to show, and with what representative dataset?
- Does the site live in this repo (`site/`) or a dedicated repo? (Recommendation:
  this repo, for a single source and simpler linking.)
