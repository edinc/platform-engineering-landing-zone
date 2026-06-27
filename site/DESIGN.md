# Design

> Visual system for the Interactive platform-engineering concepts site.
> Lane: **"Engineered-light"** — white/near-white, one committed technical accent,
> crisp architecture/systems diagrams as the hero motif. Stripe/Vercel/Linear-grade
> clarity; credible without the dev-tool-dark cliché. All color in OKLCH.

## Theme

Precise, engineered, trustworthy. A bright, quiet, morning workshop: a clean
architecture diagram on a large monitor; the feeling is precision and control, not
hustle. The page reads like schematic drawing — thin structural hairlines, generous
white, one decisive electric-indigo signal, and real interactive diagrams doing the
talking. Light is primary; an optional dark theme is secondary and inherits the
same structure.

**Color strategy:** *Restrained* brand chrome + **one Committed technical accent**,
plus a disciplined *categorical* palette reserved exclusively for the diagrams
(legitimate data-viz, never brand chrome).

## Color

Light theme (primary). All values OKLCH.

| Token | Value | Role |
| --- | --- | --- |
| `--bg` | `oklch(1 0 0)` | Page surface — pure white, no hidden warmth. |
| `--surface` | `oklch(0.985 0.002 270)` | Raised panels / detail cards. |
| `--surface-sunken` | `oklch(0.965 0.004 270)` | Insets, code wells. |
| `--ink` | `oklch(0.23 0.02 270)` | Body + headings. Verified ≥4.5:1 on white. |
| `--muted` | `oklch(0.45 0.02 270)` | Secondary text. ≥4.5:1 — never light-gray body. |
| `--faint` | `oklch(0.58 0.015 270)` | Tertiary / captions on white (large text only). |
| `--accent` | `oklch(0.52 0.19 270)` | Electric indigo — the one committed signal. |
| `--accent-deep` | `oklch(0.40 0.16 270)` | Hover / active / depth; accessible on white. |
| `--accent-wash` | `oklch(0.96 0.03 270)` | Tints behind active states only. |
| `--hairline` | `oklch(0.92 0.01 270)` | 1px schematic structure lines. |
| `--hairline-strong` | `oklch(0.86 0.012 270)` | Emphasis dividers. |

Dark theme (secondary): `--bg oklch(0.20 0.02 270)`, `--surface oklch(0.24 0.02 270)`,
`--ink oklch(0.95 0.01 270)`, `--muted oklch(0.74 0.02 270)`, `--accent oklch(0.72 0.16 270)`
(lifted for contrast on dark), `--hairline oklch(0.32 0.02 270)`.

**Diagram categoricals** (5–7 hues, even L/C, colorblind-safe; *only* inside the
architecture explorer / flows to encode layers & ownership). Tuned around L≈0.62,
C≈0.13 for distinguishability and AA label contrast:

| Role | Light value |
| --- | --- |
| cat-1 identity | `oklch(0.62 0.14 264)` |
| cat-2 network | `oklch(0.66 0.13 196)` |
| cat-3 platform | `oklch(0.70 0.14 162)` |
| cat-4 gitops | `oklch(0.74 0.14 130)` |
| cat-5 supply-chain | `oklch(0.76 0.13 92)` |
| cat-6 observability | `oklch(0.70 0.14 56)` |
| cat-7 portal | `oklch(0.64 0.16 24)` |

Rule: gray text never sits on a colored fill — use a darker shade of the fill's own
hue or a transparency of the ink.

## Typography

Voice words: *precise · engineered · trustworthy*. Reflex-reject defaults avoided
(Inter, DM Sans, Space Grotesk, IBM Plex).

- **Display + UI:** **Mona Sans** (open, variable; fitting for a GitHub-hosted
  platform-engineering brand). Self-hosted variable woff2, `font-optical-sizing: auto`.
- **Mono:** **Commit Mono** — used *only* where it's honest: code, manifests,
  diagram labels, artifact names. Mono is content, never costume.
- **Fallbacks:** metric-matched (`size-adjust` / ascent / descent overrides) to
  eliminate CLS; `font-display: swap`. Preload only the regular display weight.

