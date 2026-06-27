# Plan: Interactive platform-engineering concepts site (GitHub Pages)

Status: proposed (design brief)
Owner: platform engineering / developer relations
Audience: maintainers building a public educational microsite
Design: shaped with the impeccable `shape` flow (register `brand`, lane "Engineered-light")

## Goal

Build and publish a **dedicated, interactive website** that teaches the concepts
of platform engineering and shows **how this project embodies them**. It is a
conceptual and educational experience — the "why platform engineering, and what a
good Internal Developer Platform looks like" story — distinct from the repository's
operational reference docs (TechDocs).

The product being marketed is **the platform** (the Azure Platform Engineering
Landing Zone IDP). This site is its **brand/explainer surface**: it teaches
platform engineering *through* the project, and converts a curious visitor
(engineer, architect, or leader) into someone who understands the ideas and knows
where to go next (the repo, the docs, the golden paths).

## Register & product context (impeccable)

This doubles as the seed for a future `site/PRODUCT.md` (+ `site/DESIGN.md`) once
the site is scaffolded.

- **Register:** `brand` — design *is* the deliverable; a visitor's impression is
  the thing being made.
- **Product purpose:** market and explain the platform (an opinionated, secure,
  compliant Azure IDP) by teaching the underlying platform-engineering concepts
  with the project as the worked example.
- **Users:** application developers (paved roads remove Azure/K8s toil), platform
  engineers/architects (an opinionated reference IDP + the decisions behind it),
  engineering leaders/FinOps (faster delivery, guardrails, cost visibility), and
  the platform-curious (what *is* an IDP?).
- **Brand personality (3 words):** precise · engineered · trustworthy. Confident
  and technical without being cold; show the machine working, don't hype.
- **Design principles:** (1) *practice what you preach* — the site is as
  well-built as the platform it describes; (2) *show, don't tell* — interactive
  proof over prose; (3) *concept paired with proof* — every idea links to where
  the repo realizes it; (4) *defer depth* — the site is the front door, TechDocs
  is the reference; (5) *credible, not loud* — earn trust through craft.
- **Accessibility:** WCAG 2.1 AA minimum — verified contrast, full keyboard
  operability for every interactive, visible focus, ARIA for the diagram/flow,
  and `prefers-reduced-motion` honored.

## Why a separate site (relationship to the docs)

| Surface | Audience | Job | Tone |
| --- | --- | --- | --- |
| Repo docs / TechDocs (`docs/`) | Operators, contributors | Stand it up, run it, change it | Reference, precise |
| **This Pages site** | Evaluators, learners, leaders | Understand the concepts and how this project applies them | Narrative, visual, interactive |

The site **links into** the docs/repo for depth; it does **not** duplicate
runbooks or setup steps. Single source of truth stays in `docs/`; the site is the
conceptual front door.

## Scope

### In scope

- A standalone static site in this repo (`site/`), with its own `package.json`.
- Conceptual content on platform engineering + an interactive tour of this
  project's architecture and golden paths.
- Interactive components (architecture explorer, golden-path walkthrough, cost
  showback illustration, capability/persona filters, profile switcher).
- A **local-first** workflow: build and preview locally, sign off, then decide on
  GitHub Pages deployment.
- Design system (tokens), responsive layout, accessibility, performance budgets,
  SEO/social cards.

### Out of scope

- Operational runbooks, exhaustive API/IaC reference (those live in TechDocs).
- A live, connected demo against real Azure (use recorded/illustrative data; the
  demo environment is torn down).
- Backend services — the site is fully static.

## Narrative arc

**Problem** (cognitive load, snowflake infra, slow & unsafe delivery) → **Idea**
(platform engineering + IDP + golden paths) → **This project** (how each concept
is realized, securely, on Azure) → **Try it** (repo, docs, golden paths).

## Information architecture (pages/sections)

1. **Home / hero** — one-line thesis, a live interactive architecture teaser,
   primary CTAs (Explore the architecture · Read the docs · View on GitHub).
