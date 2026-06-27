# Product

## Register

brand

## Users

The conceptual front door for the **Azure Platform Engineering Landing Zone** — an
opinionated, secure, compliant Internal Developer Platform (IDP) on Azure. Four
audiences arrive curious and should leave understanding the ideas and knowing
where to go next:

- **Application developers** — want paved roads that remove Azure/Kubernetes toil;
  context is "I just need to ship a service safely."
- **Platform engineers & architects** — want an opinionated reference IDP and the
  decisions behind it; context is "is this how I'd build ours?"
- **Engineering leaders & FinOps** — want faster delivery, guardrails, and cost
  visibility; context is "what does this buy my org?"
- **The platform-curious** — want to learn what an IDP and platform engineering
  actually are; context is "explain this to me."

The job to be done: understand platform-engineering concepts *through this project
as the worked example*, then convert to the repo / docs / golden paths. This site
is the narrative, visual, interactive surface; the repo `docs/` (TechDocs) remain
the operational reference. The site links into the docs for depth and never
duplicates runbooks or setup.

## Product Purpose

Market and explain the platform by teaching the underlying platform-engineering
concepts (IDP, golden paths / paved roads, self-service, cognitive-load reduction,
GitOps, policy-as-code, secure-by-default, supply-chain integrity, FinOps/showback,
ownership boundaries) with the project as the proof. Success is a curious visitor
(engineer, architect, or leader) who understands the ideas, trusts the craft, and
clicks through to the repository, the how-it-works guides, or a golden-path
template. Emotionally it should evoke **precision and control** — "show the machine
working," not hype.

## Brand Personality

**precise · engineered · trustworthy.** Confident and technical without being cold;
it demonstrates the machine working instead of selling it. Voice is plain,
specific, and credible: claims are paired with the place in the repo that proves
them. Calm authority over urgency; clarity over cleverness.

## Anti-references

This must not look AI-generated or like the category's modal landing page.
Explicitly avoid:

- Generic dev-tool **dark dashboards** (the cliché "developer" aesthetic).
- **SaaS-cream / editorial-serif** landing pages (warm near-white + display serif).
- **Gradient-blob heroes** and decorative gradient backgrounds.
- The **hero-metric template** (big number + small label + gradient accent).
- **Tiny uppercase tracked eyebrows** above every section; **01 / 02 / 03** numbered
  section markers used as scaffolding.
- **Gradient text** (`background-clip: text`), decorative **glassmorphism**.
- **Identical icon-card grids** repeated endlessly; **side-stripe borders**.
- Literal "Azure blue" / dev-tool cyan as the brand signal.

## Design Principles

1. **Practice what you preach** — the site is as well-built as the platform it
   describes; craft is the argument.
2. **Show, don't tell** — interactive proof over prose; the diagrams and flows
   *are* the content, not decoration.
3. **Concept paired with proof** — every idea links to where the repo realizes it
   (a path, a how-it-works guide, an ADR).
4. **Defer depth** — the site is the front door; TechDocs is the reference. Don't
   duplicate; link.
5. **Credible, not loud** — earn trust through precision and restraint, not volume.

## Accessibility & Inclusion

WCAG 2.1 AA minimum. Verified contrast (body ≥4.5:1, large text ≥3:1; no light-gray
body on tinted white), full keyboard operability for every interactive, visible
focus, ARIA for the architecture diagram and golden-path flow, colorblind-safe
diagram categoricals, and `prefers-reduced-motion` honored for every animation
(crossfade/instant fallback). Content is visible by default and never gated on a
reveal animation.
