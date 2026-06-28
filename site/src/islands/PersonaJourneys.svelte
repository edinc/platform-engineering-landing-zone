<script lang="ts">
  import { personas } from "../lib/data/personas";
  import { concepts } from "../lib/data/concepts";
  import { withBase } from "../lib/base";
  import Icon from "../components/IconClient.svelte";

  const conceptName = new Map(concepts.map((c) => [c.id, c.term]));
  let selectedId = $state<string | null>(null);
  const persona = $derived(personas.find((p) => p.id === selectedId) ?? null);

  function pick(id: string) {
    selectedId = selectedId === id ? null : id;
  }

  // Highlight matching concept rows across the page (no dimming, just a marker).
  $effect(() => {
    const matchIds = new Set(persona?.concepts ?? []);
    document.querySelectorAll<HTMLElement>("[data-concept]").forEach((el) => {
      const on = matchIds.has(el.dataset.concept ?? "");
      el.toggleAttribute("data-match", on);
      el.querySelector("[data-match-badge]")?.toggleAttribute("hidden", !on);
    });
    return () => {
      document.querySelectorAll<HTMLElement>("[data-concept]").forEach((el) => {
        el.removeAttribute("data-match");
        el.querySelector("[data-match-badge]")?.setAttribute("hidden", "");
      });
    };
  });
</script>

