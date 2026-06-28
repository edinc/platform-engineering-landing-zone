<script lang="ts">
  import { groups, nodes, edges, owners } from "../lib/data/architectureDiagram";
  import { logos } from "../lib/logos";
  import { repoPath } from "../lib/base";

  let selectedId = $state<string | null>(null);
  let hoveredId = $state<string | null>(null);

  const selected = $derived(nodes.find((n) => n.id === selectedId) ?? null);
  const selectedOwner = $derived(selected ? owners[selected.owner] : null);
  const activeId = $derived(hoveredId ?? selectedId);

  const connected = $derived(
    new Set(
      activeId
        ? edges
            .filter((e) => e.from === activeId || e.to === activeId)
            .flatMap((e) => [e.from, e.to])
        : [],
    ),
  );

  const kindIcon: Record<string, string> = { guide: "📘", adr: "⚖", code: "›_" };

  function edgePath(pts: [number, number][]) {
    return "M " + pts.map((p) => p.join(" ")).join(" L ");
  }
  function logoSize(n: { h: number }) {
    return Math.min(n.h - 14, 34);
  }
  function select(id: string) {
    selectedId = id;
  }
  function logoColor(name: string): string {
    if (name === "github") return "var(--ink)"; // monochrome mark, theme-adaptive
    return logos[name]?.color ?? "var(--muted)";
  }
  function onNodeKey(e: KeyboardEvent, id: string) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      select(id);
    }
  }
</script>

