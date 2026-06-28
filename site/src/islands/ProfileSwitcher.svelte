<script lang="ts">
  import { profiles, posture, meters, categoryMeta, type ProfileId } from "../lib/data/profiles";
  import Icon from "../components/IconClient.svelte";

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
  <div class="prof__cards" role="radiogroup" aria-label="Environment profile" onkeydown={onKeydown}>
    {#each profiles as p (p.id)}
      <button
        type="button"
        role="radio"
        id={`prof-${p.id}`}
        class="prof__card"
        class:is-active={selected === p.id}
        aria-checked={selected === p.id}
        tabindex={selected === p.id ? 0 : -1}
        onclick={() => (selected = p.id)}
      >
        <span class="prof__card-name mono">{p.label}</span>
        <span class="prof__card-intent">{p.intent}</span>
      </button>
    {/each}
  </div>

  <div class="prof__grid">
    <div class="prof__meters" aria-label="Posture for the selected profile">
      {#each meters as m (m.id)}
        {@const lvl = m.levels[selected]}
        {@const cat = categoryMeta[m.category]}
        <div class="prof__meter" style={`--c:${cat.fill}; --c-ink:${cat.ink}`}>
          <div class="prof__meter-head">
            <span class="prof__meter-label">
              <Icon name={m.icon} size={17} />
              {m.label}
            </span>
            {#if m.note}<span class="prof__meter-pin"><Icon name="lock" size={11} /> {m.note}</span>{/if}
          </div>
          <div class="prof__bar" aria-hidden="true">
            <div class="prof__bar-fill" style={`transform: scaleX(${lvl.n / 3})`}></div>
            <span class="prof__tick" style="left:33.33%"></span>
            <span class="prof__tick" style="left:66.66%"></span>
          </div>
          <span class="prof__meter-word tnum"
            >{lvl.word}<span class="sr-only"> ({lvl.n} of 3)</span></span
          >
        </div>
      {/each}
    </div>

    <div class="prof__config">
      <div class="prof__config-head">
        <span class="prof__config-title">What it provisions</span>
        <span class="prof__config-env mono">{current.label}</span>
      </div>
      {#key selected}
        <ul role="list" class="prof__config-list">
          {#each posture as row (row.id)}
            {@const cat = categoryMeta[row.category]}
            <li class="prof__config-row">
              <span class="prof__config-dot" style={`background:${cat.fill}`} title={cat.label}></span>
              <span class="prof__config-dim">{row.label}</span>
              <span class="prof__config-val">{row.values[selected]}</span>
            </li>
          {/each}
        </ul>
      {/key}
    </div>
  </div>

  <div class="prof__footer">
    <div class="prof__legend">
      {#each Object.values(categoryMeta) as c (c.label)}
        <span class="prof__legend-item">
          <span class="prof__config-dot" style={`background:${c.fill}`}></span>{c.label}
        </span>
      {/each}
    </div>
    <p class="prof__note">
      Same Terraform, three variable sets. <strong>demo</strong> relaxes cost-driven SKUs;
      the security baseline is inherited unchanged on every profile.
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

  /* profile cards */
  .prof__cards {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--s-sm);
  }
  .prof__card {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    align-items: flex-start;
    text-align: left;
    padding: 0.85rem 1rem;
    border-radius: var(--radius);
    border: 1.5px solid var(--hairline);
    background: var(--surface);
    transition:
      border-color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart),
      transform var(--dur-1) var(--ease-out-quart);
  }
  .prof__card:hover {
    border-color: var(--hairline-strong);
    transform: translateY(-1px);
  }
  .prof__card.is-active {
    border-color: var(--accent);
    background: var(--accent-wash);
  }
  .prof__card-name {
    font-size: 1rem;
    font-weight: var(--w-semibold);
    color: var(--ink);
  }
  .prof__card.is-active .prof__card-name {
    color: var(--accent-deep);
  }
  .prof__card-intent {
    font-size: 0.82rem;
    color: var(--muted);
  }

  .prof__grid {
    margin-top: var(--s-lg);
    display: grid;
    grid-template-columns: 0.95fr 1.05fr;
    gap: clamp(1.5rem, 1rem + 2vw, 3rem);
    align-items: start;
  }

  /* meters */
  .prof__meters {
    display: flex;
    flex-direction: column;
    gap: var(--s-md);
  }
  .prof__meter-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
  }
  .prof__meter-label {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    font-weight: var(--w-medium);
    font-size: 0.95rem;
    color: var(--ink);
  }
  .prof__meter-label :global(svg) {
    color: var(--c-ink);
  }
  .prof__meter-pin {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    font-family: var(--font-mono);
    font-size: 0.68rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--c-ink);
    background: color-mix(in oklab, var(--c) 14%, transparent);
    padding: 0.12rem 0.45rem;
    border-radius: var(--radius-pill);
  }
  .prof__bar {
    position: relative;
    height: 0.6rem;
    margin-top: 0.5rem;
    background: var(--surface-sunken);
    border-radius: var(--radius-pill);
    overflow: hidden;
  }
  .prof__bar-fill {
    position: absolute;
    inset: 0;
    transform-origin: left;
    background: linear-gradient(90deg, color-mix(in oklab, var(--c) 80%, black 6%), var(--c));
    border-radius: var(--radius-pill);
    transition: transform var(--dur-4) var(--ease-out-expo);
  }
  .prof__tick {
    position: absolute;
    top: 0;
    bottom: 0;
    width: 2px;
    background: var(--bg);
    opacity: 0.7;
  }
  .prof__meter-word {
    display: inline-block;
    margin-top: 0.4rem;
    font-size: 0.85rem;
    color: var(--muted);
  }

  /* concrete config */
  .prof__config {
    border-left: var(--hair) solid var(--hairline);
    padding-left: clamp(1.25rem, 1rem + 1.5vw, 2.5rem);
  }
  .prof__config-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--s-sm);
    margin-bottom: var(--s-xs);
  }
  .prof__config-title {
    font-size: 0.72rem;
    font-weight: var(--w-semibold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
    color: var(--faint);
  }
  .prof__config-env {
    font-size: 0.82rem;
    font-weight: var(--w-semibold);
    color: var(--accent-deep);
  }
  .prof__config-list {
    display: flex;
    flex-direction: column;
    animation: cfg-in var(--dur-3) var(--ease-out-quart);
  }
  @keyframes cfg-in {
    from {
      opacity: 0;
      transform: translateY(4px);
    }
  }
  .prof__config-row {
    display: grid;
    grid-template-columns: auto minmax(7rem, auto) 1fr;
    align-items: baseline;
    gap: 0.7rem;
    padding: 0.5rem 0;
    border-bottom: var(--hair) solid var(--hairline);
  }
  .prof__config-row:last-child {
    border-bottom: none;
  }
  .prof__config-dot {
    width: 8px;
    height: 8px;
    border-radius: 3px;
    flex: 0 0 auto;
  }
  .prof__config-row .prof__config-dot {
    transform: translateY(0.3rem);
  }
  .prof__config-dim {
    font-size: 0.86rem;
    color: var(--muted);
  }
  .prof__config-val {
    font-size: 0.9rem;
    font-weight: var(--w-medium);
    color: var(--ink);
  }

  .prof__footer {
    margin-top: var(--s-lg);
    padding-top: var(--s-md);
    border-top: var(--hair) solid var(--hairline);
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
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
    max-width: 52ch;
  }

  @media (max-width: 760px) {
    .prof__grid {
      grid-template-columns: 1fr;
    }
    .prof__config {
      border-left: none;
      padding-left: 0;
      border-top: var(--hair) solid var(--hairline);
      padding-top: var(--s-md);
    }
  }
  @media (max-width: 460px) {
    .prof__cards {
      grid-template-columns: 1fr;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .prof__bar-fill {
      transition: none;
    }
  }
</style>
