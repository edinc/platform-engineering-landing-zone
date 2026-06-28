<script lang="ts">
  import ArchitectureMap from "./ArchitectureMap.svelte";
  import ArchitectureExplorer from "./ArchitectureExplorer.svelte";

  const views = [
    { id: "diagram", label: "Diagram" },
    { id: "layers", label: "Layers" },
  ] as const;
  let view = $state<"diagram" | "layers">("diagram");

  function onKeydown(e: KeyboardEvent) {
    const idx = views.findIndex((v) => v.id === view);
    if (e.key === "ArrowRight" || e.key === "ArrowDown") {
      e.preventDefault();
      view = views[(idx + 1) % views.length].id;
      focus();
    } else if (e.key === "ArrowLeft" || e.key === "ArrowUp") {
      e.preventDefault();
      view = views[(idx - 1 + views.length) % views.length].id;
      focus();
    }
  }
  function focus() {
    requestAnimationFrame(() => document.getElementById(`aview-${view}`)?.focus());
  }
</script>

<div class="aview">
  <div class="aview__bar">
    <div class="aview__toggle" role="tablist" aria-label="Architecture view" onkeydown={onKeydown}>
      {#each views as v (v.id)}
        <button
          type="button"
          role="tab"
          id={`aview-${v.id}`}
          class="aview__opt"
          class:is-active={view === v.id}
          aria-selected={view === v.id}
          tabindex={view === v.id ? 0 : -1}
          onclick={() => (view = v.id)}
        >
          {v.label}
        </button>
      {/each}
    </div>
    <p class="aview__hint mono">
      {view === "diagram" ? "click a component for details" : "↕ arrow keys move through layers"}
    </p>
  </div>

  {#if view === "diagram"}
    <ArchitectureMap />
  {:else}
    <ArchitectureExplorer />
  {/if}
</div>

<style>
  .aview__bar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-sm);
  }
  .aview__toggle {
    display: inline-flex;
    padding: 4px;
    gap: 2px;
    background: var(--surface-sunken);
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline);
  }
  .aview__opt {
    padding: 0.45rem 1.1rem;
    border-radius: var(--radius-pill);
    font-size: 0.88rem;
    font-weight: var(--w-medium);
    color: var(--muted);
    transition:
      color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart);
  }
  .aview__opt:hover {
    color: var(--ink);
  }
  .aview__opt.is-active {
    color: var(--accent-ink);
    background: var(--accent);
    box-shadow: var(--shadow-sm);
  }
  .aview__hint {
    font-size: var(--text-sm);
    color: var(--faint);
  }
</style>
