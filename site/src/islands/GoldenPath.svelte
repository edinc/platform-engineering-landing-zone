<script lang="ts">
  import { steps, actors } from "../lib/data/goldenPath";

  let current = $state(0);
  let playing = $state(false);
  let copied = $state(false);

  const step = $derived(steps[current]);
  const actor = $derived(actors[step.actor]);
  const progress = $derived((current / (steps.length - 1)) * 100);

  function go(i: number) {
    current = Math.max(0, Math.min(steps.length - 1, i));
  }

  function next() {
    if (current === steps.length - 1) {
      current = 0;
    } else {
      current += 1;
    }
  }

  function togglePlay() {
    playing = !playing;
  }

  $effect(() => {
    if (!playing) return;
    const id = setInterval(() => {
      if (current === steps.length - 1) {
        playing = false;
      } else {
        current += 1;
      }
    }, 2600);
    return () => clearInterval(id);
  });

  function onRailKeydown(e: KeyboardEvent) {
    if (e.key === "ArrowRight" || e.key === "ArrowDown") {
      e.preventDefault();
      go(current + 1);
      focusTab();
    } else if (e.key === "ArrowLeft" || e.key === "ArrowUp") {
      e.preventDefault();
      go(current - 1);
      focusTab();
    } else if (e.key === "Home") {
      e.preventDefault();
      go(0);
      focusTab();
    } else if (e.key === "End") {
      e.preventDefault();
      go(steps.length - 1);
      focusTab();
    }
  }
  function focusTab() {
    requestAnimationFrame(() => document.getElementById(`gp-tab-${current}`)?.focus());
  }

  async function copy() {
    try {
      await navigator.clipboard.writeText(step.artifact.code);
      copied = true;
      setTimeout(() => (copied = false), 1600);
    } catch {
      /* clipboard unavailable */
    }
  }
</script>