2. **What is platform engineering?** — IDP, golden paths / paved roads,
   self-service, cognitive-load reduction, "you build it, you run it" with
   guardrails, Team Topologies (platform-as-enabling-team) framing.
3. **Core concepts, applied** — one interactive section per concept, pairing the
   *idea* with *how this project does it* and a link to the proof: golden paths,
   GitOps (Flux + separate cluster-state repo), policy-as-code (Kyverno + Azure
   Policy + OPA/conftest), secure-by-default (private AKS, Workload Identity,
   default-deny egress, signed images, Private Link), supply-chain (OIDC, cosign
   keyless, SBOM, scanning), self-service & vending (Backstage), ownership
   boundaries (ALZ vs Terraform vs Flux vs ASO vs Backstage), FinOps/showback.
4. **Architecture explorer** (flagship) — the layered/component diagram where
   clicking a layer or component reveals what it is, why it's there, and the
   ADR/doc behind it.
5. **Golden-path walkthrough** — animated step-through of a request's life:
   Backstage form → PR → reusable workflow → Terraform apply → Azure identity +
   RBAC → cluster-state PR → Flux reconcile → running, governed namespace; each
   step expandable with the real artifact it produces.
6. **Cost & FinOps** — the showback pipeline (Cost Management export → allocator →
   showback container → Cost Insights) with an interactive per-team/per-product
   breakdown using clearly-labelled representative figures.
7. **Personas & journeys** — pick a persona, see their journey and the platform
   features that serve it.
8. **Concepts glossary** — short, linkable definitions (IDP, paved road, GitOps,
   Workload Identity, SBOM, showback, etc.).
9. **Get started / next steps** — repo, the how-it-works guides, golden-path
   templates.

## Design direction — "Engineered-light"

The lane: white/near-white, one committed technical accent, crisp
architecture/systems diagrams as the hero motif; Stripe/Vercel-grade clarity —
credible without the dev-tool-dark cliché.

**Scene sentence (forces light):** a platform engineer at a standing desk in a
bright, quiet office in the morning, a large monitor showing a clean architecture
diagram — the feeling is precision and control, not hustle.

**Color strategy:** *Restrained* brand chrome + **one Committed technical
accent**, plus a disciplined *categorical* palette reserved for the diagrams
(legitimate data-viz, not brand chrome). OKLCH throughout.

| Role | Value (seed, OKLCH) | Notes |
| --- | --- | --- |
| Surface `bg` | `oklch(1 0 0)` (pure white) | No hidden warmth; the accent + type carry the brand. |
| Ink (body) | `oklch(0.23 0.02 270)` | Cool near-black; verified ≥4.5:1 on white. |
| Muted | `oklch(0.45 0.02 270)` | Secondary text only; still ≥4.5:1 (no light-gray body). |
| Primary accent | `oklch(0.52 0.19 270)` electric indigo | One committed signal; deliberately *not* literal "Azure blue", *not* dev-tool cyan. |
| Accent-deep | `oklch(0.38 0.16 270)` | Hover/active/depth. |
| Hairline | `oklch(0.92 0.01 270)` | 1px structure lines (schematic feel), never side-stripe accents. |
| Diagram categoricals | 5–7 hues, even L/C, colorblind-safe | Only inside the architecture explorer / flows to encode layers & ownership. |

**Typography (procedure, not reflex):** voice words *precise · engineered ·
trustworthy*. Avoid the reflex-reject defaults (Inter, DM Sans, Space Grotesk,
IBM Plex, etc.). Direction: a distinctive grotesque for display+UI (candidates:
**Mona Sans** — open, variable, fitting for a GitHub-hosted platform-eng brand —
or **Hanken Grotesk**) paired with a real coding **mono** used *only* where it's
honest (code, manifests, diagram labels — candidates **Commit Mono** / **Martian
Mono**), so mono is content, never costume. Modular scale ≥1.25, fluid `clamp()`,
display ceiling ≤6rem, display letter-spacing ≥ -0.04em, `text-wrap: balance` on
headings, body line length 65–75ch.