<div class="persona">
  <div class="persona__tabs" role="group" aria-label="Choose a persona">
    {#each personas as p (p.id)}
      <button
        type="button"
        class="persona__tab"
        class:is-active={selectedId === p.id}
        aria-pressed={selectedId === p.id}
        onclick={() => pick(p.id)}
      >
        <span class="persona__tab-icon"><Icon name={p.icon} size={20} /></span>
        <span class="persona__tab-text">
          <span class="persona__tab-label">{p.label}</span>
          <span class="persona__tab-role">{p.role}</span>
        </span>
      </button>
    {/each}
  </div>

  {#if !persona}
    <div class="persona__prompt">
      <p>
        Select a persona to trace their journey through the platform. The
        concepts that serve them light up above.
      </p>
    </div>
  {:else}
    {#key persona.id}
      <div class="persona__detail panel-enter">
        <aside class="persona__who">
          <span class="persona__who-icon"><Icon name={persona.icon} size={26} /></span>
          <h3>{persona.label}</h3>
          <p class="persona__value">{persona.value}</p>
          <div class="persona__concepts">
            <span class="persona__concepts-label">Capabilities that serve them</span>
            <div class="persona__chips">
              {#each persona.concepts as cid (cid)}
                <a class="persona__chip" href={withBase(`/#concept-${cid}`)}>
                  {conceptName.get(cid)} <span aria-hidden="true">↑</span>
                </a>
              {/each}
            </div>
          </div>
        </aside>

        <ol class="persona__journey">
          {#each persona.journey as step, i (i)}
            <li class="persona__step">
              <span class="persona__step-num mono">{i + 1}</span>
              <div class="persona__step-body">
                <h4>{step.title}</h4>
                <p>{step.detail}</p>
              </div>
            </li>
          {/each}
        </ol>
      </div>
    {/key}
  {/if}
</div>

<style>
  .persona {
    margin-top: var(--s-xl);
  }
  .persona__tabs {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: var(--s-sm);
  }
  .persona__tab {
    display: flex;
    align-items: center;
    gap: 0.7rem;
    text-align: left;
    padding: 0.9rem 1rem;
    border-radius: var(--radius);
    border: var(--hair) solid var(--hairline);
    background: var(--bg);
    transition:
      border-color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart),
      transform var(--dur-1) var(--ease-out-quart);
  }
  .persona__tab:hover {
    border-color: var(--hairline-strong);
    transform: translateY(-1px);
  }
  .persona__tab.is-active {
    border-color: var(--accent);
    background: var(--accent-wash);
  }
  .persona__tab-icon {
    display: grid;
    place-items: center;
    width: 2.4rem;
    height: 2.4rem;
    border-radius: var(--radius-sm);
    background: var(--surface-sunken);
    color: var(--muted);
    flex: 0 0 auto;
  }
  .persona__tab.is-active .persona__tab-icon {
    background: var(--accent);
    color: var(--accent-ink);
  }
  .persona__tab-text {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .persona__tab-label {
    font-weight: var(--w-semibold);
    font-size: 0.95rem;
    color: var(--ink);
    line-height: 1.2;
  }
  .persona__tab-role {
    font-size: 0.78rem;
    color: var(--faint);
  }

  .persona__prompt {
    margin-top: var(--s-lg);
    padding: var(--s-xl);
    border: var(--hair) dashed var(--hairline-strong);
    border-radius: var(--radius-lg);
    text-align: center;
    color: var(--muted);
  }
  .persona__prompt p {
    max-width: 44ch;
    margin-inline: auto;
  }

  .persona__detail {
    margin-top: var(--s-lg);
    display: grid;
    grid-template-columns: 0.85fr 1.15fr;
    gap: var(--s-xl);
    align-items: start;
  }
  .persona__who {
    position: sticky;
    top: 5.5rem;
  }
  .persona__who-icon {
    display: grid;
    place-items: center;
    width: 3rem;
    height: 3rem;
    border-radius: var(--radius);
    background: var(--accent-wash);
    color: var(--accent-deep);
    border: var(--hair) solid color-mix(in oklab, var(--accent) 18%, transparent);
  }
  .persona__who h3 {
    margin-top: var(--s-sm);
    font-size: 1.4rem;
  }
  .persona__value {
    margin-top: 0.5rem;
    color: var(--muted);
    font-size: 1.05rem;
    line-height: 1.5;
  }
  .persona__concepts {
    margin-top: var(--s-md);
  }
  .persona__concepts-label {
    display: block;
    font-size: 0.72rem;
    font-weight: var(--w-semibold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
    color: var(--faint);
    margin-bottom: 0.5rem;
  }
  .persona__chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
  }
  .persona__chip {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.3rem 0.6rem;
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline-strong);
    font-size: 0.8rem;
    color: var(--ink);
    font-weight: var(--w-medium);
  }
  .persona__chip:hover {
    text-decoration: none;
    border-color: var(--accent);
    background: var(--accent-wash);
    color: var(--accent-deep);
  }
  .persona__chip span {
    color: var(--faint);
  }

  .persona__journey {
    list-style: none;
    padding: 0;
    margin: 0;
    position: relative;
  }
  .persona__step {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 1rem;
    padding-bottom: var(--s-lg);
    position: relative;
  }
  .persona__step:not(:last-child)::before {
    content: "";
    position: absolute;
    left: 15px;
    top: 32px;
    bottom: 0;
    width: 2px;
    background: var(--hairline);
  }
  .persona__step-num {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: var(--bg);
    border: 2px solid var(--accent);
    color: var(--accent-deep);
    font-size: 0.85rem;
    font-weight: var(--w-semibold);
    z-index: 1;
  }
  .persona__step-body h4 {
    font-size: 1.05rem;
    font-weight: var(--w-semibold);
    margin-top: 0.2rem;
  }
  .persona__step-body p {
    margin-top: 0.25rem;
    color: var(--muted);
  }

  .panel-enter {
    animation: persona-in 0.34s var(--ease-out-expo) both;
  }
  @keyframes persona-in {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
  }

  @media (max-width: 860px) {
    .persona__tabs {
      grid-template-columns: 1fr 1fr;
    }
    .persona__detail {
      grid-template-columns: 1fr;
      gap: var(--s-lg);
    }
    .persona__who {
      position: static;
    }
  }
  @media (max-width: 460px) {
    .persona__tabs {
      grid-template-columns: 1fr;
    }
  }
</style>
