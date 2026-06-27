<script lang="ts">
  import { profiles, posture, categoryMeta, type ProfileId } from "../lib/data/profiles";

  let selected = $state<ProfileId>("prod");
  const current = $derived(profiles.find((p) => p.id === selected)!);

  function onKeydown(e: KeyboardEvent) {
    const idx = profiles.findIndex((p) => p.id === selected);
    let next = -1;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (idx + 1) % profiles.length;
    else if (e.key === "ArrowLeft" || e.key === "ArrowUp")
      next = (idx - 1 + profiles.length) % profiles.length;
    if (next >= 0) {
      e.preventDefault();
      selected = profiles[next].id;
      requestAnimationFrame(() => document.getElementById(`prof-${selected}`)?.focus());
    }
  }
</script>

<div class="prof" data-selected={selected}>
  <div class="prof__head">
    <div class="prof__toggle" role="radiogroup" aria-label="Environment profile" onkeydown={onKeydown}>
      {#each profiles as p (p.id)}
        <button
          type="button"
          role="radio"
          id={`prof-${p.id}`}
          class="prof__opt mono"
          class:is-active={selected === p.id}
          aria-checked={selected === p.id}
          tabindex={selected === p.id ? 0 : -1}
          onclick={() => (selected = p.id)}
        >
          {p.label}
        </button>
      {/each}
    </div>
    <p class="prof__intent">
      {#key selected}
        <span class="prof__intent-text">{current.intent}</span>
      {/key}
    </p>
  </div>

  <table class="prof__table">
    <caption class="sr-only">Platform posture across the demo, nonprod and prod profiles</caption>
    <thead>
      <tr>
        <th scope="col" class="prof__corner"><span class="sr-only">Capability</span></th>
        {#each profiles as p (p.id)}
          <th
            scope="col"
            class="prof__col"
            class:is-selected={selected === p.id}
            aria-current={selected === p.id ? "true" : undefined}
          >
            {p.label}
          </th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each posture as row (row.id)}
        {@const cat = categoryMeta[row.category]}
        <tr>
          <th scope="row" class="prof__row-label">
            <span class="prof__cat-dot" style={`background:${cat.fill}`} title={cat.label}></span>
            {row.label}
          </th>
          {#each profiles as p (p.id)}
            <td class="prof__cell" class:is-selected={selected === p.id}>
              {row.values[p.id]}
            </td>
          {/each}
        </tr>
      {/each}
    </tbody>
  </table>

  <div class="prof__footer">
    <div class="prof__legend">
      {#each Object.values(categoryMeta) as c (c.label)}
        <span class="prof__legend-item">
          <span class="prof__cat-dot" style={`background:${c.fill}`}></span>{c.label}
        </span>
      {/each}
    </div>
    <p class="prof__note">
      Security defaults are inherited by every profile. <strong>demo</strong> relaxes
      cost-driven SKUs, never the security model.
    </p>
  </div>
</div>

<style>
  .prof {
    margin-top: var(--s-xl);
    border: var(--hair) solid var(--hairline);
    border-radius: var(--radius-lg);
    background: var(--bg);
    padding: clamp(1.25rem, 1rem + 1.5vw, 2rem);
    box-shadow: var(--shadow-sm);
  }
  .prof__head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: var(--s-md);
    margin-bottom: var(--s-lg);
  }
  .prof__toggle {
    display: inline-flex;
    padding: 4px;
    gap: 2px;
    background: var(--surface-sunken);
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline);
  }
  .prof__opt {
    padding: 0.45rem 1.1rem;
    border-radius: var(--radius-pill);
    font-size: 0.86rem;
    font-weight: var(--w-medium);
    color: var(--muted);
    transition:
      color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart);
  }
  .prof__opt:hover {
    color: var(--ink);
  }
  .prof__opt.is-active {
    color: var(--accent-ink);
    background: var(--accent);
    box-shadow: var(--shadow-sm);
  }
  .prof__intent {
    font-size: 0.95rem;
    color: var(--muted);
  }
  .prof__intent-text {
    display: inline-block;
    animation: fade-in var(--dur-3) var(--ease-out-quart) both;
  }
  @keyframes fade-in {
    from {
      opacity: 0;
      transform: translateY(4px);
    }
  }

  .prof__table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.92rem;
  }
  .prof__col,
  .prof__cell {
    text-align: left;
    padding: 0.7rem 0.9rem;
  }
  .prof__col {
    font-family: var(--font-mono);
    font-size: 0.82rem;
    font-weight: var(--w-semibold);
    color: var(--muted);
    border-bottom: 2px solid var(--hairline);
  }
  .prof__col.is-selected {
    color: var(--accent-deep);
    border-bottom-color: var(--accent);
  }
  .prof__corner {
    width: 30%;
    border-bottom: 2px solid var(--hairline);
  }
  .prof__row-label {
    display: flex;
    align-items: center;
    gap: 0.55rem;
    text-align: left;
    font-weight: var(--w-medium);
    color: var(--ink);
    padding: 0.7rem 0.9rem 0.7rem 0;
    border-bottom: var(--hair) solid var(--hairline);
    white-space: nowrap;
  }
  .prof__cat-dot {
    width: 9px;
    height: 9px;
    border-radius: 3px;
    flex: 0 0 auto;
  }
  .prof__cell {
    color: var(--muted);
    border-bottom: var(--hair) solid var(--hairline);
    transition: background var(--dur-2) var(--ease-out-quart);
  }
  .prof__cell.is-selected {
    color: var(--ink);
    background: var(--accent-wash);
    font-weight: var(--w-medium);
  }
  tbody tr:last-child .prof__cell,
  tbody tr:last-child .prof__row-label {
    border-bottom: none;
  }

  .prof__footer {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
    margin-top: var(--s-md);
    padding-top: var(--s-md);
    border-top: var(--hair) solid var(--hairline);
  }
  .prof__legend {
    display: flex;
    gap: var(--s-md);
  }
  .prof__legend-item {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.8rem;
    color: var(--muted);
  }
  .prof__note {
    font-size: 0.82rem;
    color: var(--muted);
    max-width: 48ch;
  }

  @media (max-width: 720px) {
    .prof__corner {
      width: auto;
    }
    .prof__col:not(.is-selected),
    .prof__cell:not(.is-selected) {
      display: none;
    }
    .prof__row-label {
      white-space: normal;
    }
  }
</style>
