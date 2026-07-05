# Platform Engineering Landing Zone — concepts site

The interactive **brand / explainer front door** for the Azure Platform
Engineering Landing Zone. It teaches platform-engineering concepts (golden paths,
GitOps, policy-as-code, secure-by-default, supply chain, self-service, FinOps,
ownership boundaries) using the project itself as the worked example.

This is a standalone, fully static [Astro](https://astro.build) site. It links
into the repository `docs/` (the single source of truth) and never duplicates
runbooks or setup. See `PRODUCT.md` and `DESIGN.md` in this folder for the
strategic and visual system.

## Stack

- **Astro 7** (static output) + **Svelte 5** islands, hydrated on view.
- **MDX**, sitemap.
- Self-hosted variable fonts: **Mona Sans** (display/UI) + **Commit Mono** (code).
- Design tokens in OKLCH (`src/styles/tokens.css`). Light is primary; an optional
  dark theme is provided.
- Node 20.x, pnpm. All versions pinned.

## Develop

```bash
cd site
pnpm install
pnpm dev        # http://localhost:4321/platform-engineering-landing-zone/
```

## Build & validate the real artifact (local-first)

```bash
pnpm check      # astro check (type-checks .astro/.svelte/.ts)
pnpm build      # astro check && astro build  → dist/
pnpm preview    # serve the PRODUCTION build at the real base path
```

`astro preview` serves the built artifact at the same `base` path used on GitHub
Pages, so the base-path, hydration, performance and accessibility are validated
against the real output, not just the dev server.

## Deployment — gated (Phase A: local only)

> **No GitHub Pages workflow is enabled and nothing deploys.** This is a hard
> requirement: the production build is validated locally and signed off **before**
> any Pages deploy is wired up.

When Pages is approved (Phase B), a dedicated workflow using the official Pages
actions (`actions/configure-pages`, `actions/upload-pages-artifact`,
`actions/deploy-pages`) with least-privilege `pages: write` + `id-token: write`
will be added under `.github/workflows/`. The site is already configured for the
project-pages subpath in `astro.config.mjs`
(`base: /platform-engineering-landing-zone`).

## Content sourcing

Concept and architecture content is distilled from the repository docs
(`docs/architecture`, `docs/how-it-works`, `docs/adr`, `docs/runbooks`); every
concept links back to the place that proves it. Cost and walkthrough figures are
clearly-labelled **representative data** — no live endpoints, tenant IDs or secrets.

## Analytics

Traffic is measured with **Cloudflare Web Analytics** — a privacy-first,
cookieless beacon that sets no cookies, collects no personal data and needs no
consent banner. The beacon `<script>` lives in `src/layouts/Layout.astro` and
loads on every page; the site token it carries is public by design (it ships in
the page HTML). Hits are attributed to the registered hostname
(`edinc.github.io`), so filter by the `/platform-engineering-landing-zone/` path
in the Cloudflare dashboard to isolate this site.

## Accessibility

WCAG 2.1 AA: verified contrast, full keyboard operability for every interactive,
visible focus, ARIA for the architecture diagram and golden-path flow,
colour-blind-safe diagram categoricals, and honored `prefers-reduced-motion`.
