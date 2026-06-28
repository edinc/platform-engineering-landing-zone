<script lang="ts">
  import { steps, actors, type StepKind } from "../lib/data/goldenPath";
  import Icon from "../components/IconClient.svelte";

  let current = $state(0);
  let playing = $state(false);
  let copied = $state(false);

  const step = $derived(steps[current]);
  const actor = $derived(actors[step.actor]);

  const kindMeta: Record<StepKind, { label: string; color: string }> = {
    you: { label: "You", color: "var(--accent-deep)" },
    automated: { label: "Automated", color: "var(--muted)" },
    gate: { label: "Review gate", color: "var(--cat-5-ink)" },
    outcome: { label: "Result", color: "var(--cat-3-ink)" },
  };
  const kind = $derived(kindMeta[step.kind]);

  function go(i: number) {
    current = Math.max(0, Math.min(steps.length - 1, i));
  }
  function next() {
    current = current === steps.length - 1 ? 0 : current + 1;
  }
  function togglePlay() {
    playing = !playing;
  }

  $effect(() => {
    if (!playing) return;
    const id = setInterval(() => {
      // loop: after the final stage, restart from the beginning
      current = current === steps.length - 1 ? 0 : current + 1;
    }, 2800);
    return () => clearInterval(id);
  });

  function focusTab() {
    requestAnimationFrame(() =>
      document.getElementById(`gp-tab-${current}`)?.focus({ preventScroll: true }),
    );
  }
  function onKeydown(e: KeyboardEvent) {
    if (e.key === "ArrowDown" || e.key === "ArrowRight") {
      e.preventDefault();
      go(current + 1);
      focusTab();
    } else if (e.key === "ArrowUp" || e.key === "ArrowLeft") {
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

<div class="gp" class:is-playing={playing}>
  <div class="gp__grid">
    <ol
      class="gp__pipe"
      role="tablist"
      aria-label="Golden-path stages, top to bottom"
      aria-orientation="vertical"
      onkeydown={onKeydown}
    >
      {#each steps as s, i (s.n)}
        {@const a = actors[s.actor]}
        {@const k = kindMeta[s.kind]}
        <li
          class="gp__stage"
          class:is-active={current === i}
          class:is-done={i < current}
          data-kind={s.kind}
          style={`--actor:${a.fill}; --kind:${k.color}`}
        >
          <div class="gp__rail" aria-hidden="true">
            <span class="gp__node">
              {#if i < current}
                <Icon name="check" size={14} stroke={2.6} />
              {:else}
                <Icon name={a.icon} size={14} />
              {/if}
            </span>
            {#if i < steps.length - 1}
              <span class="gp__line"><span class="gp__line-fill"></span></span>
            {/if}
          </div>

          <button
            class="gp__stage-btn"
            type="button"
            role="tab"
            id={`gp-tab-${i}`}
            aria-selected={current === i}
            aria-controls="gp-detail"
            tabindex={current === i ? 0 : -1}
            onclick={() => go(i)}
          >
            <span class="gp__meta">
              <span class="gp__actor">{a.label}</span>
              <span class="gp__tag">{k.label}</span>
            </span>
            <span class="gp__title">{s.title}</span>
            <span class="gp__produces">
              <span aria-hidden="true">↳</span> produces <code>{s.artifact.name}</code>
            </span>
          </button>
        </li>
      {/each}
    </ol>

    <div class="gp__detail">
      <div class="gp__controls">
        <p class="gp__progress mono">
          <span class="gp__progress-n">{String(current + 1).padStart(2, "0")}</span>
          <span class="gp__progress-t">/ {String(steps.length).padStart(2, "0")}</span>
        </p>
        <div class="gp__btns">
          <button class="gp__play" type="button" onclick={togglePlay} aria-pressed={playing}>
            <Icon name={playing ? "pause" : "play"} size={13} />
            {playing ? "Pause" : "Play walkthrough"}
          </button>
          <button
            class="gp__step-btn gp__step-btn--prev"
            type="button"
            onclick={() => go(current - 1)}
            disabled={current === 0}
            aria-label="Previous step"
          >
            <Icon name="arrow-right" size={16} />
          </button>
          <button class="gp__step-btn" type="button" onclick={next} aria-label="Next step">
            <Icon name="arrow-right" size={16} />
          </button>
        </div>
      </div>

      <div class="gp__panel" id="gp-detail" role="tabpanel" aria-labelledby={`gp-tab-${current}`} tabindex="0">
        {#key current}
          <div class="gp__panel-inner panel-enter">
            <div class="gp__panel-head">
              <span class="gp__panel-actor" style={`--actor:${actor.fill}`}>
                <span class="gp__panel-icon"><Icon name={actor.icon} size={15} /></span>
                {actor.label}
              </span>
              <span class="gp__tag gp__tag--lg" style={`--kind:${kind.color}`}>{kind.label}</span>
            </div>
            <h3 class="gp__panel-title">{step.title}</h3>
            <p class="gp__summary">{step.summary}</p>
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
  </div>
</div>

<style>
  .gp {
    margin-top: var(--s-xl);
  }
  .gp__grid {
    display: grid;
    grid-template-columns: minmax(0, 0.92fr) minmax(0, 1.08fr);
    gap: clamp(1.5rem, 1rem + 2vw, 3.5rem);
    align-items: start;
  }

  /* ---- pipeline (left) ---- */
  .gp__pipe {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .gp__stage {
    display: grid;
    grid-template-columns: 2.2rem 1fr;
    gap: 0.85rem;
  }
  .gp__rail {
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .gp__node {
    position: relative;
    width: 2.2rem;
    height: 2.2rem;
    border-radius: 50%;
    display: grid;
    place-items: center;
    flex: 0 0 auto;
    background: var(--bg);
    border: 2px solid color-mix(in oklab, var(--actor) 50%, var(--hairline));
    color: var(--actor);
    transition:
      border-color var(--dur-2) var(--ease-out-quart),
      background var(--dur-2) var(--ease-out-quart),
      box-shadow var(--dur-2) var(--ease-out-quart),
      transform var(--dur-2) var(--ease-out-quart);
  }
  .gp__stage.is-done .gp__node {
    background: var(--actor);
    border-color: var(--actor);
    color: var(--bg);
  }
  .gp__stage.is-active .gp__node {
    border-color: var(--actor);
    box-shadow: 0 0 0 4px color-mix(in oklab, var(--actor) 16%, transparent);
    transform: scale(1.08);
  }
  .gp.is-playing .gp__stage.is-active .gp__node::after {
    content: "";
    position: absolute;
    inset: -2px;
    border-radius: 50%;
    border: 2px solid var(--actor);
    animation: gp-pulse 1.8s var(--ease-out-quart) infinite;
  }
  @keyframes gp-pulse {
    to {
      transform: scale(1.6);
      opacity: 0;
    }
  }
  .gp__line {
    position: relative;
    width: 2px;
    flex: 1 1 auto;
    min-height: 0.75rem;
    margin-block: 0.2rem;
    background: var(--hairline);
    border-radius: 2px;
  }
  .gp__line-fill {
    position: absolute;
    inset: 0;
    background: var(--actor);
    border-radius: 2px;
    transform: scaleY(0);
    transform-origin: top;
    transition: transform var(--dur-3) var(--ease-out-quart);
  }
  .gp__stage.is-done .gp__line-fill {
    transform: scaleY(1);
  }

  .gp__stage-btn {
    display: block;
    text-align: left;
    width: 100%;
    padding: 0.1rem 0.6rem 1.1rem 0;
    border-radius: var(--radius-sm);
  }
  .gp__stage-btn:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
  .gp__meta {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.15rem;
  }
  .gp__actor {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: var(--w-medium);
    color: var(--actor);
  }
  .gp__tag {
    font-family: var(--font-mono);
    font-size: 0.62rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--kind);
    background: color-mix(in oklab, var(--kind) 13%, transparent);
    padding: 0.08rem 0.4rem;
    border-radius: var(--radius-pill);
  }
  .gp__title {
    display: block;
    font-size: 1.04rem;
    font-weight: var(--w-semibold);
    color: var(--muted);
    letter-spacing: -0.01em;
    transition: color var(--dur-1) var(--ease-out-quart);
  }
  .gp__stage.is-active .gp__title,
  .gp__stage.is-done .gp__title,
  .gp__stage-btn:hover .gp__title {
    color: var(--ink);
  }
  .gp__produces {
    display: block;
    margin-top: 0.3rem;
    font-size: 0.78rem;
    color: var(--faint);
  }
  .gp__produces code {
    font-size: 0.76rem;
    color: var(--muted);
    background: var(--surface-sunken);
    padding: 0.08em 0.38em;
    border-radius: var(--radius-sm);
  }

  /* ---- detail (right, sticky) ---- */
  .gp__detail {
    position: sticky;
    top: 5.5rem;
  }
  .gp__controls {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
    margin-bottom: var(--s-md);
  }
  .gp__progress {
    font-size: 0.95rem;
    color: var(--faint);
  }
  .gp__progress-n {
    color: var(--accent-deep);
    font-weight: var(--w-semibold);
    font-size: 1.15rem;
  }
  .gp__btns {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .gp__play {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    height: 2.3rem;
    padding-inline: 0.9rem;
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
    display: inline-grid;
    place-items: center;
    width: 2.3rem;
    height: 2.3rem;
    border-radius: 50%;
    border: var(--hair) solid var(--hairline-strong);
    background: var(--bg);
    color: var(--ink);
  }
  .gp__step-btn--prev :global(svg) {
    transform: rotate(180deg);
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
    border: var(--hair) solid var(--hairline);
    border-radius: var(--radius-lg);
    background: var(--bg);
    box-shadow: var(--shadow-md);
    padding: clamp(1.1rem, 0.9rem + 1vw, 1.75rem);
  }
  .gp__panel:focus-visible {
    box-shadow: var(--shadow-md), var(--focus-ring);
  }
  .gp__panel-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
  }
  .gp__panel-actor {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.85rem;
    font-weight: var(--w-medium);
    color: var(--actor);
  }
  .gp__panel-icon {
    display: inline-grid;
    place-items: center;
    width: 1.85rem;
    height: 1.85rem;
    border-radius: var(--radius-sm);
    background: color-mix(in oklab, var(--actor) 14%, transparent);
  }
  .gp__tag--lg {
    font-size: 0.66rem;
    padding: 0.16rem 0.5rem;
  }
  .gp__panel-title {
    margin-top: var(--s-sm);
    font-size: 1.45rem;
  }
  .gp__summary {
    margin-top: 0.5rem;
    color: var(--muted);
    line-height: 1.55;
  }
  .gp__artifact {
    margin: var(--s-md) 0 0;
    border-radius: var(--radius);
    border: var(--hair) solid var(--hairline-strong);
    background: var(--surface-sunken);
    overflow: hidden;
  }
  .gp__artifact-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
    padding: 0.5rem 0.85rem;
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

  @media (max-width: 860px) {
    .gp__grid {
      grid-template-columns: 1fr;
      gap: var(--s-lg);
    }
    .gp__detail {
      position: static;
    }
    /* show controls above the pipeline on narrow screens */
    .gp__detail {
      order: -1;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .gp.is-playing .gp__stage.is-active .gp__node::after {
      animation: none;
    }
  }
</style>
