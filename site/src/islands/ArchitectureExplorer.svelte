<script lang="ts">
  import { layers, owners } from "../lib/data/architecture";
  import { repoPath } from "../lib/base";

  const ordered = [...layers].reverse(); // top of stack (L10) first
  const ownerList = Object.values(owners);

  let selectedId = $state("shared-services");
  let ownerFilter = $state<string | null>(null);

  const selected = $derived(layers.find((l) => l.id === selectedId) ?? layers[0]);
  const selectedOwner = $derived(owners[selected.owner]);

  const kindIcon: Record<string, string> = { guide: "📘", adr: "⚖", code: "›_" };

  function select(id: string) {
    selectedId = id;
  }

  function onKeydown(e: KeyboardEvent) {
    const idx = ordered.findIndex((l) => l.id === selectedId);
    let next = -1;
    if (e.key === "ArrowDown" || e.key === "ArrowRight") next = Math.min(idx + 1, ordered.length - 1);
    else if (e.key === "ArrowUp" || e.key === "ArrowLeft") next = Math.max(idx - 1, 0);
    else if (e.key === "Home") next = 0;
    else if (e.key === "End") next = ordered.length - 1;
    if (next >= 0) {
      e.preventDefault();
      selectedId = ordered[next].id;
      requestAnimationFrame(() => {
        document.getElementById(`arch-tab-${selectedId}`)?.focus();
      });
    }
  }

  function toggleOwner(id: string) {
    ownerFilter = ownerFilter === id ? null : id;
  }

  function dimmed(id: string) {
    return ownerFilter !== null && layers.find((l) => l.id === id)?.owner !== ownerFilter;
  }
</script>