**Motion:** intentional, part of the build — one orchestrated page-load, then
diagram-driven reveals (explorer detail panels, golden-path stepping). Ease-out
exponential curves, no bounce; a `prefers-reduced-motion` crossfade/instant
fallback for every animation; content visible by default (never gated on a
reveal). Use a real motion lib (Motion/GSAP) for the explorer/flow.

**Imagery = the diagrams.** For this brand the "imagery" is the custom
architecture/systems visualizations (interactive SVG/canvas), not stock photos.
Zero colored-block placeholders; the diagrams must be real and decisive.

**Anchor references:** Stripe (clarity-on-white + precise product diagrams),
Vercel (monochrome precision + crisp motion), Linear (engineered restraint).

**Anti-references (explicitly avoid):** generic dev-tool dark dashboards;
SaaS-cream / editorial-serif landing pages; gradient-blob heroes; the hero-metric
template (big number + gradient); tiny uppercase tracked eyebrows or 01/02/03
numbered markers above every section; gradient text; decorative glassmorphism;
identical icon-card grids; side-stripe borders.

## Interactivity (the "interactive" requirement)

- **Interactive architecture diagram** — clickable/zoomable layered + component
  view; hover for summaries, click for detail panels with ADR/doc deep links.
  Built from the same diagram source/capability model used in `docs/`.
- **Animated golden-path flow** — click- or scroll-driven step sequence with the
  artifact produced at each hop.
- **Capability / persona filter** — toggle a persona to highlight relevant
  capabilities across the page.
- **Profile switcher** — `demo` / `nonprod` / `prod` toggles that update posture
  callouts (cost vs HA vs security).
- **Cost showback visualization** — interactive bar/treemap by team and product
  (representative data).
- **Copyable snippets**, light/dark theme (light is primary), respectful motion.

Every interactive is keyboard-operable and reduced-motion aware.

## Technology choice

Primary: **Astro** + a few interactive "islands" (Svelte or React) for the
explorer/flow/charts, **MDX** for content, and a charting/diagram approach (D3 /
visx for the bespoke explorer; ECharts/Recharts for cost). Rationale: ships mostly
static HTML with hydration only where needed (strong Lighthouse), first-class
Pages support, MDX authoring, islands without a heavy SPA. Node 20; pnpm; pin all
versions.

| Option | Pros | Cons |
| --- | --- | --- |
| **Astro (recommended)** | Fast, content-first, islands, easy Pages, MDX | New build to maintain |
| Docusaurus | React + MDX, batteries-included | Heavier, "docs-shaped" |
| MkDocs Material | Reuses TechDocs stack | Weak for bespoke interactivity |
| Custom Vite + Svelte/React | Max control | Most maintenance |

## Deployment — local preview first, Pages later (gated)

**This is a hard requirement: validate locally and get sign-off before any
GitHub Pages deploy.**

1. **Phase A — local only.** Scaffold `site/` (Astro). Iterate with `astro dev`,
   then build and serve the **production** build with `astro preview` to validate
   the real artifact (base-path, hydration, perf, a11y). The maintainer reviews
   and signs off. **No Pages workflow is enabled and nothing deploys in this
   phase.**
2. **Phase B — Pages (only after sign-off).** Add `.github/workflows/pages.yml`
   using the official Pages actions (`actions/configure-pages`,
   `actions/upload-pages-artifact`, `actions/deploy-pages`), the `github-pages`
   environment, and least-privilege `pages: write` + `id-token: write`. Until
   sign-off the workflow is absent or `workflow_dispatch`-only — it does **not**
   auto-deploy on push. PRs build for preview validation (no deploy).
3. Configure Astro `site`/`base` for the project-pages subpath (or a custom
   domain). Verify the built artifact locally before the first deploy. Cache
   `node_modules`/build for fast deploys. Optional `CNAME` for a custom domain.