{#snippet logoMark(name: string, tx: number, ty: number, s: number, fill: string)}
  {@const def = logos[name]}
  {#if def}
    <g
      transform={`translate(${tx},${ty}) scale(${s / 24})`}
      fill={fill}
      fill-rule={def.fillRule ?? "nonzero"}
    >
      {#each def.paths as p (p.d)}
        <path d={p.d} opacity={p.opacity ?? 1}></path>
      {/each}
    </g>
  {/if}
{/snippet}

<div class="amap">
  <div class="amap__canvas">
    <svg
      viewBox="0 0 1000 660"
      role="group"
      aria-label="Interactive platform architecture diagram. Tab to a component and press Enter for its details."
    >
      <!-- group frames -->
      {#each groups as g (g.id)}
        <g class={`amap-frame amap-frame--${g.kind}`} aria-hidden="true">
          <rect x={g.x} y={g.y} width={g.w} height={g.h} rx="16"></rect>
          <text class="amap-frame__label" x={g.x + 20} y={g.y + 26}>{g.label}</text>
          {#if g.logo}
            {@render logoMark(g.logo, g.x + g.w - 38, g.y + 8, 22, logoColor(g.logo))}
          {/if}
        </g>
      {/each}

      <!-- edges -->
      {#each edges as e (e.from + e.to)}
        {@const active = activeId != null && (e.from === activeId || e.to === activeId)}
        <g class="amap-edge" class:is-active={active} aria-hidden="true">
          <path
            d={edgePath(e.points)}
            fill="none"
            stroke-dasharray={e.dashed ? "5 5" : undefined}
          ></path>
          <text class="amap-edge__label" x={e.labelAt[0]} y={e.labelAt[1]}>{e.label}</text>
        </g>
      {/each}

      <!-- nodes -->
      {#each nodes as n (n.id)}
        {@const ls = logoSize(n)}
        {@const lx = n.bar ? n.x + 18 : n.x + n.w - 14 - ls}
        {@const ly = n.y + (n.h - ls) / 2}
        <g
          class="amap-node"
          class:is-selected={selectedId === n.id}
          class:is-connected={connected.has(n.id) && activeId !== n.id}
          class:is-dim={activeId != null && activeId !== n.id && !connected.has(n.id)}
          class:amap-node--bar={n.bar}
          role="button"
          tabindex="0"
          aria-pressed={selectedId === n.id}
          aria-label={`${n.label}. ${n.summary}`}
          onclick={() => select(n.id)}
          onkeydown={(e) => onNodeKey(e, n.id)}
          onfocus={() => (hoveredId = n.id)}
          onblur={() => (hoveredId = null)}
          onmouseenter={() => (hoveredId = n.id)}
          onmouseleave={() => (hoveredId = null)}
        >
          <rect class="amap-node__box" x={n.x} y={n.y} width={n.w} height={n.h} rx="11"></rect>
          {#if n.bar}
            <text class="amap-node__bar-label" x={n.x + n.w / 2} y={n.y + n.h / 2 + 5}>{n.label}</text>
          {:else}
            <text class="amap-node__label" x={n.x + 18} y={n.y + (n.sub ? 30 : n.h / 2 + 5)}>{n.label}</text>
            {#if n.sub}
              <text class="amap-node__sub" x={n.x + 18} y={n.y + 50}>{n.sub}</text>
            {/if}
          {/if}
          {@render logoMark(n.logo, lx, ly, ls, logoColor(n.logo))}
        </g>
      {/each}
    </svg>
  </div>

  <div class="amap__panel" aria-live="polite">
    {#if !selected}
      <div class="amap__prompt">
        <strong>Explore the platform.</strong> Select any component to see what it is, why it's
        there, who owns it, and the decision behind it. Tab through the boxes and press Enter for
        keyboard access.
      </div>
    {:else}
      {#key selected.id}
        {@const o = selectedOwner!}
        <div class="amap__detail panel-enter">
          <div class="amap__detail-main">
            <div class="amap__detail-head">
              <span class="amap__detail-logo" aria-hidden="true">
                <svg viewBox="0 0 24 24" width="26" height="26" fill={logoColor(selected.logo)} fill-rule={logos[selected.logo]?.fillRule ?? "nonzero"}>
                  {#each logos[selected.logo]?.paths ?? [] as p (p.d)}
                    <path d={p.d} opacity={p.opacity ?? 1}></path>
                  {/each}
                </svg>
              </span>
              <h3>{selected.label}</h3>
              <span class="amap__owner" style={`--owner:${o.fill}; --owner-ink:${o.ink}`}>
                <span class="amap__owner-dot" style={`background:${o.fill}`}></span>{o.label}
              </span>
            </div>
            <p class="amap__summary">{selected.summary}</p>
          </div>
          <div class="amap__detail-aside">
            <div class="amap__why">
              <span class="amap__why-label">Why it's here</span>
              <p>{selected.why}</p>
            </div>
            <div class="amap__proofs">
              {#each selected.proofs as p (p.path)}
                <a class="amap__proof" href={repoPath(p.path)} target="_blank" rel="noopener">
                  <span class="amap__proof-kind" aria-hidden="true">{kindIcon[p.kind]}</span>
                  {p.label}
                  <span aria-hidden="true">↗</span>
                </a>
              {/each}
            </div>
          </div>
        </div>
      {/key}
    {/if}
  </div>
</div>

<style>
  .amap {
    margin-top: var(--s-lg);
  }
  .amap__canvas {
    border: var(--hair) solid var(--hairline);
    border-radius: var(--radius-lg);
    background:
      radial-gradient(120% 120% at 50% 0%, var(--surface), var(--bg) 70%);
    padding: clamp(0.5rem, 0.25rem + 1vw, 1.25rem);
    overflow-x: auto;
    overflow-y: hidden;
    -webkit-overflow-scrolling: touch;
  }
  .amap__canvas svg {
    width: 100%;
    min-width: 660px;
    height: auto;
    display: block;
  }

  /* group frames */
  .amap-frame rect {
    fill: none;
    stroke: var(--hairline-strong);
    stroke-width: 1.5;
  }
  .amap-frame--subscription rect {
    fill: color-mix(in oklab, var(--surface) 60%, transparent);
    stroke-dasharray: 2 6;
    stroke-linecap: round;
  }
  .amap-frame--cluster rect {
    stroke: var(--accent);
    stroke-dasharray: 6 5;
    fill: var(--accent-wash);
    fill-opacity: 0.45;
  }
  .amap-frame--hub rect,
  .amap-frame--workloads rect {
    stroke-dasharray: 4 5;
    fill: color-mix(in oklab, var(--surface-sunken) 70%, transparent);
  }
  .amap-frame__label {
    font-family: var(--font-mono);
    font-size: 12px;
    letter-spacing: 0.02em;
    fill: var(--faint);
    text-transform: uppercase;
  }

  /* edges */
  .amap-edge path {
    stroke: var(--hairline-strong);
    stroke-width: 1.5;
    transition:
      stroke var(--dur-2) var(--ease-out-quart),
      stroke-width var(--dur-2) var(--ease-out-quart);
  }
  .amap-edge__label {
    font-family: var(--font-mono);
    font-size: 11px;
    fill: var(--faint);
    text-anchor: middle;
    transition: fill var(--dur-2) var(--ease-out-quart);
  }
  .amap-edge.is-active path {
    stroke: var(--accent);
    stroke-width: 2.5;
  }
  .amap-edge.is-active .amap-edge__label {
    fill: var(--accent-deep);
  }

  /* nodes */
  .amap-node {
    cursor: pointer;
    outline: none;
  }
  .amap-node__box {
    fill: var(--surface);
    stroke: var(--hairline-strong);
    stroke-width: 1.5;
    transition:
      stroke var(--dur-1) var(--ease-out-quart),
      fill var(--dur-1) var(--ease-out-quart),
      opacity var(--dur-2) var(--ease-out-quart);
  }
  .amap-node--bar .amap-node__box {
    fill: var(--surface-sunken);
  }
  .amap-node:hover .amap-node__box {
    stroke: var(--accent);
    fill: var(--bg);
  }
  .amap-node.is-selected .amap-node__box {
    stroke: var(--accent);
    stroke-width: 2.25;
    fill: var(--bg);
    filter: drop-shadow(var(--shadow-md));
  }
  .amap-node.is-connected .amap-node__box {
    stroke: var(--accent);
    fill: var(--accent-wash);
  }
  .amap-node.is-dim {
    opacity: 0.45;
  }
  .amap-node:focus-visible .amap-node__box {
    stroke: var(--accent);
    stroke-width: 2.25;
  }
  .amap-node:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 3px;
    border-radius: 12px;
  }
  .amap-node__label {
    font-family: var(--font-sans);
    font-size: 15px;
    font-weight: 600;
    fill: var(--ink);
  }
  .amap-node__sub {
    font-family: var(--font-mono);
    font-size: 11px;
    fill: var(--muted);
  }
  .amap-node__bar-label {
    font-family: var(--font-mono);
    font-size: 12.5px;
    fill: var(--muted);
    text-anchor: middle;
  }

  /* detail panel */
  .amap__panel {
    margin-top: var(--s-md);
    min-height: 7.5rem;
  }
  .amap__prompt {
    padding: var(--s-lg);
    border: var(--hair) dashed var(--hairline-strong);
    border-radius: var(--radius-lg);
    color: var(--muted);
    max-width: 70ch;
  }
  .amap__prompt strong {
    color: var(--ink);
  }
  .amap__detail {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--s-lg);
    border: var(--hair) solid var(--hairline);
    border-radius: var(--radius-lg);
    background: var(--bg);
    box-shadow: var(--shadow-sm);
    padding: clamp(1.1rem, 0.9rem + 1vw, 1.75rem);
  }
  .amap__detail-head {
    display: flex;
    align-items: center;
    gap: 0.7rem;
    flex-wrap: wrap;
  }
  .amap__detail-logo {
    display: inline-grid;
    place-items: center;
    width: 2.4rem;
    height: 2.4rem;
    border-radius: var(--radius);
    background: var(--surface);
    border: var(--hair) solid var(--hairline);
  }
  .amap__detail-head h3 {
    font-size: 1.35rem;
  }
  .amap__owner {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.8rem;
    font-weight: var(--w-medium);
    color: var(--owner-ink);
    padding: 0.22rem 0.55rem;
    border-radius: var(--radius-pill);
    background: color-mix(in oklab, var(--owner) 12%, transparent);
  }
  .amap__owner-dot {
    width: 9px;
    height: 9px;
    border-radius: 3px;
  }
  .amap__summary {
    margin-top: var(--s-md);
    font-size: 1.05rem;
    line-height: 1.55;
    color: var(--ink);
  }
  .amap__why {
    padding: var(--s-sm) var(--s-md);
    border-radius: var(--radius);
    background: var(--surface-sunken);
  }
  .amap__why-label {
    display: block;
    font-size: 0.72rem;
    font-weight: var(--w-semibold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
    color: var(--faint);
    margin-bottom: 0.4rem;
  }
  .amap__why p {
    color: var(--muted);
    line-height: 1.55;
  }
  .amap__proofs {
    margin-top: var(--s-md);
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }
  .amap__proof {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.32rem 0.6rem;
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline-strong);
    font-size: 0.8rem;
    font-weight: var(--w-medium);
    color: var(--ink);
  }
  .amap__proof-kind {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    color: var(--faint);
  }
  .amap__proof:hover {
    text-decoration: none;
    border-color: var(--accent);
    background: var(--accent-wash);
    color: var(--accent-deep);
  }

  .panel-enter {
    animation: amap-in 0.32s var(--ease-out-expo) both;
  }
  @keyframes amap-in {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
  }

  @media (max-width: 760px) {
    .amap__detail {
      grid-template-columns: 1fr;
      gap: var(--s-md);
    }
  }
</style>