<div class="arch">
  <div class="arch__legend" role="group" aria-label="Filter layers by owner">
    <span class="arch__legend-title">Owned by</span>
    {#each ownerList as o (o.id)}
      <button
        type="button"
        class="arch__owner"
        class:is-active={ownerFilter === o.id}
        aria-pressed={ownerFilter === o.id}
        onclick={() => toggleOwner(o.id)}
      >
        <span class="arch__owner-dot" style={`background:${o.fill}`}></span>
        {o.label}
      </button>
    {/each}
  </div>

  <div class="arch__grid">
    <div
      class="arch__stack"
      role="tablist"
      aria-label="Platform capability layers, top to bottom"
      aria-orientation="vertical"
      onkeydown={onKeydown}
    >
      {#each ordered as layer (layer.id)}
        {@const o = owners[layer.owner]}
        <button
          type="button"
          role="tab"
          id={`arch-tab-${layer.id}`}
          class="arch__layer"
          class:is-selected={selectedId === layer.id}
          class:is-dim={dimmed(layer.id)}
          aria-selected={selectedId === layer.id}
          aria-controls="arch-panel"
          tabindex={selectedId === layer.id ? 0 : -1}
          style={`--owner:${o.fill}; --owner-ink:${o.ink}`}
          onclick={() => select(layer.id)}
        >
          <span class="arch__level mono">{layer.level}</span>
          <span class="arch__layer-body">
            <span class="arch__layer-name">{layer.name}</span>
            <span class="arch__layer-tech">{layer.tech.slice(0, 3).join(" · ")}</span>
          </span>
          <span class="arch__owner-dot arch__owner-dot--layer" style={`background:${o.fill}`} aria-hidden="true"></span>
        </button>
      {/each}
    </div>

    <div
      class="arch__panel"
      id="arch-panel"
      role="tabpanel"
      tabindex="0"
      aria-labelledby={`arch-tab-${selectedId}`}
    >
      {#key selectedId}
        <div class="arch__panel-inner panel-enter">
          <div class="arch__panel-head">
            <span class="arch__level arch__level--lg mono">{selected.level}</span>
            <h3>{selected.name}</h3>
          </div>
          <span class="arch__panel-owner" style={`--owner:${selectedOwner.fill}; --owner-ink:${selectedOwner.ink}`}>
            <span class="arch__owner-dot" style={`background:${selectedOwner.fill}`}></span>
            Owned by {selectedOwner.label}
          </span>

          <p class="arch__summary">{selected.summary}</p>

          <div class="arch__why">
            <span class="arch__why-label">Why it's here</span>
            <p>{selected.why}</p>
          </div>

          <div class="arch__components">
            <span class="arch__sub-label">Key components</span>
            <ul role="list" class="arch__chips">
              {#each selected.tech as t (t)}
                <li class="arch__tech mono">{t}</li>
              {/each}
            </ul>
          </div>

          <div class="arch__proofs">
            <span class="arch__sub-label">Proof in the repo</span>
            <div class="arch__chips">
              {#each selected.proofs as p (p.path)}
                <a class="arch__proof" href={repoPath(p.path)} target="_blank" rel="noopener">
                  <span class="arch__proof-kind mono" aria-hidden="true">{kindIcon[p.kind]}</span>
                  {p.label}
                  <span class="arch__proof-ext" aria-hidden="true">↗</span>
                </a>
              {/each}
            </div>
          </div>
        </div>
      {/key}
    </div>
  </div>
</div>

<style>
  .arch {
    margin-top: var(--s-xl);
  }
  .arch__legend {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: var(--s-md);
  }
  .arch__legend-title {
    font-size: var(--text-sm);
    color: var(--faint);
    margin-right: 0.25rem;
  }
  .arch__owner {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    padding: 0.32rem 0.7rem;
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline-strong);
    background: var(--bg);
    color: var(--muted);
    font-size: 0.82rem;
    font-weight: var(--w-medium);
    transition:
      color var(--dur-1) var(--ease-out-quart),
      border-color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart);
  }
  .arch__owner:hover {
    color: var(--ink);
    border-color: var(--muted);
  }
  .arch__owner.is-active {
    color: var(--ink);
    border-color: var(--ink);
    background: var(--surface-sunken);
  }
  .arch__owner-dot {
    width: 10px;
    height: 10px;
    border-radius: 3px;
    flex: 0 0 auto;
  }

  .arch__grid {
    display: grid;
    grid-template-columns: minmax(0, 0.85fr) minmax(0, 1.15fr);
    gap: var(--s-lg);
    align-items: start;
  }

  /* Stack */
  .arch__stack {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .arch__layer {
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: 0.85rem;
    text-align: left;
    padding: 0.7rem 0.85rem;
    border-radius: var(--radius);
    border: var(--hair) solid var(--hairline);
    background: var(--surface);
    position: relative;
    transition:
      border-color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart),
      transform var(--dur-1) var(--ease-out-quart),
      opacity var(--dur-2) var(--ease-out-quart);
  }
  .arch__layer::before {
    content: "";
    position: absolute;
    inset-block: 8px;
    left: 0;
    width: 3px;
    border-radius: 3px;
    background: var(--owner);
    opacity: 0;
    transition: opacity var(--dur-1) var(--ease-out-quart);
  }
  .arch__layer:hover {
    border-color: var(--hairline-strong);
    background: var(--bg);
    transform: translateX(2px);
  }
  .arch__layer.is-selected {
    border-color: var(--accent);
    background: var(--bg);
    box-shadow: var(--shadow-sm);
  }
  .arch__layer.is-selected::before {
    opacity: 1;
  }
  .arch__layer.is-dim {
    opacity: 0.4;
  }
  .arch__level {
    font-size: 0.78rem;
    font-weight: var(--w-semibold);
    color: var(--faint);
    width: 2.1rem;
  }
  .arch__layer.is-selected .arch__level {
    color: var(--accent-deep);
  }
  .arch__layer-body {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .arch__layer-name {
    font-weight: var(--w-semibold);
    color: var(--ink);
    font-size: 0.98rem;
  }
  .arch__layer-tech {
    font-size: 0.76rem;
    color: var(--faint);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .arch__owner-dot--layer {
    width: 9px;
    height: 9px;
    border-radius: 50%;
  }

  /* Panel */
  .arch__panel {
    border: var(--hair) solid var(--hairline);
    border-radius: var(--radius-lg);
    background: var(--bg);
    box-shadow: var(--shadow-md);
    padding: clamp(1.25rem, 1rem + 1.5vw, 2rem);
    position: sticky;
    top: 5.5rem;
    min-height: 22rem;
  }
  .arch__panel:focus-visible {
    box-shadow: var(--shadow-md), var(--focus-ring);
  }
  .arch__panel-head {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  .arch__level--lg {
    font-size: 0.95rem;
    width: auto;
    padding: 0.2rem 0.5rem;
    border-radius: var(--radius-sm);
    background: var(--accent-wash);
    color: var(--accent-deep);
  }
  .arch__panel-head h3 {
    font-size: 1.5rem;
  }
  .arch__panel-owner {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    margin-top: 0.75rem;
    font-size: 0.82rem;
    font-weight: var(--w-medium);
    color: var(--owner-ink);
    padding: 0.25rem 0.6rem;
    border-radius: var(--radius-pill);
    background: color-mix(in oklab, var(--owner) 12%, transparent);
  }
  .arch__summary {
    margin-top: var(--s-md);
    color: var(--ink);
    font-size: 1.05rem;
    line-height: 1.55;
  }
  .arch__why {
    margin-top: var(--s-md);
    padding: var(--s-sm) var(--s-md);
    border-radius: var(--radius);
    background: var(--surface-sunken);
  }
  .arch__why-label,
  .arch__sub-label {
    display: block;
    font-size: 0.72rem;
    font-weight: var(--w-semibold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
    color: var(--faint);
    margin-bottom: 0.4rem;
  }
  .arch__why p {
    color: var(--muted);
    line-height: 1.55;
  }
  .arch__components,
  .arch__proofs {
    margin-top: var(--s-md);
  }
  .arch__chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.45rem;
  }
  .arch__tech {
    padding: 0.28rem 0.6rem;
    border-radius: var(--radius-sm);
    background: var(--surface);
    border: var(--hair) solid var(--hairline);
    font-size: 0.78rem;
    color: var(--muted);
  }
  .arch__proof {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.32rem 0.6rem;
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline-strong);
    font-size: 0.8rem;
    color: var(--ink);
    font-weight: var(--w-medium);
    transition:
      border-color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart),
      color var(--dur-1) var(--ease-out-quart);
  }
  .arch__proof-kind {
    color: var(--faint);
    font-size: 0.72rem;
  }
  .arch__proof-ext {
    color: var(--faint);
  }
  .arch__proof:hover {
    text-decoration: none;
    border-color: var(--accent);
    background: var(--accent-wash);
    color: var(--accent-deep);
  }

  .panel-enter {
    animation: panel-in 0.34s var(--ease-out-expo) both;
  }
  @keyframes panel-in {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
  }

  @media (max-width: 820px) {
    .arch__grid {
      grid-template-columns: 1fr;
    }
    .arch__panel {
      position: static;
    }
  }
</style>