## Design & quality

- Lightweight design system (the tokens above), responsive mobile-first, accessible
  components (contrast, keyboard nav, focus, alt text, ARIA for the diagram).
- Performance budget: Lighthouse ≥ 95 (perf/a11y/best-practices/SEO); minimal JS;
  lazy-load heavy visuals.
- SEO + social: meta, Open Graph/Twitter cards, sitemap, favicon.
- Analytics: optional, privacy-respecting (or none).

## Content sourcing

- Reuse the diagrams and capability model from `docs/` (avoid a third source of
  truth for architecture).
- Concept text is original/educational; link authoritative external references
  (CNCF platforms whitepaper, Team Topologies) where helpful.
- Cost figures use clearly-labelled representative data (the live demo is gone).

## Acceptance criteria

1. The site builds from `site/` and runs as a **local production preview**
   (`astro preview`) that the maintainer reviews and **approves before any Pages
   deploy**.
2. GitHub Pages deployment (when approved) uses a dedicated Actions workflow with
   the official Pages actions and least-privilege permissions; it does not
   auto-deploy before sign-off.
3. The site explains platform-engineering concepts (IDP, golden paths, GitOps,
   policy-as-code, secure-by-default, supply chain, self-service, FinOps) for a
   non-expert.
4. At least three genuinely interactive, keyboard-accessible features work: the
   architecture explorer, the golden-path walkthrough, and the cost visualization.
5. Every concept section links to where the project proves it (repo path, doc, ADR).
6. Visual direction holds to the Engineered-light brief and passes the AI-slop
   test (none of the listed anti-references; verified contrast; real diagrams, not
   placeholder blocks).
7. Responsive on mobile/desktop; Lighthouse ≥ 95 across categories; honors
   `prefers-reduced-motion`.
8. No secrets, tenant IDs, or live endpoints embedded; cost/demo data labelled
   representative.
9. Versions pinned.

## Phasing / milestones

1. **Skeleton + LOCAL preview** — scaffold Astro in `site/`, design tokens + the
   hero + "what is platform engineering"; validate via `astro preview` locally.
   **(Sign-off gate — no deploy.)**
2. **Concepts, applied** — interactive concept sections with deep links.
3. **Architecture explorer** — the flagship interactive diagram.
4. **Golden-path walkthrough + cost visualization** — the two narrative interactives.
5. **Personas, glossary, polish** — a11y/perf/SEO pass, social cards.
6. **Pages deployment** — only after local sign-off: add/enable the gated Pages
   workflow; optional custom domain.

## Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Concept site drifts from the real architecture | Source diagrams/capability model from `docs/`; review together. |
| Interactivity hurts performance/accessibility | Astro islands, perf/a11y budgets (Lighthouse), reduced-motion support. |
| Deploying before it's ready | Local-first gate: production preview + sign-off before any Pages deploy. |
| Second toolchain maintenance | Keep small/static; pin versions; isolate in `site/`; no backend. |
| Pages base-path/asset issues | Configure Astro `site`/`base`; test the built artifact locally, not just dev. |
| Stale/sensitive demo data | Labelled representative figures; pre-publish secret scan. |
| Looking AI-generated | Hold to the Engineered-light brief + anti-reference ban list; distinctive type + one committed accent + real diagrams. |

## Resolved decisions

- **Site lives in this repo** at `site/` (single source, simpler linking).
- **Astro** is the framework (recommended above).
- **Default `*.github.io` project page** to start; custom domain optional later.
- **Local preview + sign-off before any GitHub Pages deploy** (hard requirement).
- Visual lane: **Engineered-light** (above).

## Open questions

- Exact display + mono font pairing (shortlist in the brief; pick during build).
- How much of the cost story to show, and with what representative dataset?
- Svelte vs React for the interactive islands (decide at scaffold; lean Svelte for
  smaller hydration).