<div class="gp">
  <div class="gp__bar">
    <div
      class="gp__rail"
      role="tablist"
      aria-label="Golden-path steps"
      style={`--gp-count:${steps.length}`}
      onkeydown={onRailKeydown}
    >
      <div class="gp__track" aria-hidden="true">
        <div class="gp__fill" style={`transform: scaleX(${progress / 100})`}></div>
      </div>
      {#each steps as s, i (s.n)}
        {@const a = actors[s.actor]}
        <button
          type="button"
          role="tab"
          id={`gp-tab-${i}`}
          class="gp__dot"
          class:is-current={current === i}
          class:is-done={i < current}
          aria-selected={current === i}
          aria-controls="gp-panel"
          aria-label={`Step ${s.n}: ${s.title}`}
          tabindex={current === i ? 0 : -1}
          style={`--actor:${a.fill}`}
          onclick={() => go(i)}
        >
          <span class="gp__dot-num">{s.n}</span>
          <span class="gp__dot-title">{s.title}</span>
        </button>
      {/each}
    </div>

    <div class="gp__controls">
      <button type="button" class="gp__play" onclick={togglePlay} aria-pressed={playing}>
        {#if playing}
          <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1" fill="currentColor"/><rect x="14" y="5" width="4" height="14" rx="1" fill="currentColor"/></svg>
          Pause
        {:else}
          <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5l12 7-12 7z" fill="currentColor"/></svg>
          Play walkthrough
        {/if}
      </button>
      <button type="button" class="gp__step-btn" onclick={() => go(current - 1)} disabled={current === 0} aria-label="Previous step">←</button>
      <button type="button" class="gp__step-btn" onclick={next} aria-label="Next step">→</button>
    </div>
  </div>

  <div class="gp__panel" id="gp-panel" role="tabpanel" aria-labelledby={`gp-tab-${current}`} tabindex="0">
    {#key current}
      <div class="gp__grid panel-enter">
        <div class="gp__detail">
          <div class="gp__meta">
            <span class="gp__count mono">Step {step.n} / {steps.length}</span>
            <span class="gp__actor" style={`--actor:${actor.fill}`}>
              <span class="gp__actor-dot"></span>{actor.label}
            </span>
          </div>
          <h3 class="gp__title">{step.title}</h3>
          <p class="gp__summary">{step.summary}</p>
        </div>

        <figure class="gp__artifact">
          <figcaption class="gp__artifact-head">
            <span class="gp__artifact-name mono">{step.artifact.name}</span>
            <button type="button" class="gp__copy" onclick={copy} aria-label="Copy artifact">
              {copied ? "copied" : "copy"}
            </button>
          </figcaption>
          <pre class="gp__code"><code>{step.artifact.code}</code></pre>
        </figure>
      </div>
    {/key}
  </div>
</div>

<style>
  .gp {
    margin-top: var(--s-xl);
  }
  .gp__bar {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--s-md);
    flex-wrap: wrap;
  }
  .gp__rail {
    position: relative;
    display: grid;
    grid-template-columns: repeat(var(--gp-count, 8), 1fr);
    gap: 0;
    flex: 1 1 30rem;
    min-width: 0;
  }
  .gp__track {
    position: absolute;
    top: 13px;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--hairline-strong);
    border-radius: 2px;
  }
  .gp__fill {
    height: 100%;
    width: 100%;
    transform-origin: left;
    background: var(--accent);
    border-radius: 2px;
    transition: transform var(--dur-3) var(--ease-out-quart);
  }
  .gp__dot {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    padding-top: 0;
    text-align: center;
  }
  .gp__dot-num {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: var(--bg);
    border: 2px solid var(--hairline-strong);
    color: var(--faint);
    font-family: var(--font-mono);
    font-size: 0.82rem;
    font-weight: var(--w-semibold);
    transition:
      border-color var(--dur-2) var(--ease-out-quart),
      background var(--dur-2) var(--ease-out-quart),
      color var(--dur-2) var(--ease-out-quart),
      transform var(--dur-2) var(--ease-out-quart);
  }
  .gp__dot.is-done .gp__dot-num {
    border-color: var(--accent);
    color: var(--accent-deep);
  }
  .gp__dot.is-current .gp__dot-num {
    border-color: var(--accent);
    background: var(--accent);
    color: var(--accent-ink);
    transform: scale(1.12);
    box-shadow: 0 0 0 4px var(--accent-wash);
  }
  .gp__dot-title {
    font-size: 0.72rem;
    line-height: 1.2;
    color: var(--faint);
    max-width: 9ch;
    transition: color var(--dur-1) var(--ease-out-quart);
  }
  .gp__dot.is-current .gp__dot-title {
    color: var(--ink);
    font-weight: var(--w-medium);
  }
  .gp__dot:hover .gp__dot-num {
    border-color: var(--accent);
  }

  .gp__controls {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .gp__play {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    height: 2.3rem;
    padding-inline: 0.85rem;
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline-strong);
    background: var(--bg);
    color: var(--ink);
    font-size: 0.85rem;
    font-weight: var(--w-medium);
  }
  .gp__play:hover {
    border-color: var(--accent);
    color: var(--accent-deep);
  }
  .gp__step-btn {
    width: 2.3rem;
    height: 2.3rem;
    border-radius: 50%;
    border: var(--hair) solid var(--hairline-strong);
    background: var(--bg);
    color: var(--ink);
    font-size: 1rem;
  }
  .gp__step-btn:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent-deep);
  }
  .gp__step-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .gp__panel {
    margin-top: var(--s-xl);
    border-radius: var(--radius-lg);
  }
  .gp__panel:focus-visible {
    box-shadow: var(--focus-ring);
  }
  .gp__grid {
    display: grid;
    grid-template-columns: 0.85fr 1.15fr;
    gap: var(--s-lg);
    align-items: stretch;
  }
  .gp__meta {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  .gp__count {
    font-size: 0.8rem;
    color: var(--faint);
  }
  .gp__actor {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.8rem;
    font-weight: var(--w-medium);
    color: var(--muted);
  }
  .gp__actor-dot {
    width: 9px;
    height: 9px;
    border-radius: 3px;
    background: var(--actor);
  }
  .gp__title {
    margin-top: 0.85rem;
    font-size: 1.7rem;
  }
  .gp__summary {
    margin-top: var(--s-sm);
    color: var(--muted);
    font-size: 1.05rem;
    line-height: 1.55;
    max-width: 42ch;
  }

  .gp__artifact {
    margin: 0;
    border-radius: var(--radius);
    border: var(--hair) solid var(--hairline-strong);
    background: var(--surface-sunken);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }
  .gp__artifact-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
    padding: 0.55rem 0.85rem;
    border-bottom: var(--hair) solid var(--hairline);
    background: var(--surface);
  }
  .gp__artifact-name {
    font-size: 0.78rem;
    color: var(--muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .gp__copy {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    color: var(--faint);
    padding: 0.15rem 0.45rem;
    border-radius: var(--radius-sm);
    border: var(--hair) solid var(--hairline);
  }
  .gp__copy:hover {
    color: var(--accent-deep);
    border-color: var(--accent);
  }
  .gp__code {
    margin: 0;
    padding: 0.9rem 1rem;
    overflow-x: auto;
    font-size: 0.82rem;
    line-height: 1.65;
    color: var(--ink);
    flex: 1;
  }
  .gp__code code {
    font-size: inherit;
  }

  .panel-enter {
    animation: gp-in 0.32s var(--ease-out-expo) both;
  }
  @keyframes gp-in {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
  }

  @media (max-width: 820px) {
    .gp__grid {
      grid-template-columns: 1fr;
    }
    .gp__dot-title {
      display: none;
    }
    .gp__track {
      top: 13px;
    }
  }
</style>