Scale: modular **≥1.25** ratio, fluid `clamp()` for display/headings (max ≤ 6rem),
fixed `rem` for body. Display letter-spacing ≥ -0.04em. `text-wrap: balance` on
h1–h3; `text-wrap: pretty` on prose. Body 1rem/1.6, measure 65–75ch. Weights: 400
body, 500 UI labels, 600 subheads, 700 display. `tabular-nums` for cost figures.

| Step | clamp / size | Role |
| --- | --- | --- |
| display | `clamp(2.5rem, 1.4rem + 4.6vw, 5rem)` | Hero h1 |
| h2 | `clamp(1.9rem, 1.3rem + 2.4vw, 2.85rem)` | Section titles |
| h3 | `clamp(1.3rem, 1.05rem + 1vw, 1.6rem)` | Subsection |
| lead | `1.25rem` | Hero/section lead |
| body | `1rem` | Prose |
| sm | `0.875rem` | Metadata, captions |
| mono | `0.9rem` | Code / labels |

## Spacing & Layout

4pt base scale: `--space-1..` = 4, 8, 12, 16, 24, 32, 48, 64, 96, 128px, exposed as
`--s-3xs … --s-4xl`. Section rhythm via `clamp()` (tight groupings, generous
separations — vary, never uniform). Content max-width ~72rem; prose column 68ch.
Flexbox for 1D, Grid for 2D; `repeat(auto-fit, minmax(280px, 1fr))` for
breakpoint-free groups. Semantic z-index scale: base → nav(100) → sticky(200) →
backdrop(300) → panel/modal(400) → toast(500) → tooltip(600). No 9999.

Cards used sparingly (never the default, never nested). Hairlines and white space
carry grouping. Schematic feel: 1px structural rules, not colored side-stripes.

## Components

- **Buttons:** primary = solid `--accent` ink-on-accent (verified contrast),
  hover→`--accent-deep`; secondary = hairline outline on white; ghost = text +
  underline-on-hover. focus-visible: 2px accent ring + 2px offset. Radius 8px.
- **Nav:** sticky top, hairline underline on scroll, in-page anchors with
  scroll-spy active state (accent underline), skip-link first.
- **Concept block:** two-column "idea ↔ how this project does it" with a proof
  link (repo path / how-it-works / ADR) rendered as a mono chip — not a card grid.
- **Detail panel** (explorer/flow): raised `--surface`, hairline, mono artifact
  name, what / why / proof links; opens as accessible region, ESC to close.
- **Code/manifest well:** `--surface-sunken`, Commit Mono, copy button, scroll-x.
- **Toggle group** (profile / persona / cost dimension): segmented control,
  roving-tabindex, `aria-pressed`, accent active fill.
- **Chip / tag:** hairline pill, mono, for tags + proof links.

## Iconography

Sparse, single set, 1.5px stroke line icons (custom inline SVG or one library;
never mixed). Icons support labels, never replace them. The real "imagery" is the
**custom architecture / systems diagrams** (interactive SVG) — zero stock photos,
zero colored-block placeholders. Diagrams must be real and decisive.

## Motion

Intentional, part of the build — one orchestrated page-load, then diagram-driven
reveals (explorer detail panels, golden-path stepping). Ease-out exponential
(quart/quint/expo), no bounce, no elastic. Durations 150–420ms; stagger list items
where it fits the content (never a uniform fade-on-every-section reflex). Content is
visible by default; reveals enhance, never gate. Premium materials allowed when they
earn it: blur, mask, clip-path, soft shadow/glow on the diagrams. Every animation
has a `prefers-reduced-motion: reduce` crossfade/instant fallback. A real motion lib
(Motion) drives the explorer/flow.

## Accessibility

WCAG 2.1 AA. Verified contrast (see Color), keyboard operability for every
interactive, visible focus, ARIA for diagram + flow, colorblind-safe categoricals,
honored reduced-motion, zoomable to 200%, 44px touch targets, body never below 16px.

## Anchors / Anti-references

Anchors: Stripe (clarity-on-white + precise product diagrams), Vercel (monochrome
precision + crisp motion), Linear (engineered restraint). Banned: dev-tool-dark,
SaaS-cream/editorial-serif, gradient-blob heroes, hero-metric template, per-section
uppercase eyebrows, 01/02/03 markers, gradient text, decorative glassmorphism,
identical icon-card grids, side-stripe borders.
